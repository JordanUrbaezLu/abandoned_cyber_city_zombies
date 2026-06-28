// =============================================================================
// _acc_elites.gsc - elite cyber-zombie spawn logic
//
// Design reference: docs/11_enemies.md (The Cast, Elite Quota Per Round,
// Co-op Scaling), docs/06_mechanics.md (Elite Timing).
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

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;
#using scripts\zm\zm_abandoned_cyber_city\_acc_zombie_speed;   // shielded 50%-slower gait (mirror of the glitch speed think)
#using scripts\zm\zm_abandoned_cyber_city\_acc_perks;          // Savior (Mega QR) revive damage-reduction predicate

// ---------------------------------------------------------------------------
// Tuning (tuned against docs/04_progression_and_skills.md difficulty table)
// ---------------------------------------------------------------------------

#define ACC_ELITE_SHIELDED_MIN_ROUND 5
#define ACC_ELITE_TELEPORTER_MIN_ROUND 11
#define ACC_ELITE_EMP_MIN_ROUND 21

#define ACC_ELITE_SHARD_REWARD 1

// EMP elite on-hit debuff (docs/11_enemies.md "Elite: EMP (Surge)").
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
    self acc_depth_shielded_roll();
}

// self = a fully-init'd zombie (coop HP applied). On an abyss FLOOR, roll depth_shielded_pct() to spawn as a
// Shielded "Riot" elite. Skips bosses + anything already shielded/elite (the re-entrancy guard double-protects).
function acc_depth_shielded_roll()
{
    if ( !isalive( self ) ) return;
    if ( IS_TRUE( self.acc_is_elite ) || IS_TRUE( self.acc_is_shielded ) ) return;
    if ( IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) ) return;
    pct = depth_shielded_pct( acc_bus_trench::underground_layer( self.origin ) );
    if ( pct <= 0 ) return;
    if ( acc_utility::acc_rand_int( 100 ) >= pct ) return;
    self.acc_is_elite = true;
    self.acc_elite_class = "shielded";
    promote_to_shielded( self );
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
// by design (docs/06_mechanics.md Data Shard Economy) - without this reset
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
    // (r4, r8, r12, ...), and the COUNT that round = the round number / 2 (r4 -> 2, r8 -> 4, r12 -> 6, ...).
    // Every other round spawns zero elites. (round is a multiple of 4 here, so /2 is always a whole number.)
    // CAVEAT: at high rounds that's still a chunk of shields vs the ~24-AI cap - they're spread across the
    // round (spawn_elites_over_round) and the cap throttles concurrent live ones; revisit if it feels heavy.
    if ( round_number >= 4 && ( round_number % 4 ) == 0 )
        return int( round_number / 2 );
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
// docs/11_enemies.md "Co-op Scaling": elites gain +50% HP per extra player,
// flatter than regular zombies so duos don't blender them). Sampled at
// promote time so mid-game joins are reflected on the next elite.
// ---------------------------------------------------------------------------

function promote_to_shielded( z )
{
    // Re-entrancy guard (user 2026-06-25): BOTH the round-based shield spawn AND the depth-scaled abyss roll
    // can target a zombie - promote ONCE (a 2nd call would 25x HP + double the shield model + reward thread).
    if ( !isdefined( z ) || IS_TRUE( z.acc_is_shielded ) ) return;
    z.acc_is_shielded = true;

    // HP = EXACTLY 5x a NORMAL zombie's current health, at ANY player count (user 2026-06-24). By promote
    // time z.maxhealth IS the round's normal-zombie HP WITH the co-op regular +100%/player mult already baked
    // in (acc_coop_scaling at zombie_init_done), so a FLAT x5 keeps the Shielded a clean 5x a normal zombie.
    // Do NOT multiply special_hp_mult() here - that DOUBLE-counts co-op (it earlier made a 2p Shielded ~4.5x a
    // 2p zombie instead of a clean multiple); coop_scaling's own comment forbids stacking it on a maxhealth
    // that already carries regular_hp_mult.
    base_hp = z.maxhealth;
    z.maxhealth = int( base_hp * 5 );
    z.health = z.maxhealth;
    z.acc_elite_front_damage_resist = 0.25; // take 25% from front (OC tier pierces this - _acc_damage effect 4/4)

    // Visual tell (docs/52): bolt the stock Rocket Shield world model onto the elite's back so it
    // reads as the front-armoured "Shielded" class. j_spine4 is the zombie rig's upper-torso bone
    // (stock uses it for torso FX/attachments on zombies, zombie.csc:103); attachments self-align to
    // the tag. Zero new asset - wpn_t7_zmb_zod_rocket_shield_world already packs (.zone, used by the
    // Rocket Shield boss item too). z is the live, init-done AI here (spawn_elite waits the init gate).
    z Attach( "wpn_t7_zmb_zod_rocket_shield_world", "j_spine4" );

    // Heavy half-pace WALK gait (user 2026-06-22) - ~half the round's jog, natural (no slow-mo). See think.
    z thread shielded_speed_think();

    // Reward (user 2026-06-22): killing the "Riot" (Shielded) elite gives the KILLER 2 Data Shards.
    z thread shielded_death_reward();
}

// self = a Shielded ("Riot") elite. The player who lands the kill gets 2 Data Shards (user 2026-06-22).
// "riot_elite" source = a FLAT grant (not the diminishing "elite_kill" tag). #using _acc_data_shards present.
function shielded_death_reward()
{
    self waittill( "death", attacker );
    // Reactor-surge (or any future "purge") Shielded grant NO shards - a survive-the-gauntlet THREAT, not a
    // farm, same as the glitch purge (user 2026-06-24). The reactor sets this flag before promote_to_shielded.
    if ( isdefined( self.acc_no_shard_reward ) && self.acc_no_shard_reward )
        return;
    if ( isdefined( attacker ) && isplayer( attacker ) )
        acc_data_shards::grant_player( attacker, 2, "riot_elite" );
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

        self zombie_utility::set_zombie_run_cycle_override_value( "walk" );   // slow heavy gait (was run/sprint @ 0.5x = slow-mo)
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

    // Visual tell (docs/52): recoloured eyes mark this elite vs the horde, using the SAME client-side
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

    // Visual tell (docs/52): recoloured eyes mark this elite vs the horde (same accEyeTint client path
    // as the Glitch Stalker / Teleporter). NOTE: a DISTINCT electric-blue tint (different from the
    // Teleporter's intended magenta) is NOT possible through the current 1-bit field + single global
    // colour dvar - it needs accEyeTint widened to carry a per-actor colour index plus a colour map in
    // _acc_lui.csc (outside this module's edit scope; see problems[]). Tint still flags it as an elite.
    acc_lui::set_actor_eye_tint( z, true );
}

// ---------------------------------------------------------------------------
// EMP elite on-hit debuff (docs/11_enemies.md: melee hit drains 200 points
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

    // EXO SUIT - damage resistance (user 2026-06-22): each Exo Suit tier reduces ALL incoming damage by
    // acc_exo_resist_per_tier (default 5%/tier -> -25% at T5). The exo's "body" counterpart to the gun
    // Overclock - the 3rd of its 3 augments (speed-gate + this + the melee scaler in _acc_damage). Applied
    // AFTER the trench melee bump so it resists the bumped value too. Capped + floored at 1 (always killable).
    exo_tier = ( isdefined( self.acc_exo_tier ) ? self.acc_exo_tier : 0 );
    if ( exo_tier > 0 )
    {
        resist = exo_tier * getdvarfloat( "acc_exo_resist_per_tier", 0.05 );
        if ( resist > 0.80 ) resist = 0.80;
        final = int( final * ( 1.0 - resist ) );
        if ( final < 1 ) final = 1;
    }

    // SAVIOR (Mega Quick Revive) - take 50% damage while you are reviving a teammate (user 2026-06-26). Read
    // live (no poll lag) from the stock reviving state; applied AFTER exo so the two resistances stack
    // multiplicatively. Floored at 1 (always killable). See acc_perks::savior_revive_damage_mult + docs/13.
    savior_dr = acc_perks::savior_revive_damage_mult( self );
    if ( savior_dr < 1.0 )
    {
        final = int( final * savior_dr );
        if ( final < 1 ) final = 1;
    }

    // GOD MODE (user 2026-06-27): every per-hit EFFECT above has ALREADY fired (EMP debuff, trench melee scaling;
    // the Phantom chain slow runs Phantom-side) - but a godded player takes ZERO damage. Returning 0 zeros the hit
    // on the stock player-damage path (zombie melee, boss hits, and DoDamage all route through this
    // register_player_damage_callback), so there is no down/death. REPLACES the old EnableInvulnerability god mode,
    // which blocked this whole callback so no effect could land while invulnerable. "Only damage is impossible."
    // level.acc_god is the entry-script flag (default OFF in normal play, so this is a no-op there).
    if ( IS_TRUE( level.acc_god ) )
        return 0;

    // Return the modified damage (check_player_damage_callbacks uses the first != -1 return,
    // _zm.gsc:5512); -1 = leave unchanged (no exo, non-melee = identical to before).
    if ( final != iDamage )
        return final;

    return -1; // unchanged
}

// PHANTOM CHAIN-special on-hit zap (user 2026-06-24; called from _acc_boss_phantom::phantom_chain since 2026-06-25).
// self = the hit player. Plays the electric-zap SFX (the special connected) and applies a brief -25% move slow
// (acc_phantom_slowed -> read by recompute_move_speed). Driven Phantom-side (not the damage callback) so it lands
// even under GOD MODE. Mega ELECTRIC CHERRY "Power Surge" is IMMUNE to the slow.
function acc_phantom_chain_zap()
{
    self endon( "disconnect" );

    self PlaySound( "acc_phantom_zap" );

    // Immune = the LIVE Mega Electric Cherry "Power Surge" (persistent mega flag AND currently holds the perk;
    // moved off Mega Widow's, user 2026-06-25 - the electric perk shrugs off the electric zap special).
    // Mega flag read straight off the player field - no cross-module #using.
    if ( isdefined( self.acc_mega_perks ) && IS_TRUE( self.acc_mega_perks[ "specialty_combat_efficiency" ] )
         && self HasPerk( "specialty_combat_efficiency" ) )
        return;

    self.acc_phantom_slowed = true;
    acc_utility::recompute_move_speed( self );

    self notify( "acc_phantom_slow_restart" );   // a fresh chain hit refreshes the slow window
    self thread acc_phantom_slow_clear();
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

    // Active-Cyberware-ability lockout window (docs/11: "Phase Step locked
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
