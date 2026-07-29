// =============================================================================
// _acc_elites.gsc - elite cyber-zombie spawn logic
//
// Design reference: docs/08_enemies.md (The Cast, Elite Quota Per Round,
// Co-op Scaling), docs/05_mechanics.md (Elite Timing).
//
// Three elite classes: Shielded (r5+), Teleporter (r11+), EMP (r21+).
// Spawning is driven by "pressure pulses" inside a round, not random spawn
// overrides, so elites feel deliberate.
//
// Also owns:
//  - The per-round reset of the elite-shard diminishing-returns counter
//    (player.acc_shards_elite_count_round, incremented by
//    acc_data_shards::grant_player for "elite_kill"-sourced grants).
//  - The EMP elite's on-hit debuff (point drain + Cyberware ability lockout)
//    via the stock player-damage callback chain.
// =============================================================================

#using scripts\shared\ai\zombie_utility;
#using scripts\shared\util_shared;
#using scripts\shared\hud_util_shared;   // hud::createIcon for the Battery-surge full-screen aura (trench-warning recipe)

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_leveling;   // priority-elite kill XP (docs/45)
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;
#using scripts\zm\zm_abandoned_cyber_city\_acc_zombie_speed;   // shielded 50%-slower gait (mirror of the glitch speed think)
#using scripts\zm\zm_abandoned_cyber_city\_acc_perks;          // Savior (Mega QR) revive damage-reduction predicate

// ---------------------------------------------------------------------------
// Tuning (tuned against docs/03_progression_and_skills.md difficulty table)
// ---------------------------------------------------------------------------

#define ACC_ELITE_SHIELDED_MIN_ROUND 5
#define ACC_ELITE_TELEPORTER_MIN_ROUND 11
#define ACC_ELITE_EMP_MIN_ROUND 21

#define ACC_ELITE_SHARD_REWARD 1

// Shielded shield-round COUNT curve: int(k*log2(round) - c), then x elite_count_player_mult().
// User 2026-07-15 (replaced LINEAR round/2, which ran to 24 shields by r48). k=2.5 / c=3.0 anchor the
// early game to the old curve exactly (r4 -> 2, r8 -> 4). Live dvars acc_shielded_count_log_k / _log_c.
#define ACC_SHIELDED_COUNT_LOG_K 2.5
#define ACC_SHIELDED_COUNT_LOG_C 3.0

// EMP elite on-hit debuff (docs/08_enemies.md "Elite: EMP (Surge)").
#define ACC_ELITE_EMP_HIT_POINT_DRAIN 200
#define ACC_ELITE_EMP_HIT_DISABLE_SEC 5

#namespace acc_elites;

function init()
{
    acc_utility::log( "elites init" );

    level.acc_elite_active_count = 0;

    level thread round_pressure_loop();
    level thread watch_round_shard_counter_reset();

    // VERIFIED(acc): "zombie_killed" is only ever notified on the PLAYER (and
    // only in the insta-kill path, _zm_powerups.gsc:1463) - a level waittill
    // would hang forever. The stock per-zombie death hook is
    // zm_spawner::register_zombie_death_event_callback (_zm_spawner.gsc:2463);
    // the callback runs ON the dying zombie with the attacker as arg
    // (usage example: _zm_perk_widows_wine.gsc:134).
    zm_spawner::register_zombie_death_event_callback( &on_elite_zombie_death );

    // VERIFIED(acc): zm::register_player_damage_callback (_zm.gsc:5522-5530)
    // is the dispatched player-damage hook - player_damage_override (wired at
    // level.overridePlayerDamage, _zm.gsc:1341) runs
    // check_player_damage_callbacks as its FIRST step (_zm.gsc:5108-5110);
    // each callback runs ON the damaged player with 10 positional args, and
    // returning -1 means "damage unchanged, later callbacks still evaluate"
    // (_zm.gsc:5502-5519). An EARLIER callback returning non -1 short-circuits
    // us (e.g. the riotshield absorb path) - acceptable, those hits were
    // blocked anyway. Stock users: _zm_weap_riotshield.gsc:75,
    // _zm_weap_gravityspikes.gsc:108.
    zm::register_player_damage_callback( &on_player_damaged );

    // DEPTH-SCALED Shielded ratio (user 2026-06-25): the deeper into the abyss, the more zombies spawn Shielded.
    // We init AFTER coop_scaling (acc_main order), so chaining level.zombie_init_done here makes us the OUTERMOST
    // hook - calling the prior hook first, our roll runs AFTER coop's HP scaling, exactly when
    // promote_to_shielded wants the co-op-scaled maxhealth. This is IN ADDITION to the round-based shield rounds.
    level.acc_depth_zid_prev = level.zombie_init_done;
    level.zombie_init_done = &acc_depth_shielded_init_hook;
}

// Per-zombie init-chain hook: run the prior init (coop HP scaling etc.) FIRST, then the depth-Shielded roll.
function acc_depth_shielded_init_hook()
{
    if ( isdefined( level.acc_depth_zid_prev ) ) self [[ level.acc_depth_zid_prev ]]();
    self thread acc_depth_shielded_roll();
}

// self = a fully-init'd zombie (coop HP applied). On an abyss FLOOR, roll depth_shielded_pct() to spawn as a
// Shielded "Riot" elite. Skips bosses + anything already shielded/elite (the re-entrancy guard double-protects).
// THREADED with the SAME 0.3s delay as _acc_trench_skins::trench_skin_roll (fixed 2026-07-04 - the flagged
// latent SPAWN-ORIGIN TRAP): at zombie_init_done time EVERY zombie sits at the single surface factory spawner
// (z=208, layer 0) - stock spawn_zombie only teleports it to its real riser AFTER init. The old same-frame
// origin read therefore always saw layer 0 -> pct 0 -> the depth-Shielded roll NEVER fired anywhere. 0.3s
// later the zombie is at its true rise point (risers spend 1-2s under the floor, so the promotion is
// invisible to players).
function acc_depth_shielded_roll()
{
    self endon( "death" );
    wait 0.3;

    if ( !isdefined( self ) || !isalive( self ) ) return;
    if ( IS_TRUE( self.acc_is_elite ) || IS_TRUE( self.acc_is_shielded ) ) return;
    if ( IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) || IS_TRUE( self.is_boss ) ) return;
    pct = depth_shielded_pct( acc_bus_trench::underground_layer( self.origin ) );
    if ( pct <= 0 ) return;
    if ( acc_utility::acc_rand_int( 100 ) >= pct ) return;
    self.acc_is_elite = true;
    self.acc_elite_class = "shielded";
    promote_to_shielded( self );
    level.acc_elite_active_count += 1;   // symmetry with spawn_elite; on_elite_zombie_death decrements for any elite (audit 2026-07-12)
}

// user 2026-06-25: deeper abyss = a higher % of zombies spawn Shielded. Surface + L1 (the pit) = 0 (the
// round-based shield rounds still cover those); the descent FLOORS scale up. Live dvars per floor.
function depth_shielded_pct( layer )
{
    switch ( layer )
    {
        case 2: return getdvarint( "acc_shielded_pct_l2", 10 );   // trench floor 2 (first descent)
        case 3: return getdvarint( "acc_shielded_pct_l3", 15 );   // floor 3
        case 4: return getdvarint( "acc_shielded_pct_l4", 22 );   // floor 4
        case 5: return getdvarint( "acc_shielded_pct_l5", 30 );   // floor 5 (deepest)
    }
    return 0;   // layer 0 (surface) + layer 1 (pit): no depth Shielded
}

// ---------------------------------------------------------------------------
// Round-level orchestration
// ---------------------------------------------------------------------------

function round_pressure_loop()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );

        quota = elite_quota_for_round( round_number );
        if ( quota <= 0 ) continue;

        level thread spawn_elites_over_round( quota, round_number );
    }
}

// The elite-shard diminishing-returns counter
// (player.acc_shards_elite_count_round, incremented by
// acc_data_shards::grant_player for "elite_kill"-sourced grants) is PER ROUND
// by design (docs/05_mechanics.md Data Shard Economy) - without this reset
// the low-round diminish became permanent once tripped. The reset lives here
// because elites own the elite-kill cadence.
function watch_round_shard_counter_reset()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );

        players = acc_utility::get_all_players();
        for ( i = 0; i < players.size; i++ )
        {
            players[ i ].acc_shards_elite_count_round = 0;
        }
    }
}

function elite_quota_for_round( round_number )
{
    // SHIELDED-ONLY EVENT ROUNDS (user 2026-06-22): the Teleporter + EMP elites are removed; the only
    // elite left is the Shielded zombie. It spawns on a "shield round" every 4 rounds from r4
    // (r4, r8, r12, ...); every other round spawns zero elites. The CADENCE is unchanged.
    //
    // The COUNT is now LOG IN ROUND x LOG IN PLAYERS (user 2026-07-15):
    //   count = max( 2, int( k*log2(round) - c ) )  x  acc_coop_scaling::elite_count_player_mult()
    //   k = acc_shielded_count_log_k (2.5), c = acc_shielded_count_log_c (3.0)
    //
    // Replaces the LINEAR round/2 (r20 -> 10, r40 -> 20, r48 -> 24 shields, forever). That linear curve
    // is what the OLD comment here flagged as "still a chunk of shields vs the ~24-AI cap ... revisit if
    // it feels heavy" - this IS that revisit, and the cap is now ACC_AI_LIMIT 50 (_acc_main.gsc:98), not
    // 24 (the old note was stale). Constants anchor the EARLY GAME bit-identical to the old curve at 1p
    // (r4 = 2, r8 = 4) and only flatten once it ran away (r20: 7 vs 10, r48: 10 vs 24).
    //
    // The count was also PLAYER-BLIND before: a 4p lobby got the same shield count as solo while the
    // regular horde grew +30%/player, so Shielded were a shrinking share of the wave as the lobby grew.
    // The two logs COMPOUND (4p doubles the round term) - hence the flat late round term; the rejected
    // linear-round x log-player design reached 78 elites at r40 4p vs the 50-AI cap (elites-only wave).
    //
    // NOTE this is only ONE of three Shielded sources - the depth roll (promote_on_spawn) and the reactor
    // surge (_acc_reactor) spawn Shielded independently and are NOT bounded by this quota.
    if ( round_number >= 4 && ( round_number % 4 ) == 0 )
    {
        k = getdvarfloat( "acc_shielded_count_log_k", ACC_SHIELDED_COUNT_LOG_K );
        c = getdvarfloat( "acc_shielded_count_log_c", ACC_SHIELDED_COUNT_LOG_C );

        n = int( ( k * acc_utility::acc_log2( round_number ) ) - c );
        if ( n < 2 ) n = 2;   // floor BEFORE the player mult: a shield round is never worth < 2 at 1p

        n = int( n * acc_coop_scaling::elite_count_player_mult() );
        if ( n < 2 ) n = 2;
        return n;
    }
    return 0;
}

function spawn_elites_over_round( quota, round_number )
{
    level endon( "end_game" );
    level endon( "acc_round_end" );

    // SHIELD-ROUND pacing (user 2026-06-22): the quota now equals the round number (r8 -> 8 shields), so
    // the old 38s elite spacing would only fit ~2 of them before the round ended. Spread them ~3s apart
    // (live dvar) so the whole batch actually arrives. endon("acc_round_end") still cuts the batch short if
    // the round is cleared early, and the ~24-AI cap throttles how many are concurrently alive.
    spacing_sec = getdvarfloat( "acc_shielded_spacing", 3.0 );
    if ( spacing_sec < 0.5 ) spacing_sec = 0.5;

    for ( i = 0; i < quota; i++ )
    {
        wait( spacing_sec );
        // VERIFIED(acc): 'class' is a reserved GSC keyword (TOKEN_CLASS) -
        // cannot be a variable name. First-compile finding 2026-06-12.
        elite_class = pick_elite_class_for_round( round_number );
        spawn_elite( elite_class );
    }
}

function pick_elite_class_for_round( round_number )
{
    // Teleporter + EMP elites REMOVED (user 2026-06-22). Shielded is the only elite class now, so every
    // elite spawn is a Shielded zombie. (promote_to_teleporter / promote_to_emp + the EMP on-hit debuff
    // remain defined below but are now UNREACHABLE - never picked here, so they never spawn.)
    return "shielded";
}

// ---------------------------------------------------------------------------
// Elite spawning
// ---------------------------------------------------------------------------

function spawn_elite( class_name )
{
    spawner = pick_elite_spawner();
    if ( !isdefined( spawner ) )
    {
        acc_utility::log( "elites: no spawner found, skipping" );
        return;
    }

    zombie = zombie_utility::spawn_zombie( spawner );
    if ( !isdefined( zombie ) ) return;

    // VERIFIED(acc): zombie_spawn_init (_zm_spawner.gsc:295) runs as a
    // frame-end spawn func ('waittillframeend', spawner_shared.gsc:581) and
    // resets health/maxhealth - promoting before it completes gets clobbered.
    // Wait pattern from _zm_ai_faller.gsc:168-171.
    // Capped iteration (n<100) so a culled-but-defined / never-init actor can't tie this spawn thread up
    // for the rest of the round - matches the cap EVERY other spawn_zombie init-wait already uses
    // (_acc_boss_glitch:415, _acc_reactor:328, _acc_paradise:511, _acc_boss_phantom:442). The caller's
    // endon("acc_round_end") already prevents a cross-round hang; this just bails a stuck spawn cleanly so
    // the round's remaining elite quota still spawns. ~100 network frames >> a normal 1-frame init, so a
    // valid zombie is never skipped (co-op audit 2026-06-27).
    n = 0;
    while ( isdefined( zombie ) && !isdefined( zombie.zombie_init_done ) && n < 100 )
    {
        util::wait_network_frame();
        n++;
    }
    if ( !isdefined( zombie ) || !isalive( zombie ) || !isdefined( zombie.zombie_init_done ) ) return;

    zombie.acc_is_elite = true;
    zombie.acc_elite_class = class_name;

    switch ( class_name )
    {
    case "shielded":   promote_to_shielded( zombie );   break;
    case "teleporter": promote_to_teleporter( zombie ); break;
    case "emp":        promote_to_emp( zombie );        break;
    }

    level.acc_elite_active_count += 1;
    acc_utility::log( "spawned elite: " + class_name );
}

function pick_elite_spawner()
{
    // VERIFIED(acc): get_active_zombie_spawners does not exist in stock.
    // level.zombie_spawners is the stock spawner list - stock round_spawning
    // itself picks array::random( level.zombie_spawners ) (_zm.gsc:3804);
    // zone-aware placement is handled downstream by the zombie_location system.
    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
    {
        return undefined;
    }
    return level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];
}

// ---------------------------------------------------------------------------
// Class-specific promotions
//
// Every promotion multiplies HP by acc_coop_scaling::special_hp_mult() - the
// flat elite co-op curve (1.0 solo / 1.5 / 2.0 / 2.5 at 2/3/4 players;
// docs/08_enemies.md "Co-op Scaling": elites gain +50% HP per extra player,
// flatter than regular zombies so duos don't blender them). Sampled at
// promote time so mid-game joins are reflected on the next elite.
// ---------------------------------------------------------------------------

// self = the Shielded zombie the Thundergun blast hit. Deliberate no-op (immunity): no fling,
// no damage, no ragdoll (user 2026-07-03 "make shield zombies immune to the thundergun").
// A DEFINED fling func makes stock _zm_weap_thundergun skip its weaponless one-shot path
// (the Avogadro vendor pattern); the acc fractional boss system never clobbers a set func.
function shielded_thundergun_immune( player )
{
}

function promote_to_shielded( z )
{
    // Re-entrancy guard (user 2026-06-25): BOTH the round-based shield spawn AND the depth-scaled abyss roll
    // can target a zombie - promote ONCE (a 2nd call would 25x HP + double the shield model + reward thread).
    if ( !isdefined( z ) || IS_TRUE( z.acc_is_shielded ) ) return;
    z.acc_is_shielded = true;

    // THUNDERGUN IMMUNITY (user 2026-07-03): Shielded elites shrug the blast off entirely.
    z.thundergun_fling_func = &shielded_thundergun_immune;

    // HP = EXACTLY 4x a NORMAL zombie's current health, at ANY player count (user 2026-07-04: 5x -> 4x, "5x is
    // too much"). By promote time z.maxhealth IS the round's normal-zombie HP WITH the co-op regular +100%/player
    // mult already baked in (acc_coop_scaling at zombie_init_done), so a FLAT x4 keeps the Shielded a clean 4x a
    // normal zombie. Do NOT multiply special_hp_mult() here - that DOUBLE-counts co-op (it earlier made a 2p
    // Shielded ~4.5x a 2p zombie instead of a clean multiple); coop_scaling's own comment forbids stacking it on
    // a maxhealth that already carries regular_hp_mult.
    base_hp = z.maxhealth;
    z.maxhealth = int( base_hp * 4 );
    z.health = z.maxhealth;
    z.acc_elite_front_damage_resist = 0.25; // take 25% from front (OC tier pierces this - _acc_damage effect 4/4)

    // ARMORED SKIN (user 2026-07-03): the SPIKES + CHAIN-ARMOR BOTD body is the Shielded
    // elite's EXCLUSIVE look, map-wide. Default body3 (the user distinguished it from the
    // "just barbed wire" body1, which is the TRENCH zombie's skin - _acc_trench_skins; body1's
    // bin has the barbwire material, so chain-armor = body2 or body3). If 3 isn't the spiked
    // one, flip `acc_armored_body 2` LIVE - no rebuild (0 = off/charred). no_gib = the armor
    // NEVER comes off (user rule) - stock-honored flag (zombie_utility checks it; Margwa/Mechz
    // precedent). If the zombie was already trench-skinned (underground spawn, 0.3s-delayed
    // roll may have run first), detach whichever mob head it attached (Detach of a not-attached
    // model is a safe no-op) so the armored head can't double up.
    n_body = getdvarint( "acc_armored_body", 3 );
    if ( n_body >= 1 && n_body <= 3 )
    {
        z SetModel( "c_t8_zmb_mob_zombie_body" + n_body );
        z Detach( "c_zom_dlc4_zombie_charred_head" );
        z Detach( "c_t8_zmb_mob_zombie_head1" );
        z Detach( "c_t8_zmb_mob_zombie_head2" );
        z Detach( "c_t8_zmb_mob_zombie_head3" );
        z Detach( "c_t8_zmb_mob_zombie_head4" );
        z Attach( "c_t8_zmb_mob_zombie_head" + getdvarint( "acc_armored_head", 1 ) );
        z.no_gib = true;
        z.acc_trench_skinned = true;   // belt-and-braces: the trench roll also guards on acc_is_shielded
    }

    // Back rocket-shield attach REMOVED (user 2026-07-03): it was the visual tell from the
    // charred-skin era - the CHAIN-ARMOR body above is the tell now. (The
    // wpn_t7_zmb_zod_rocket_shield_world zone line stays - the Rocket Shield boss item uses it.)
    // Was: z Attach( "wpn_t7_zmb_zod_rocket_shield_world", "j_spine4" );

    // Heavy half-pace WALK gait (user 2026-06-22) - ~half the round's jog, natural (no slow-mo). See think.
    // Set the keep-alive skip-flag SYNCHRONOUSLY here (not only inside the threaded think) so the frame-N+1
    // on-spawn speed hook reliably sees it and never writes a "sprint" override onto this actor before the
    // think's first re-pin runs - closes the spawn-order race at the source (user 2026-06-28).
    z.acc_boss_custom_speed = true;
    z thread shielded_speed_think();

    // Reward (user 2026-06-22; 2 -> 3 shards user 2026-07-13): killing the "Riot" (Shielded) elite gives the KILLER 3 Data Shards.
    z thread shielded_death_reward();
}

// self = a Shielded ("Riot") elite. The player who lands the kill gets 3 Data Shards (user 2026-07-13, was 2).
// "riot_elite" source = a FLAT grant (not the diminishing "elite_kill" tag). #using _acc_data_shards present.
function shielded_death_reward()
{
    self waittill( "death", attacker );
    // Reactor-surge (or any future "purge") Shielded grant NO shards - a survive-the-gauntlet THREAT, not a
    // farm, same as the glitch purge (user 2026-06-24). The reactor sets this flag before promote_to_shielded.
    if ( isdefined( self.acc_no_shard_reward ) && self.acc_no_shard_reward )
        return;
    if ( isdefined( attacker ) && isplayer( attacker ) )
    {
        acc_data_shards::grant_player( attacker, 3, "riot_elite" );
        acc_leveling::grant_elite_xp( attacker, "riot" );   // [acc] leveling: priority-brute kill bonus (docs/45)
    }
}

// self = a Shielded elite. A HEAVY, half-pace lumberer. The naive way to do "50% slower" - lock the round's
// run/sprint gait and play it at 0.5x rate - IS true 50% ground speed, but the engine renders any anim rate
// <1.0 as SLOW-MOTION (the documented zombie-speed constraint), so it looked like it was crawling/floating,
// not just half-pace (user 2026-06-22: "why does it move so slow"). FIX: use the naturally-slow WALK gait at
// NATURAL (>=1.0) cadence instead. A walk is INHERENTLY ~half a jog and animates correctly (no slow-mo), so
// the shield brute reads as a proper heavy half-speed zombie. The rate creeps with the round (rate_for_round)
// like the horde, so it stays slow-but-not-frozen. acc_boss_custom_speed makes the global _acc_zombie_speed
// keep-alive SKIP this actor (no two writers fighting); NO SetScale (the 0xC0000005 live-AI crasher). Re-
// asserted on a cadence (round/state changes clobber the override). Tune: acc_shielded_walk_rate (default 1.2
// = a BIT faster than the natural walk, user 2026-06-24; 1.0 = natural walk, raise more for a faster brute -
// still no slow-mo, since walk is the slow gait). NOTE the
// trade vs the old 0.5x: speed is now the walk anim's pace, not a math-exact 50% of the horde's current gait
// - but it LOOKS right (no slow-mo). At high SPRINT rounds it reads slower-than-50% relative; bump the rate.
function shielded_speed_think()
{
    self endon( "death" );
    level endon( "end_game" );

    self.acc_boss_custom_speed = true; // _acc_zombie_speed keep-alive skips us

    for ( ;; )
    {
        if ( !isalive( self ) ) return;

        r    = acc_zombie_speed::current_round();
        rate = acc_zombie_speed::rate_for_round( r ) * getdvarfloat( "acc_shielded_walk_rate", 1.2 );  // 1.0 -> 1.2: a BIT faster walk (user 2026-06-24)
        if ( rate < 1.0 ) rate = 1.0;   // never below natural cadence => never slow-mo

        // Re-pin to WALK only on drift. CRITICAL: clear the stock override-LOCK first. set_zombie_run_cycle()
        // early-returns if self.zombie_move_speed_override is already defined (zombie_utility.gsc), so once the
        // frame-N+1 on-spawn speed hook (or any round re-eval) writes the horde tier ("sprint" at round >=15)
        // onto this actor, our "walk" call is SILENTLY DROPPED and the elite keeps the sprint gait FOREVER - it
        // spawns fast and never slows (user 2026-06-28: "shield zombie ran faster than a normal zombie + never
        // changed speed"). Mirror _acc_zombie_speed::apply_speed_for_round (line 227-233: clear, then set) so
        // the downgrade always lands.
        if ( self.zombie_move_speed != "walk" ||
             !isdefined( self.zombie_move_speed_override ) ||
             self.zombie_move_speed_override != "walk" )
        {
            self.zombie_move_speed_override = undefined;
            self zombie_utility::set_zombie_run_cycle_override_value( "walk" );   // slow heavy gait (was run/sprint @ 0.5x = slow-mo)
        }
        self ASMSetAnimationRate( rate );
        wait 1;
    }
}

function promote_to_teleporter( z )
{
    // Frailer than shielded. Gets a teleport ability on cooldown.
    z.maxhealth = int( z.maxhealth * 0.8 * acc_coop_scaling::special_hp_mult() );
    z.health = z.maxhealth;
    z thread teleporter_ability_loop();

    // Visual tell (docs/09): recoloured eyes mark this elite vs the horde, using the SAME client-side
    // eye-tint path as the Glitch Stalker (accEyeTint clientfield -> _acc_lui.csc eye_tint_cb,
    // mapshaderconstant; NO FX asset). NOTE: the existing accEyeTint field is a single on/off bit and
    // the colour comes from ONE global dvar (acc_glitch_eye_color), so all tinted actors share the
    // SAME colour today - a DISTINCT magenta tint needs the field/.csc colour-map extended in _acc_lui
    // (outside this module's edit scope; see problems[]). Tinted-vs-untinted still distinguishes elites.
    acc_lui::set_actor_eye_tint( z, true );
}

function teleporter_ability_loop()
{
    self endon( "death" );

    for ( ;; )
    {
        wait( 8 + randomfloat( 4 ) ); // 8-12s cooldown

        target = acc_utility::get_closest_player_to( self.origin );
        if ( !isdefined( target ) ) continue;

        // VERIFIED(acc): clamp the computed point to the navmesh first -
        // stock pattern shared/ai/zombie.gsc:1192-1212 (GetClosestPointOnNavMesh
        // then ForceTeleport); raw offsets can land inside geometry/off-mesh.
        flank_pos = GetClosestPointOnNavMesh( target.origin + ( 300, 0, 0 ), 100, 30 );
        if ( !isdefined( flank_pos ) )
        {
            continue;
        }
        self forceteleport( flank_pos );
        // TODO(acc-fx): play teleport FX on both source and destination.
    }
}

function promote_to_emp( z )
{
    z.maxhealth = int( z.maxhealth * 1.5 * acc_coop_scaling::special_hp_mult() );
    z.health = z.maxhealth;
    z.acc_emp_on_hit = true; // consumed by on_player_damaged below

    // Visual tell (docs/09): recoloured eyes mark this elite vs the horde (same accEyeTint client path
    // as the Glitch Stalker / Teleporter). NOTE: a DISTINCT electric-blue tint (different from the
    // Teleporter's intended magenta) is NOT possible through the current 1-bit field + single global
    // colour dvar - it needs accEyeTint widened to carry a per-actor colour index plus a colour map in
    // _acc_lui.csc (outside this module's edit scope; see problems[]). Tint still flags it as an elite.
    acc_lui::set_actor_eye_tint( z, true );
}

// ---------------------------------------------------------------------------
// EMP elite on-hit debuff (docs/08_enemies.md: melee hit drains 200 points
// and locks the player's active Cyberware ability for 5s)
// ---------------------------------------------------------------------------

// Registered via zm::register_player_damage_callback in init(). Runs ON the
// damaged player (dispatch _zm.gsc:5511) for EVERY player damage event - keep
// the reject paths cheap. Return -1 = leave the damage unchanged.
function on_player_damaged( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
    if ( !isdefined( iDamage ) || iDamage <= 0 ) return -1;

    // This hook fires BEFORE player_damage_override's laststand/god-mode checks (_zm.gsc:5110 vs
    // :5137) - don't act on downed/invalid players.
    if ( !zm_utility::is_player_valid( self ) ) return -1;

    // SENTRY DRONE rocket self-splash NEGATION (2026-07-24, adversarial-review catch): the drone's
    // launcher secondary MagicBullets a REAL s1_mahem attributed to the OWNER (so kills credit them),
    // and stock Callback_PlayerDamage's self-damage whitelist (_zm.gsc:1435) lets an OWN-rocket
    // MOD_PROJECTILE_SPLASH through at s1_mahem's raw ~3100 = an instant self-down whenever a crossing
    // zombie detonates the rocket near the owner (the RP mahem cap below never applies - it is gated on
    // eAttacker.acc_is_rogue_protector, and here eAttacker IS the player). The native rocket is only
    // the VISUAL (the real kill is the drone's scripted zombie-only AoE), so during a drone-rocket
    // flight window (acc_drone_rocket_until, a self-expiring timestamp refreshed by the missile watch
    // in _acc_boss_items::sentry_rocket_watch) a self-attributed mahem hit is ZEROED. Window-gated on
    // purpose: a hand-FIRED box Mahem outside the window keeps its normal self-splash risk. Teammates
    // never needed a lane (stock: "players can't hurt each other", _zm.gsc:1427).
    if ( isdefined( eAttacker ) && eAttacker == self
         && isdefined( weapon ) && isdefined( weapon.name ) && IsSubStr( weapon.name, "mahem" )
         && isdefined( self.acc_drone_rocket_until ) && GetTime() < self.acc_drone_rocket_until )
        return 0;

    final = iDamage;

    // Zombie MELEE only for the EMP + trench bump. VERIFIED(acc): zombie melee on players arrives as
    // meansofdeath "MOD_MELEE" (shared/ai/zombie.gsc:402 / engine Melee()).
    b_melee = ( isdefined( sMeansOfDeath ) && sMeansOfDeath == "MOD_MELEE" );
    if ( b_melee )
    {
        // EMP elite on-hit debuff (side effect; leaves the damage value alone).
        if ( isdefined( eAttacker ) && IS_TRUE( eAttacker.acc_emp_on_hit ) )
            self apply_emp_melee_debuff();

        // TRENCH per-layer melee bump (user 2026-06-21): a melee hit while you're in trench layer L hits
        // for +acc_trench_layer_dmg_add HP per layer (flat). This is the ONLY reliable lever - open-field
        // zombie melee deals engine Melee() WEAPON damage and ignores self.meleeDamage, so we scale the
        // INCOMING hit here.
        final = acc_bus_trench::trench_melee_scaled( self, final );

        // PHANTOM chain-special SLOW is now applied from the Phantom SIDE (_acc_boss_phantom::phantom_chain, on
        // the blink-strike), NOT here (user 2026-06-25). Reason: it must land even in GOD MODE, where
        // EnableInvulnerability suppresses this whole damage callback - so a damage-gated slow never fired and the
        // speed effect couldn't be tested while invulnerable. acc_phantom_chain_zap() (below) is unchanged and now
        // called from there. (Was: self acc_phantom_chain_zap() gated on eAttacker.acc_phantom_chaining.)
    }

    // (ROGUE PROTECTOR: his BULLETS are now PURE 25 damage - the 25% slow moved to his SEPARATE
    // close-range ZAP attack, user 2026-07-03 "two attacks, shooting and zapping". The zap is
    // applied directly from _acc_civil_protector::zap_loop via acc_protector_zap(), NOT on bullet
    // hits - so no trigger here. acc_protector_zap()/acc_protector_slow_clear() stay below.)

    // ROGUE PROTECTOR - PROXIMITY DAMAGE (user 2026-07-05: "more damage the closer he is"): his
    // BULLETS scale on a LINEAR ramp over Distance(boss, player) - full acc_protector_close_mult (3x)
    // at/inside close_range, tapering to 1.0 (unchanged) at/beyond far_range. Applied BEFORE exo/savior
    // so the player's resistances reduce the boosted value. eAttacker = the boss; his hits route here
    // (register_player_damage_callback). THREE lanes since 2026-07-09:
    //   ROCKET (the visible s1_mahem projectile fire_loop now fires - weapon name says "mahem", or any
    //     MOD_PROJECTILE_SPLASH): the raw weapon damage is a 3100 one-shot - HARD-CAP it to
    //     acc_protector_mahem_dmg + the BIG knockback. This cap is what makes the real rocket usable.
    //   ZAP PULSE (MOD_GRENADE_SPLASH): untouched here (exact scripted 10 from zap_loop).
    //   BULLETS (everything else from him): fixed base + proximity ramp + max cap + the small knockback.
    if ( isdefined( eAttacker ) && IS_TRUE( eAttacker.acc_is_rogue_protector ) && isdefined( sMeansOfDeath ) )
    {
        b_rp_mahem = ( ( isdefined( weapon ) && isdefined( weapon.name ) && IsSubStr( weapon.name, "mahem" ) )
                       || sMeansOfDeath == "MOD_PROJECTILE_SPLASH" );
        if ( b_rp_mahem )
        {
            // ROCKET CAP: keep the engine's blast falloff shape but never exceed the design value
            // (s1_mahem raw playerDamage would one-shot; the old invisible scripted RadiusDamage was 50).
            mahem_dmg = getdvarint( "acc_protector_mahem_dmg", 69 );   // [acc] RP ROCKET +25% (user 2026-07-12: 55 -> 69)
            if ( final > mahem_dmg ) final = mahem_dmg;
            if ( final < 1 ) final = 1;
            // KNOCKBACK (user 2026-07-09): the rocket blast shoves you hard away from the boss.
            // [acc] user 2026-07-18 +25% RP knockback: 320 -> 400 (bullets 160 -> 200 below; the fixed
            // z_pop lift is deliberately NOT scaled - it only exists to defeat ground friction).
            self thread rp_knockback( eAttacker, getdvarfloat( "acc_protector_mahem_knockback", 400 ), 110 );
        }
        else if ( sMeansOfDeath != "MOD_GRENADE_SPLASH" )
        {
        // BULLET damage is fully CONTROLLED here (user 2026-07-05: he was ONE-HITTING - "before he did 25 ...
        // he should max do 60"). OVERRIDE the raw MagicBullet weapon damage with a fixed base (the far-range
        // value), apply the proximity ramp up to close_mult, then HARD-CAP at acc_protector_max_dmg (60) so he
        // can NEVER one-shot regardless of the weapon or the buff. (28 base x 3.0 close = 84 -> clamped to 60.)
        // Base 25 -> 28 (user 2026-07-09: "very slightly buff the Rogue Protector damage"; cap unchanged).
        base_dmg    = getdvarint(   "acc_protector_bullet_dmg", 28 );
        max_dmg     = getdvarint(   "acc_protector_max_dmg",    60 );
        close_mult  = getdvarfloat( "acc_protector_close_mult",  3.0 );
        close_range = getdvarfloat( "acc_protector_close_range", 150 );
        far_range   = getdvarfloat( "acc_protector_far_range",   1000 );
        final = base_dmg;
        if ( close_mult > 1.0 && far_range > close_range )
        {
            dist = Distance( eAttacker.origin, self.origin );
            if ( dist <= close_range )
                mult = close_mult;
            else if ( dist >= far_range )
                mult = 1.0;
            else
                mult = 1.0 + ( close_mult - 1.0 ) * ( ( far_range - dist ) / ( far_range - close_range ) );
            final = int( base_dmg * mult );
        }
        if ( final > max_dmg ) final = max_dmg;   // *** THE CAP: max 60, never a one-shot ***
        if ( final < 1 ) final = 1;
        // KNOCKBACK (user 2026-07-09: "add knock back to his shots"): a light shove per bullet.
        self thread rp_knockback( eAttacker, getdvarfloat( "acc_protector_knockback", 200 ), 45 );
        }
    }

    // PANZER +10% (user 2026-07-18 "buff Panzer damage by 10%"): his ELECTROBALL explosion damage is
    // engine/GDT-side (the 115 grenade - _acc_boss_panzer only owns the impact-detonate + zap slow), so
    // the +10% for that lane is applied HERE, before mitigations - same spot the RP lanes shape their
    // damage. Melee rides acc_panzer_melee_damage (90 -> 99, mechz_spiki callback) and the flamethrower
    // acc_panzer_flame_mult (1.1 -> 1.21) - this lane covers the one engine-side source.
    if ( isdefined( eAttacker ) && IS_TRUE( eAttacker.acc_is_panzer ) && isdefined( sMeansOfDeath )
         && IsSubStr( sMeansOfDeath, "GRENADE" ) )
    {
        final = int( final * getdvarfloat( "acc_panzer_explosive_mult", 1.1 ) );
        if ( final < 1 ) final = 1;
    }

    // EXO SUIT resistance + SAVIOR (Mega Quick Revive) revive DR. Extracted to apply_player_mitigations() so
    // any EARLY-chain damage override that short-circuits this function (the mechz/Panzer melee callback)
    // applies the SAME armor - otherwise that boss's melee silently ignores the Exo/Savior progression
    // (audit 2026-07-12). Applied AFTER the trench melee bump so it resists the bumped value too.
    final = self apply_player_mitigations( final );

    // GOD MODE = DEMIGOD (user 2026-07-08, refactor of the 2026-06-27 zero-damage god): damage LANDS
    // FOR REAL - you see and feel exactly what every zombie/boss hit deals - but health is FLOORED AT
    // 1 HP, so death/downs stay impossible ("I can't die but I can still test how much damage they
    // do"). Every per-hit EFFECT above has already fired (EMP debuff, trench melee scaling; the
    // Phantom chain slow runs Phantom-side). Implementation: clamp the outgoing damage to
    // (health - 1) at THIS event's health snapshot - sequential hits re-read health, so a burst can
    // park you at exactly 1 HP but never below. (The old return 0 zeroed every hit - no damage
    // numbers, no HP movement, nothing to test against. The pre-2026-06-27 EnableInvulnerability
    // god blocked this whole callback.) level.acc_god is the entry-script flag (default OFF in
    // normal play, so this is a no-op there). NOTE FOR NEW DAMAGE CALLBACKS: this clamp only
    // protects damage that REACHES this callback - a callback registered EARLIER in the chain that
    // returns its own value short-circuits us (the mechz melee did exactly that and killed a godded
    // player, 2026-07-08) - any such override must carry its own acc_god demigod clamp (memory
    // player-damage-callbacks-return-minus-one).
    if ( IS_TRUE( level.acc_god ) )
    {
        if ( final >= self.health )
            final = self.health - 1;
        if ( final < 0 )
            final = 0;
        return final;
    }

    // Return the modified damage (check_player_damage_callbacks uses the first != -1 return,
    // _zm.gsc:5512); -1 = leave unchanged (no exo, non-melee = identical to before).
    if ( final != iDamage )
        return final;

    return -1; // unchanged
}

// Shared player-damage mitigations: EXO SUIT resistance + SAVIOR (Mega Quick Revive) revive DR.
// self = the hit PLAYER; returns the mitigated damage (both capped/floored at 1 so you stay killable).
// Exo: each tier reduces ALL incoming damage by acc_exo_resist_per_tier (default 4%/tier, cap 0.80;
// user 2026-07-13 nerf 6% -> 4%).
// Savior: 50% damage while reviving a teammate; stacks multiplicatively with Exo (applied second).
// EXTRACTED 2026-07-12 (audit): any damage callback registered EARLIER in the chain than on_player_damaged
// (the mechz/Panzer MOD_MELEE override) short-circuits that function, so it must call THIS to give the player
// the same armor - otherwise Panzer melee alone ignores the Exo/Savior investment. Apply BEFORE any demigod clamp.
function apply_player_mitigations( dmg )
{
    exo_tier = ( isdefined( self.acc_exo_tier ) ? self.acc_exo_tier : 0 );
    if ( exo_tier > 0 )
    {
        resist = exo_tier * getdvarfloat( "acc_exo_resist_per_tier", 0.04 );
        if ( resist > 0.80 ) resist = 0.80;
        dmg = int( dmg * ( 1.0 - resist ) );
        if ( dmg < 1 ) dmg = 1;
    }

    savior_dr = acc_perks::savior_revive_damage_mult( self );
    if ( savior_dr < 1.0 )
    {
        dmg = int( dmg * savior_dr );
        if ( dmg < 1 ) dmg = 1;
    }

    // HIVE NODE (boss item 14, user 2026-07-16): a support carrier's aura shields everyone inside it, and its
    // active "Bloom" burst drops a strong short shield. Both ride SELF-EXPIRING timestamps set in _acc_boss_items
    // (acc_hive_covered_until = passive aura, acc_hive_bubble_until = burst) - plain self fields, no cross-module
    // call. Stacked multiplicatively with Exo + Savior (applied last), each floored at 1 so you stay killable.
    if ( isdefined( self.acc_hive_covered_until ) && gettime() < self.acc_hive_covered_until )
    {
        hive_dr = getdvarfloat( "acc_hive_dr", 0.15 );
        if ( hive_dr > 0 )
        {
            dmg = int( dmg * ( 1.0 - hive_dr ) );
            if ( dmg < 1 ) dmg = 1;
        }
    }
    if ( isdefined( self.acc_hive_bubble_until ) && gettime() < self.acc_hive_bubble_until )
    {
        hive_bubble = getdvarfloat( "acc_hive_bubble_dr", 0.50 );
        if ( hive_bubble > 0 )
        {
            dmg = int( dmg * ( 1.0 - hive_bubble ) );
            if ( dmg < 1 ) dmg = 1;
        }
    }

    return dmg;
}

// PHANTOM CHAIN-special on-hit zap (user 2026-06-24; called from _acc_boss_phantom::phantom_chain since 2026-06-25).
// self = the hit player. Plays the electric-zap SFX (the special connected) and applies a brief -25% move slow
// (acc_phantom_slowed -> read by recompute_move_speed). Driven Phantom-side (not the damage callback) so it lands
// even under GOD MODE. Mega ELECTRIC CHERRY "Power Surge" is IMMUNE to the slow.
function acc_phantom_chain_zap()
{
    // [acc] NO endon("disconnect") here: this helper is CALLED INLINE from the Phantom's teleport loop
    // (_acc_boss_phantom.gsc), so an endon would bind to the BOSS thread and silently kill the Phantom's
    // attack loop when this player disconnects. The function has no wait; the timed part runs in the
    // separately-threaded acc_phantom_slow_clear() which carries its own disconnect endon.
    if ( !isdefined( self ) )
        return;

    // Battery boss item (user 2026-07-08): absorb the zap when READY (fresh +20% surge + aura + SFX) OR while a
    // surge is already ACTIVE (a 2nd zap inside the 5s window can't hinder your boost). Only a zap during the
    // post-surge recharge (5-10s) slows you normally. See acc_battery_absorb_zap.
    if ( self acc_battery_absorb_zap() )
        return;

    self PlaySound( "acc_phantom_zap" );

    // Mega Electric Cherry "Power Surge" NO LONGER grants full immunity - it now SOFTENS the stun to -10%
    // instead of the normal -25% (user 2026-07-03, was a hard return/immune). Mega flag read straight off the
    // player field (persistent mega flag AND currently holds the perk); recompute_move_speed picks the softened
    // 0.90 vs the normal 0.75 multiplier off acc_phantom_slow_mega.
    self.acc_phantom_slow_mega = ( isdefined( self.acc_mega_perks ) && IS_TRUE( self.acc_mega_perks[ "specialty_combat_efficiency" ] )
                                   && self HasPerk( "specialty_combat_efficiency" ) );

    self.acc_phantom_slowed = true;
    acc_utility::recompute_move_speed( self );

    self notify( "acc_phantom_slow_restart" );   // a fresh chain hit refreshes the slow window
    self thread acc_phantom_slow_clear();
}

// ROGUE PROTECTOR on-hit zap (user 2026-07-03): the Phantom zap shape, -25% slow
// (acc_protector_slow_mult in recompute_move_speed) so the hit is unmistakably felt. Mega
// Electric Cherry "Power Surge" softens it to -10% (not full immunity); 3s window, re-hit refreshes.
function acc_protector_zap()   // self = the hit player
{
    // [acc] NO endon("disconnect"): called inline from _acc_civil_protector::zap_loop, so an endon would
    // bind to the Protector's zap-loop thread and kill it on this player's disconnect. Timed part is in
    // the separately-threaded acc_protector_slow_clear() (which keeps its own endon). See acc_phantom_chain_zap.
    if ( !isdefined( self ) )
        return;

    // Battery boss item: absorb the zap (fresh surge if ready, or protect the active surge); only a zap
    // during the post-surge recharge slows normally. See acc_battery_absorb_zap.
    if ( self acc_battery_absorb_zap() )
        return;

    self PlaySound( "acc_phantom_zap" );

    // Mega Electric Cherry "Power Surge" softens this stun to -10% instead of full immunity (user 2026-07-03).
    self.acc_protector_slow_mega = ( isdefined( self.acc_mega_perks ) && IS_TRUE( self.acc_mega_perks[ "specialty_combat_efficiency" ] )
                                     && self HasPerk( "specialty_combat_efficiency" ) );

    self.acc_protector_slowed = true;
    acc_utility::recompute_move_speed( self );

    self notify( "acc_protector_slow_restart" );
    self thread acc_protector_slow_clear();
}

function acc_protector_slow_clear()   // self = the slowed player
{
    self endon( "disconnect" );
    self endon( "acc_protector_slow_restart" );
    wait( getdvarfloat( "acc_protector_slow_sec", 3.0 ) );
    self.acc_protector_slowed = false;
    acc_utility::recompute_move_speed( self );
}

// ROGUE PROTECTOR shot KNOCKBACK (user 2026-07-09): one horizontal impulse away from the boss +
// a small pop of lift so the engine actually registers it mid-ground-friction. SetVelocity on a
// PLAYER is the stock jump-pad idiom (_zm_jump_pad.gsc); a single additive impulse (not the pad's
// sustain loop) reads as recoil, not a launch. Threaded from on_player_damaged so a throw there
// can never break the damage-callback chain. self = the hit player, boss = the Rogue Protector.
function rp_knockback( boss, strength, z_pop )
{
    if ( !isdefined( self ) || !isplayer( self ) || !isdefined( boss ) )
        return;
    if ( strength <= 0 )
        return;   // acc_protector_knockback 0 = knockback off

    dir = self.origin - boss.origin;
    dir = ( dir[ 0 ], dir[ 1 ], 0 );   // horizontal shove; the lift is the fixed z_pop below
    if ( LengthSquared( dir ) < 1 )
        dir = AnglesToForward( ( 0, self.angles[ 1 ] + 180, 0 ) );   // on top of the boss: shove backwards
    dir = VectorNormalize( dir );

    self SetVelocity( self GetVelocity() + VectorScale( dir, strength ) + ( 0, 0, z_pop ) );
}

// Lift the Phantom slow after acc_phantom_slow_sec (default 3s); a re-hit restarts it via the notify above.
function acc_phantom_slow_clear()   // self = the slowed player
{
    self endon( "disconnect" );
    self endon( "acc_phantom_slow_restart" );
    wait( getdvarfloat( "acc_phantom_slow_sec", 3.0 ) );
    self.acc_phantom_slowed = false;
    acc_utility::recompute_move_speed( self );
}

// AVOGADRO "cyberhacker" on-shot zap (user 2026-07-04): identical shape to the Rogue zap - a 30% move
// slow (acc_avogadro_slow_mult in recompute_move_speed; user 2026-07-05, was 25%), 3s window, refreshes on
// re-hit, Mega Electric Cherry "Power Surge" softens it to -10%. His shot does NO damage - this stun IS the
// whole threat; at ~1.6 shots/sec on a nearby player the window keeps refreshing so you stay slowed. Driven
// from his own fire_loop (not a damage callback), so it lands under god mode.
function acc_avogadro_zap()   // self = the hit player
{
    // [acc] NO endon("disconnect"): called inline from Avogadro's aura_loop/bolt_watchdog/fire loop
    // (_acc_boss_avogadro.gsc), so an endon would bind to the BOSS thread and kill his attack loop when
    // this player disconnects. Timed part is in the threaded acc_avogadro_slow_clear(). See acc_phantom_chain_zap.
    if ( !isdefined( self ) )
        return;

    // Battery boss item: absorb the zap (fresh surge if ready, or protect the active surge); only a zap
    // during the post-surge recharge slows normally. See acc_battery_absorb_zap.
    if ( self acc_battery_absorb_zap() )
        return;

    self PlaySound( "acc_phantom_zap" );

    self.acc_avogadro_slow_mega = ( isdefined( self.acc_mega_perks ) && IS_TRUE( self.acc_mega_perks[ "specialty_combat_efficiency" ] )
                                    && self HasPerk( "specialty_combat_efficiency" ) );

    self.acc_avogadro_slowed = true;
    acc_utility::recompute_move_speed( self );

    self notify( "acc_avogadro_slow_restart" );
    self thread acc_avogadro_slow_clear();
}

function acc_avogadro_slow_clear()   // self = the slowed player
{
    self endon( "disconnect" );
    self endon( "acc_avogadro_slow_restart" );
    wait( getdvarfloat( "acc_avogadro_slow_sec", 3.0 ) );
    self.acc_avogadro_slowed = false;
    acc_utility::recompute_move_speed( self );
}

// BATTERY boss item surge (user 2026-07-08): shared absorb path for ALL THREE boss zaps (Phantom chain /
// Rogue Protector / Avogadro). A zap on a READY Battery holder is fully replaced - no slow, no mega-softening,
// instead a +24% move boost (acc_battery_boost_mult in recompute_move_speed; user 2026-07-22 +20% buffed by
// 20% -> 1.24) for 5s (acc_battery_boost_sec) +
// a light blue-green full-screen aura (battery_aura, the trench-warning tint recipe) + own SFX (acc_battery_zap,
// the "electric voltage" wav). COOLDOWN 10s (acc_battery_cooldown_sec; user 2026-07-09, was 12s), one surge per cooldown (NOT a
// refresh-on-re-zap). While the surge is ACTIVE (the 5s window) a second zap is ABSORBED so it can't hinder the
// boost (user 2026-07-08); only a zap during the LATER recharge window (surge ended, cd not up) slows you
// normally. NOT the legacy Kinetic Battery (acc_item_battery, dormant) - the flag is acc_item_volt_battery.

// True if the Battery is implanted AND its absorb cooldown has elapsed (ready to proc a fresh surge).
function acc_battery_ready()   // self = player
{
    if ( !IS_TRUE( self.acc_item_volt_battery ) )
        return false;
    if ( isdefined( self.acc_battery_cd_until ) && GetTime() < self.acc_battery_cd_until )
        return false;   // still recharging
    return true;
}

// Battery zap handling (user 2026-07-08 "a 2nd zap in the surge window shouldn't hinder the boost").
// Returns true if the Battery HANDLED this zap (the caller must then NOT apply its slow):
//   - Mid-surge (acc_battery_boost, the active 5s): ABSORB - protects the running boost from a 2nd zap.
//   - Off cooldown: proc a FRESH +24% surge.
//   - Implanted but recharging (surge already ended, still <12s): returns FALSE -> the caller's slow applies,
//     so you CAN still be slowed during the cooldown - just never while the boost itself is up.
function acc_battery_absorb_zap()   // self = the zapped player
{
    if ( !IS_TRUE( self.acc_item_volt_battery ) )
        return false;                        // not a Battery holder -> normal slow
    if ( IS_TRUE( self.acc_battery_boost ) )
        return true;                         // surge ACTIVE -> absorb, keep the boost intact (no re-slow)
    if ( self acc_battery_ready() )
    {
        self acc_battery_surge();            // off cooldown -> fresh surge
        return true;
    }
    return false;                            // recharging (surge ended) -> caller applies its normal slow
}

function acc_battery_surge()   // self = the zapped player (Battery implanted + off cooldown)
{
    // [acc] NO endon("disconnect"): called inline from the boss zap applicators above, which run on the
    // BOSS's thread - same rule as acc_phantom_chain_zap. Timed part is in acc_battery_boost_clear().
    if ( !isdefined( self ) )
        return;

    self PlaySound( "acc_battery_zap" );

    // Start the 10s recharge NOW so a second zap this window can't re-proc (one surge per cooldown).
    self.acc_battery_cd_until = GetTime() + int( getdvarfloat( "acc_battery_cooldown_sec", 10.0 ) * 1000 );

    self.acc_battery_boost = true;
    acc_utility::recompute_move_speed( self );

    self notify( "acc_battery_boost_restart" );   // cancel any stale clear/aura thread from a prior surge
    self thread acc_battery_boost_clear();
    self thread battery_aura();                    // light blue-green screen tint for the surge window
}

function acc_battery_boost_clear()   // self = the surging player
{
    self endon( "disconnect" );
    self endon( "acc_battery_boost_restart" );
    wait( getdvarfloat( "acc_battery_boost_sec", 5.0 ) );
    self.acc_battery_boost = false;
    acc_utility::recompute_move_speed( self );
}

// Full-screen light blue-green aura while the surge is active - the SAME recipe as the trench "DANGER" red
// tint (_acc_bus_trench::ensure_trench_warning): a 640x480 "white" icon with horzAlign/vertAlign "fullscreen"
// spans the whole screen on any aspect. Per-player, lazily created + reused (hidden alpha 0 between surges).
function battery_aura()   // self = the surging player
{
    self endon( "disconnect" );
    self endon( "acc_battery_boost_restart" );   // a fresh proc (post-cooldown) restarts a clean aura window

    battery_ensure_aura( self );
    if ( !isdefined( self.acc_battery_aura_bg ) )
        return;   // [acc] coop pool-full guard (hud::create returned undefined) - skip the aura this proc

    self.acc_battery_aura_bg fadeovertime( 0.15 );   // quick flash in
    // SUBTLE tint (user 2026-07-08: 0.35 filled the whole screen + hid the player). A light edge-of-screen
    // wash, not a color fill - dial acc_battery_aura_alpha live to taste (0 = off).
    self.acc_battery_aura_bg.alpha = getdvarfloat( "acc_battery_aura_alpha", 0.15 );

    wait( getdvarfloat( "acc_battery_boost_sec", 5.0 ) );

    self.acc_battery_aura_bg fadeovertime( 0.5 );     // gentle fade out at the end of the surge
    self.acc_battery_aura_bg.alpha = 0;
}

function battery_ensure_aura( player )
{
    if ( isdefined( player.acc_battery_aura_bg ) )
        return;
    player.acc_battery_aura_bg = player hud::createIcon( "white", 640, 480 );
    if ( !isdefined( player.acc_battery_aura_bg ) )
        return;   // pool full - caller guards
    player.acc_battery_aura_bg.horzAlign = "fullscreen";
    player.acc_battery_aura_bg.vertAlign = "fullscreen";
    player.acc_battery_aura_bg.alignX = "left";
    player.acc_battery_aura_bg.alignY = "top";
    player.acc_battery_aura_bg.x = 0;
    player.acc_battery_aura_bg.y = 0;
    player.acc_battery_aura_bg.color = ( 0.25, 0.95, 0.80 );   // light blue-green (aqua/teal)
    player.acc_battery_aura_bg.alpha = 0;
    player.acc_battery_aura_bg.sort  = 0;                       // behind HUD text, like the trench bg
    player.acc_battery_aura_bg.hidewheninmenu = true;
}

// Runs on the player. No waits - keeps the damage pipeline synchronous.
function apply_emp_melee_debuff()
{
    // Drain points, clamped so the score can't go negative
    // (minus_to_player_score subtracts blindly, _zm_score.gsc:565).
    n_drain = ACC_ELITE_EMP_HIT_POINT_DRAIN;
    if ( isdefined( self.score ) && n_drain > self.score ) n_drain = self.score; // reading score is fine; WRITES go through zm_score
    if ( n_drain > 0 )
    {
        // VERIFIED(acc): zm_score::minus_to_player_score (_zm_score.gsc:551)
        // is the sanctioned deduction path (same pattern as
        // _acc_events_hack.gsc:80); it syncs self.pers and stats internally.
        self zm_score::minus_to_player_score( n_drain );
    }

    // Active-Cyberware-ability lockout window (docs/08: "Phase Step locked
    // out"). Contract: ability runtimes (_acc_cyberware's Phase Step watcher,
    // _acc_weapon_abilities::try_activate_ability) must refuse activation
    // while gettime() < player.acc_cw_locked_until.
    self.acc_cw_locked_until = gettime() + ( ACC_ELITE_EMP_HIT_DISABLE_SEC * 1000 );
    self notify( "acc_emp_disabled", ACC_ELITE_EMP_HIT_DISABLE_SEC );
    self iprintln( "EMP surge! Cyberware locked for " + ACC_ELITE_EMP_HIT_DISABLE_SEC + "s" );
}

// ---------------------------------------------------------------------------
// Death / drop handling
// ---------------------------------------------------------------------------

// Registered via zm_spawner::register_zombie_death_event_callback in init().
// Runs ON the dying zombie (self) with the attacker as the only arg
// (dispatch: _zm_spawner.gsc:2344 'self [[ callback ]]( attacker )').
function on_elite_zombie_death( attacker )
{
    if ( !isdefined( self.acc_is_elite ) || !self.acc_is_elite )
    {
        return;
    }

    level.acc_elite_active_count = acc_utility::clamp_int( level.acc_elite_active_count - 1, 0, 99 );

    // Trench-only economy (user 2026-06-19): elites are NOT a shard source by default - shards come
    // from the trench (pit caches + Trench Warden + Glitch Altar), so the topside elite drop here is
    // OFF unless re-enabled. Set `acc_elite_shard_drop 1` to restore the 1-shard corpse pickup.
    if ( getdvarint( "acc_elite_shard_drop", 0 ) )
        acc_data_shards::spawn_pickup_at( self.origin, ACC_ELITE_SHARD_REWARD );

    // Subroutine T3 capstone - every 5th elite drops a random pickup.
    if ( isdefined( attacker ) && isplayer( attacker ) && isdefined( attacker.acc_cw_recursion_active ) )
    {
        attacker.acc_cw_recursion_counter += 1;
        if ( attacker.acc_cw_recursion_counter % 5 == 0 )
        {
            drop_recursion_powerup_at( self.origin );
        }
    }
}

function drop_recursion_powerup_at( origin )
{
    // NO drops during the Paradise final battle (user 2026-06-26): the onslaught is a survive-not-farm gauntlet, so
    // suppress even the Subroutine recursion capstone (the generic horde drops are blocked by
    // acc_paradise::block_powerup_drop; this forced drop bypasses that hook, so gate it explicitly here).
    if ( IS_TRUE( level.acc_paradise_onslaught ) ) return;

    // VERIFIED(acc): zm_powerups::specific_powerup_drop( name, drop_spot )
    // (_zm_powerups.gsc:688; stock call pattern _zm_ai_dogs.gsc:292). All four
    // names are registered powerups (the powerup modules are #using'd by our
    // entry script, matching stock maps).
    options = [];
    options[ options.size ] = "full_ammo";
    options[ options.size ] = "insta_kill";
    options[ options.size ] = "double_points";
    options[ options.size ] = "nuke";

    name = options[ acc_utility::acc_rand_int( options.size ) ];
    level thread zm_powerups::specific_powerup_drop( name, origin );
    acc_utility::log( "recursion drop at " + origin );
}
