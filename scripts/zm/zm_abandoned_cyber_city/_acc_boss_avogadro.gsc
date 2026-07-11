// =============================================================================
// _acc_boss_avogadro.gsc - the "Avogadro" cyberhacker boss (full implementation)
//
// Identity (user 2026-07-04): NOT lethal - super ANNOYING. A fast electric harasser whose
// job is stun-locking players and knocking their perks / PaP offline.
//   - HP = EXACTLY the Phantom's (shared scale_phantom_hp, 65k base / anchor 5 / exp 1.06 x log coop).
//   - Always spawns in the LAB (struct acc_boss_spawn @ (19,3648,0)) and roams the Lab machines.
//   - ATTACK (reworked 2026-07-06, user: "animation didn't line up with the logs and sfx / no bolt"):
//     BT-DRIVEN BOLT THROW. The pack BT plays his range-attack anim (enemy 150-2000u + LOS), whose
//     GDT notetrack self-notifies "avo_send_bolt" at the throw frame (frame 20); bolt_listener catches
//     it and launches a VISIBLE electric bolt (script_model + its own acc_avo_bolt_fx clientfield =
//     crackle cloud + tesla arc stacked, throw bark at launch / warp-out at impact, all client-side AT
//     the bolt) that flies to the target and applies the 30% slow + acc_avo_shot_damage (5) ON IMPACT
//     (dodgeable - step aside and it misses). Cadence = acc_avo_bolt_cd (0.75s) + the throw anim.
//     Anim + SFX + bolt + stun + log are ONE event. Point-blank (<220u, inside the bolt's 150u minimum)
//     aura_loop direct-zaps (same slow, acc_avo_aura_damage 5) so hugging him still means stun-lock.
//     bolt_watchdog falls back to direct zaps ONLY if the BT bolt starves on a bug (logs the reason).
//   - HACK ability: walks up to a machine and disables it for 30s; max 2 at once PER boss; PRIORITIZES
//     perks. Targets: Pack-a-Punch, Jugg, Quick Revive, Stamin-Up, Electric Cherry, Widow's Wine. FULL disable
//     (user 2026-07-06): base perk paused for ALL players, machine unbuyable (TriggerEnable false),
//     glow dark, and every MEGA effect drops too (owns_or_paused + on_perk_hacked - see
//     apply_hack_effect for the complete contract). Restores after 30s / when the owner dies.
//
// SPAWN = SpawnActor("spawner_zm_avogadro", ...) (the LED-bake-safe Rogue Protector recipe; the pack GDT
// ships the archetype->variant->spawner chain, zone-listed). Then zm_ai_avogadro::avogadro_spawn(avo,1)
// runs the pack's zombie setup on the pre-spawned actor (skip_cinematic). He is a ZOMBIE-team aitype
// (no team flip). Movement is driven by the pack BT, which we let SEEK a machine via the acc_avo_seek /
// acc_avo_goal_pos fields (a tiny early-out we added to zm_ai_avogadro::avogadrotargetservice).
//
// CADENCE: joins the shared boss roster as a 3rd type ("avogadro", widened coin flip in
// _acc_civil_protector::boss_roster) - a debt-director like the Rogue Protector. DEV mode instead runs
// a repeating test-spawn loop for easy iteration. Toggle live: acc_avo_enable 0. Trace: acc_avo_debug 1.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\codescripts\struct;

#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_perks;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_zm_ai_avogadro;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_phantom;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_nameplate;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_elites;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_lights;

#insert scripts\shared\shared.gsh;

#precache( "fx", "zombie/fxt/fx_tesla_bolt_secondary_zmb" );   // visible zap FX played at the target

// [acc] TEST MODE (user 2026-07-05: "just hardcode for now, we test as hardcoded"). 1 = force him to
// spawn EARLY (on the host player) + log every step, in ANY launcher (PLAY_NORMAL / PLAY_TEST_MAP), so a
// hardcoded test run always shows him - no acc_dev, no flags. 0 = SHIP behaviour (dev = round-1 on-player,
// normal play = round-9 shared-roster boss, dev-gated logging). *** FLIP TO 0 BEFORE SHIP. ***
#define ACC_AVO_TEST_MODE         0
#define ACC_AVO_TEST_ROUND        5     // TEST (user 2026-07-05): first spawns at round 5, ALWAYS in the Lab, respawns if killed - "test like a real game". Later he moves to the shared boss roster.

#define ACC_AVO_ENABLE_DEF        1
#define ACC_AVO_DISPLAY_NAME      "AVOGADRO"
#define ACC_AVO_MAX_HACKS         2       // machines disabled at once
#define ACC_AVO_HACK_SECS_DEF     30      // seconds a machine stays disabled
#define ACC_AVO_FIRE_INTERVAL_DEF 0.5     // seconds between point-blank AURA zaps (user 2026-07-06: "attacks so slow" - was 0.8; the BOLT cadence is acc_avo_bolt_cd, read in _zm_ai_avogadro::avoFinishBoltShoot)
#define ACC_AVO_FIRE_RANGE_DEF    1500    // units - fallback-target search radius (watchdog / bolt retarget)
#define ACC_AVO_AURA_RANGE_DEF    220     // units - point-blank aura zap reach (covers the bolt's 150u minimum range)
#define ACC_AVO_BOLT_SPEED_DEF    900     // units/sec - visible bolt projectile speed (user 2026-07-06 "hard to see": was 1100; slower = a readable, dodgeable flight)
#define ACC_AVO_BOLT_HIT_RADIUS_DEF 130   // units - impact radius that lands the slow
#define ACC_AVO_HACK_RANGE_DEF    150     // proximity to a machine to disable it
#define ACC_AVO_SLOW_SEC_DEF      3.0     // stun duration (matches Phantom/Rogue)

#namespace acc_boss_avogadro;

function dbg( msg )
{
    // HARDCODED to dev (user 2026-07-05: "we don't use flags, we test as hardcoded"): the KEY [AVO]
    // events (spawn / hack / restore / drops) fire whenever level.acc_dev is on, so the normal dev launch
    // (PLAY_TEST_MAP.bat, acc_dev 1) logs them to console_mp.log (as [SCRIPTER]) with NO extra flag. These
    // are infrequent (a few per boss), so no screen spam. The per-2.5s position HEARTBEAT stays behind
    // acc_avo_debug (opt-in via run_avo_test.bat) so it doesn't clutter normal dev play.
    if ( ACC_AVO_TEST_MODE == 0 && getdvarint( "acc_avo_debug", 0 ) != 1 )   // acc_dev DECOUPLED 2026-07-10 (clean screen; [AVO] rides acc_avo_debug now)
        return;
    acc_utility::log( "[AVO] " + msg );
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
        if ( isdefined( players[ i ] ) )
            players[ i ] IPrintLnBold( "^5[AVO]^7 " + msg );
}

// ---------------------------------------------------------------------------
// Init + cadence
// ---------------------------------------------------------------------------

function init()
{
    level endon( "end_game" );

    if ( getdvarint( "acc_avo_enable", ACC_AVO_ENABLE_DEF ) != 1 )
        return;

    level flag::wait_till( "initial_blackscreen_passed" );
    wait 3;                                  // let the perk machines / glow hosts finish their init

    level.acc_avo_hacked     = [];           // key ("specialty_*" | "pap") -> true while disabled (by ANY Avogadro)
    level.acc_avo_hacked_by  = [];           // key -> the acc_avo_id of the Avogadro that owns this hack (per-boss ownership - each boss restores ITS OWN hacks when it dies)
    level.acc_avo_gen        = [];           // key -> generation counter (invalidates a dead boss's stale expire timer)
    level.acc_avo_hack_count = 0;            // TOTAL currently disabled (info/heartbeat only - the 2-machine cap is now PER boss, so two Avogadros can disable up to 4)
    level.acc_avo_alive      = 0;            // live Avogadro count (last-death force-clears any residue)
    level.acc_avo_next_id    = 0;            // hands each spawned Avogadro a unique int id (for hack ownership)
    if ( !isdefined( level.acc_avo_debt ) )
        level.acc_avo_debt = 0;

    level._effect[ "acc_avo_zap" ] = "zombie/fxt/fx_tesla_bolt_secondary_zmb";   // visible zap-at-target FX

    cache_target_origins();

    if ( ACC_AVO_TEST_MODE == 1 )
    {
        dbg( "TEST MODE (hardcoded ACC_AVO_TEST_MODE) - unconditional early spawn loop in ANY launcher" );
        level thread dev_test_spawn();
    }
    else if ( IS_TRUE( level.acc_dev ) )
    {
        dbg( "DEV mode - running repeating test-spawn loop" );
        level thread dev_test_spawn();
    }
    else
    {
        level thread round_watch();
        level thread director();
    }
}

// How many "avogadro" slots the shared roster assigns this round (read via the published pointer,
// NOT a #using of _acc_civil_protector - that would cycle). 0 if the roster isn't up yet.
function due_count( round_number )
{
    if ( getdvarint( "acc_avo_enable", ACC_AVO_ENABLE_DEF ) != 1 )
        return 0;
    if ( !isdefined( level.acc_boss_roster_fn ) )
        return 0;
    return [[ level.acc_boss_roster_fn ]]( round_number, "avogadro" );
}

function round_watch()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
        n = due_count( round_number );
        if ( n > 0 )
        {
            level.acc_avo_debt += n;         // ADD (a stale debt carries over), same as the other bosses
            dbg( "round " + round_number + " - " + n + " Avogadro(s) owed (debt=" + level.acc_avo_debt + ")" );
        }
    }
}

function director()
{
    level endon( "end_game" );
    for ( ;; )
    {
        wait 3;
        // [acc] #6 PARADISE (2026-07-05): during the finale the paradise wave OWNS Avogadro spawns (cap 1 in
        // the arena). Pause the debt director so a carried-over debt can't drop a SECOND Avogadro into the
        // arena that the paradise cap-1 gate never authorized. Mirrors dev_test_spawn's onslaught pause. The
        // debt is preserved (we skip BEFORE spending it), so owed bosses still spawn once the onslaught ends.
        if ( IS_TRUE( level.acc_paradise_onslaught ) )
            continue;
        if ( level.acc_avo_debt <= 0 )
            continue;
        boss = spawn_boss();
        if ( isdefined( boss ) && isalive( boss ) )
            level.acc_avo_debt--;
        // else: leave the debt, retry next tick
    }
}

// TEST: from ACC_AVO_TEST_ROUND (5) on, keep exactly one Avogadro alive in the Lab - respawns ~12s
// after a kill so you can re-fight him each round. "Test like a real game" (user 2026-07-05).
function dev_test_spawn()
{
    level endon( "end_game" );
    for ( ;; )
    {
        // PARADISE (user 2026-07-05): the finale spawns Avogadro into the arena itself; pause the Lab
        // test-respawn so he doesn't also keep erupting at the (unreachable) Lab during the onslaught.
        if ( IS_TRUE( level.acc_paradise_onslaught ) ) { wait 12; continue; }
        rn = ( isdefined( level.round_number ) ? level.round_number : 1 );
        if ( rn >= ACC_AVO_TEST_ROUND && level.acc_avo_alive <= 0 )
            spawn_boss();
        wait 12;
    }
}

// ---------------------------------------------------------------------------
// Spawn
// ---------------------------------------------------------------------------

function host_player()
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
        if ( isdefined( players[ i ] ) )
            return players[ i ];
    return undefined;
}

function spawn_boss()
{
    // SPAWN ORIGIN: ALWAYS the LAB (user 2026-07-05: "always spawn in at the lab" - the acc_boss_spawn
    // struct @ (19,3648,0)). He then chases the nearest player from there. Fall back to a player only if
    // the Lab struct is somehow missing.
    org   = undefined;
    ang   = ( 0, 180, 0 );
    where = "Lab";
    // PARADISE (user 2026-07-05): the arena is a separate dimension at z=-1200 and the Lab struct (z=0) is
    // unreachable from it, so spawn him ON a living player in the arena instead. Normal rounds still use the Lab.
    if ( IS_TRUE( level.acc_paradise_onslaught ) )
    {
        pp = host_player();
        if ( isdefined( pp ) ) { org = pp.origin; ang = ( 0, pp.angles[ 1 ], 0 ); where = "Paradise arena"; }
    }
    // SEALED-LAB FALLBACK (review fix 2026-07-08): the Lab sits behind two buyable doors (enter_lab_e /
    // enter_lab_w) whose clips stay path-DISCONNECTED until bought. A roster Avogadro spawned in a
    // still-sealed Lab (possible from round 9) can't path to anyone and can't be shot - the same
    // stranded-boss failure the Rogue Protector's Plaza-anchor rework fixed. Honor the "always spawn
    // at the lab" ask whenever the Lab is OPEN; if BOTH doors are still closed, spawn ON a living
    // player instead (the navmesh-guaranteed entrance the paradise branch above already uses).
    if ( !isdefined( org )
         && !( level flag::exists( "enter_lab_e" ) && level flag::get( "enter_lab_e" ) )
         && !( level flag::exists( "enter_lab_w" ) && level flag::get( "enter_lab_w" ) ) )
    {
        pp = host_player();
        if ( isdefined( pp ) ) { org = pp.origin; ang = ( 0, pp.angles[ 1 ], 0 ); where = "player (Lab sealed)"; }
    }
    if ( !isdefined( org ) )
    {
        s = struct::get( "acc_boss_spawn", "targetname" );
        if ( isdefined( s ) )
        {
            org = s.origin;
            if ( isdefined( s.angles ) )
                ang = ( 0, s.angles[ 1 ], 0 );
        }
    }
    if ( !isdefined( org ) )
    {
        p = host_player();
        if ( !isdefined( p ) ) { dbg( "FAIL: no Lab struct AND no players - cannot spawn" ); return undefined; }
        org = p.origin; ang = ( 0, p.angles[ 1 ], 0 ); where = "player (no Lab struct)";
    }

    // HP = the Phantom's EXACT scale (base 65k, anchor 5, Phantom exponent) x the log coop mult.
    // Set level.avogadro_hp BEFORE the pack setup so avogadro_spawn() applies it as health+maxhealth.
    rn = ( isdefined( level.round_number ) ? level.round_number : 1 );
    hp = int( acc_boss_phantom::scale_phantom_hp( rn, getdvarfloat( "acc_phantom_hp_exp", 1.06 ) ) * acc_coop_scaling::boss_hp_player_mult() );
    if ( hp < 1 )
        hp = 1;
    level.avogadro_hp = hp;

    boss = SpawnActor( "spawner_zm_avogadro", org, ang, "avogadro", true );
    if ( !isdefined( boss ) )
    {
        // Retry at a player origin - navmesh-guaranteed (the spike proved SpawnActor works on a player).
        p = host_player();
        if ( isdefined( p ) && DistanceSquared( p.origin, org ) > 1 )
        {
            dbg( "SpawnActor undefined at " + org + " (" + where + ") - retrying at player origin" );
            org = p.origin; ang = ( 0, p.angles[ 1 ], 0 ); where = where + "->player-retry";
            boss = SpawnActor( "spawner_zm_avogadro", org, ang, "avogadro", true );
        }
    }
    if ( !isdefined( boss ) )
    {
        dbg( "FAIL: SpawnActor(spawner_zm_avogadro) returned undefined at " + org );
        return undefined;
    }

    // Run the pack's zombie setup on the pre-spawned actor (skip the 806u rise cinematic).
    zm_ai_avogadro::avogadro_spawn( boss, true );
    if ( !isdefined( boss ) )
    {
        dbg( "FAIL: actor died during pack setup" );
        return undefined;
    }

    // --- boss identity ---
    boss.acc_avo_id       = level.acc_avo_next_id;   // unique id for per-boss hack ownership (multi-Avogadro rounds)
    level.acc_avo_next_id++;
    boss.is_boss          = true;   // _acc_zombie_speed skips is_boss (no ASM stomp/freeze)
    boss.acc_is_boss      = true;
    boss.acc_is_mini_boss = true;   // boss headshot / corpse-skip handling
    boss.acc_boss_custom_speed = true;
    boss.ignore_enemy_count = true; // fights ALONGSIDE the wave, never gates round end
    boss.ignore_nuke        = true;
    boss.acc_avo_no_melee   = true; // kill the pack BT melee - his close threat is the aura zap (slow + chip), not a 60-dmg swing
    boss.zombie_move_speed  = getdvarstring( "acc_avo_gait", "run" );   // gait: "walk"|"run"|"sprint" (user 2026-07-05: sprint too fast -> run). Live-tunable via acc_avo_gait, respawn. (getDVARSTRING - plain `getdvar` does NOT exist in this GSC dialect; getdvarstring DOES take a default.)
    // SPEED (user 2026-07-06 tuning ladder): run gait at BOOSTED anim playback. 1.0 "too slow" -> 2.0
    // "way too fast" -> 1.5 "still out-speeds the player" -> 1.2 "a bit slower" -> 1.15 FINAL. DESIGN
    // INTENT (user): an UN-slowed player must be able to outrun him - the 30% zap slow is what closes
    // the gap, not raw pace, so his chase speed sits just under player run. ASMSetAnimationRate PERSISTS
    // (the exact _acc_zombie_speed mechanism for past-sprint rounds) and does NOT touch
    // set_zombie_run_cycle_override_value - the run-cycle override is what froze Brutus's custom ASM,
    // the bare rate call is safe on the standard blackboard move state his locomotion runs through. His
    // throw anim rides the same rate.
    boss ASMSetAnimationRate( getdvarfloat( "acc_avo_anim_rate", 1.15 ) );
    boss.maxhealth = hp;
    boss.health    = hp;

    dbg( "spawned @ " + org + " (" + where + ") - round " + rn + ", " + hp + " hp, gait=" + boss.zombie_move_speed );
    // DEV: always tell every player he's live (regardless of acc_avo_debug), so a test can never "miss"
    // a spawn that happened across the map. Normal play stays silent (the nameplate + music are the tell).
    if ( ACC_AVO_TEST_MODE == 1 )   // acc_dev DECOUPLED 2026-07-10 (clean screen): no dev "ACTIVE + hp" banner; the 3D nameplate + boss music below are the tell
        announce( "^5AVOGADRO ACTIVE^7 (" + where + ") - " + hp + " hp" );

    // --- presentation: 3D nameplate + shared boss music ---
    level notify( "acc_boss_spawned", boss, ACC_AVO_DISPLAY_NAME );
    level thread acc_boss::boss_music( boss );

    // --- behaviour + lifecycle ---
    level thread boss_life( boss );

    return boss;
}

// Owns the per-boss threads + the death handoff (drops, alive-count, last-death hack clear).
function boss_life( boss )
{
    level endon( "end_game" );
    level.acc_avo_alive++;
    my_id = boss.acc_avo_id;    // capture now - `boss` goes undefined once the pack death() Delete()s it

    boss thread bolt_listener();
    boss thread aura_loop();
    boss thread bolt_watchdog();
    boss thread hack_director();
    dbg( "boss_life ACTIVE - bolt_listener + aura_loop + bolt_watchdog + hack_director threaded @ " + boss.origin );   // co-op inert-boss diag (user 2026-07-05): if this DOESN'T log, spawn_boss aborted before here (pack setup threw); if it DOES, the threads ran (issue is downstream - unreachable machines / no target). Launch the co-op test with +set acc_avo_debug 1.

    // Wait for death. Poll isalive and keep the PER-BOSS last origin (M3, review 2026-07-04: do NOT read
    // level.avogadro_death_origin - it's a single global the pack overwrites, so with 2 Avogadros alive
    // one boss_life could drop at the other's death spot). This captures his position ~0.25s before death.
    org = boss.origin;
    // Freeze org at the GROUND kill spot, NOT the airborne exit-anim rise (user 2026-07-10 "killed Avogadro,
    // no item"). The pack's death() (_zm_ai_avogadro.gsc:853) sets boss.is_alive=0 AT GROUND, THEN
    // AnimScripted("exit_anim") LIFTS him ~800u while allowdeath stays false (line 929) so .health is held ->
    // engine isalive() stays TRUE through the whole departure rise. A bare isalive() poll therefore kept
    // re-sampling boss.origin high in the air, and grant_drops' floor-snap (2500u down-trace) then MISSED /
    // snapped onto the roof -> the item spawned unreachable. Breaking on the pack's own is_alive==0 flag (set
    // at ground, before the rise) keeps the last pre-rise ground origin. wait 0.1 keeps that origin fresh.
    while ( isdefined( boss ) && isalive( boss ) && !( isdefined( boss.is_alive ) && boss.is_alive == 0 ) )
    {
        org = boss.origin;
        wait 0.1;
    }

    level.acc_avo_alive--;
    if ( level.acc_avo_alive < 0 )
        level.acc_avo_alive = 0;

    restore_boss_hacks( my_id );         // THIS boss dying restores ONLY the machines IT disabled - a still-alive sibling keeps its own

    grant_drops( org );

    if ( level.acc_avo_alive <= 0 )
        clear_all_hacks();               // last Avogadro down -> belt-and-suspenders: force-restore any residue
}

// ---------------------------------------------------------------------------
// Attack (reworked 2026-07-06): BT-driven bolt throw + point-blank aura zap.
//
// The OLD fire_loop stunned players from a bare 0.6s GSC timer - no animation, no projectile, just the
// zap SFX + slow, while the pack BT independently tried (and failed - unregistered ShouldDopunchAttack
// node, see _zm_ai_avogadro::InitavogadroBehaviorsAndASM) to play his range-attack anim on a 20s
// cooldown. That's exactly the "his animation didn't line up with the logs and sfx / I never saw his
// lightning bolt" bug. NOW the BT owns the attack: it plays the throw anim, the anim's notetrack fires
// "avo_send_bolt" at the release frame, and bolt_listener launches the visible projectile whose IMPACT
// applies the slow. One event = anim + SFX + bolt + stun + log, all in sync.
// ---------------------------------------------------------------------------

// Every zap now CHIPS real damage (user 2026-07-06 ladder: pure-stun 0 -> 1 -> "make it 5" for BOTH the
// bolt and the aura). `dmg` optional - defaults to the BOLT/shot damage (acc_avo_shot_damage); the aura
// passes its own acc_avo_aura_damage (both default 5).
// Attacker = the boss actor: proper damage direction indicator + kill attribution, and it trips the pack's
// perk-damage override (electric shellshock + overlay tell, fixed stock-safe in _zm_ai_avogadro). NOT the
// victim as attacker - stock DROPS self-attacker damage on un-whitelisted MODs (memory
// stock-self-damage-mod-whitelist). Falls back to the attribution-less 2-arg form if the boss is gone
// (e.g. a bolt landing after his death).
function zap_damage( t, boss, dmg )
{
    if ( !isdefined( dmg ) )
        dmg = getdvarint( "acc_avo_shot_damage", 5 );
    if ( dmg <= 0 || !isdefined( t ) )
        return;
    if ( isdefined( boss ) )
        t DoDamage( dmg, t.origin, boss, boss );
    else
        t DoDamage( dmg, t.origin );
}

// Waits for the throw-frame notetrack of the BT range attack ("avo_send_bolt", GDT Self Notify @ frame
// 20 of ai_zombie_avogadro_range_attack_start) and launches the visible bolt at his current enemy.
function bolt_listener()
{
    self endon( "death" );
    self endon( "avogadro_death" );   // the pack's death() notify (it doesn't fire the standard "death") - end BEFORE it Delete()s self, or we touch a removed entity
    level endon( "end_game" );
    self.acc_avo_last_bolt_ms = GetTime();
    for ( ;; )
    {
        self waittill( "avo_send_bolt" );
        self.acc_avo_last_bolt_ms = GetTime();

        t = undefined;
        if ( isdefined( self.enemy ) && isplayer( self.enemy ) && zm_utility::is_player_valid( self.enemy ) )
            t = self.enemy;
        else
            t = pick_fire_target();       // enemy died/downed mid-anim - retarget so the throw isn't wasted
        if ( !isdefined( t ) )
        {
            dbg( "BOLT anim fired but no valid target - throw wasted" );
            continue;
        }

        // (No server PlaySound here - PlaySound on an AI ACTOR is dead in this build, nameplate-module
        // precedent. The throw bark plays CLIENT-side in the acc_avo_bolt_fx callback, at the bolt, the
        // frame it spawns - so the sound is locked to the visual.)
        acc_boss_nameplate::zap_pulse( self );          // client electric burst on him = muzzle flash tell
        level thread bolt_travel( self, t );
        dbg( "BOLT thrown (dist=" + int( Distance( self.origin, t.origin ) ) + ")" );
    }
}

// The visible projectile: script_model + its OWN "acc_avo_bolt_fx" scriptmover clientfield (2026-07-06,
// user: "make sure his shots are visible" - the single linger FX was too faint). The .csc callback
// stacks TWO fx on the mover - his crackle cloud + the bright tesla arc - and plays the throw bark at
// launch / warp-out fizzle at impact, positionally AT the bolt, so audio and visual are one event.
// Flies to a slightly-led impact point; every valid player inside the hit radius eats the 30% slow +
// chip damage. Threaded on LEVEL so an in-flight bolt still lands (and cleans up) if the boss dies
// mid-flight.
// *** DO NOT swap this for a world-position PlayFX bolt (user 2026-07-05): fx_tesla_bolt_secondary_zmb
// is a LOOPING fx with no handle to kill it - PlayFX instances piled into a permanent blinding wall.
// The clientfield-on-entity pattern below is self-cleaning (field 0 = StopFX, Delete kills the ent). ***
function bolt_travel( boss, t )
{
    level endon( "end_game" );
    if ( !isdefined( boss ) || !isdefined( t ) )
        return;

    src = boss GetTagOrigin( "tag_weapon_right" );
    if ( !isdefined( src ) )
        src = boss.origin + ( 0, 0, 48 );

    // Lead a moving target a touch (the pack's original bolt led by 1.5s - far too much; 0.25s is
    // dodgeable-but-honest). Z lead dropped so jumping doesn't aim the bolt into the sky.
    v_vel  = t GetVelocity();
    lead_f = getdvarfloat( "acc_avo_bolt_lead", 0.25 );
    lead   = v_vel * lead_f;
    dst    = t.origin + ( 0, 0, 40 ) + ( lead[ 0 ], lead[ 1 ], 0 );

    bolt = Spawn( "script_model", src );
    if ( !isdefined( bolt ) )
        return;
    bolt SetModel( "tag_origin" );
    bolt clientfield::set( "acc_avo_bolt_fx", 1 );      // crackle + tesla arc + throw bark, client-side at the bolt

    speed = getdvarfloat( "acc_avo_bolt_speed", ACC_AVO_BOLT_SPEED_DEF );
    if ( speed < 100 )
        speed = 100;
    t_fly = Distance( src, dst ) / speed;
    // Min flight 0.25s (was 0.15): below that the clientfield snapshot (~1-2 server frames) eats most of
    // the flight and the bolt reads as an invisible hit - the other half of "I can't see his projectile".
    if ( t_fly < 0.25 ) t_fly = 0.25;
    if ( t_fly > 2.0 )  t_fly = 2.0;
    bolt MoveTo( dst, t_fly );
    wait t_fly;

    if ( !isdefined( bolt ) )
        return;

    // Impact: slow every valid player in the blast radius (usually just the target; a huddled co-op
    // pair both get clipped - fits the "spread the slow" identity).
    r_sq = getdvarfloat( "acc_avo_bolt_hit_radius", ACC_AVO_BOLT_HIT_RADIUS_DEF );
    r_sq = r_sq * r_sq;
    hit = 0;
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !zm_utility::is_player_valid( p ) )
            continue;
        if ( DistanceSquared( bolt.origin, p.origin + ( 0, 0, 40 ) ) <= r_sq )
        {
            p acc_elites::acc_avogadro_zap();           // 30% slow (3s, refreshes), god-safe
            zap_damage( p, boss );                      // + 1 chip damage (acc_avo_shot_damage)
            hit++;
        }
    }
    bolt clientfield::set( "acc_avo_bolt_fx", 0 );      // StopFX both + warp-out fizzle SFX at the impact point
    if ( hit > 0 )
        dbg( "BOLT impact HIT " + hit + " player(s)" );
    else
        dbg( "BOLT impact MISSED (dodged)" );
    wait 0.15;                                          // let the field-0 snapshot reach clients before Delete
    if ( isdefined( bolt ) )
        bolt Delete();
}

// Point-blank stun-lock: the BT bolt has a 150u MINIMUM range, so a player hugging him would never be
// zapped. Inside ACC_AVO_AURA_RANGE the aura direct-zaps on a short timer (with the zap_pulse arc on his
// body right next to you, this reads as his electric field biting).
function aura_loop()
{
    self endon( "death" );
    self endon( "avogadro_death" );
    level endon( "end_game" );
    hb = 0;
    for ( ;; )
    {
        wait getdvarfloat( "acc_avo_fire_interval", ACC_AVO_FIRE_INTERVAL_DEF );
        t = pick_fire_target( getdvarfloat( "acc_avo_aura_range", ACC_AVO_AURA_RANGE_DEF ) );
        if ( !isdefined( t ) )
            continue;
        t acc_elites::acc_avogadro_zap();
        zap_damage( t, self, getdvarint( "acc_avo_aura_damage", 5 ) );   // aura damage, own dvar (user 2026-07-06: 5)
        acc_boss_nameplate::zap_pulse( self );
        if ( GetTime() >= hb )                           // throttled log
        {
            hb = GetTime() + 2000;
            dbg( "AURA zap (dist=" + int( Distance( self.origin, t.origin ) ) + ")" );
        }
    }
}

// Safety net: if the BT bolt hasn't fired for ~3 cooldowns + 8s while the boss is READY ("none") or has
// lost its enemy field (a BUG - the target service should always maintain it), fall back to old-style
// direct zaps every tick so he is never toothless, and log the block reason so the playtest log says
// exactly what starved him. Legit gates (player out of range / hiding without LOS / cooldown running)
// do NOT trigger the fallback - hiding from the bolt is intended counterplay.
function bolt_watchdog()
{
    self endon( "death" );
    self endon( "avogadro_death" );
    level endon( "end_game" );
    warned = false;
    none_streak = 0;                                     // consecutive ticks stuck on block="none" (ready but never throwing)
    for ( ;; )
    {
        wait 2;
        starve_ms = int( ( getdvarfloat( "acc_avo_bolt_cd", 0.75 ) * 3 + 8 ) * 1000 );
        last = ( isdefined( self.acc_avo_last_bolt_ms ) ? self.acc_avo_last_bolt_ms : 0 );
        if ( GetTime() - last <= starve_ms )
        {
            warned = false;
            none_streak = 0;
            continue;
        }
        t = pick_fire_target();
        if ( !isdefined( t ) )
            continue;                                    // nobody in reach - nothing is being starved
        blk = ( isdefined( self.acc_avo_bolt_block ) ? self.acc_avo_bolt_block : "never_evaluated" );
        if ( blk == "los" || blk == "range" || blk == "cooldown" )
        {
            none_streak = 0;
            if ( !warned ) { warned = true; dbg( "bolt quiet " + int( ( GetTime() - last ) / 1000 ) + "s (block=" + blk + ") - legit gate, no fallback" ); }
            continue;
        }
        // block="none" means the CONDITION passes - the BT may be about to throw this very frame (the
        // 2026-07-06 playtest logged a false STARVED 48ms before a real throw). Only call it broken after
        // 2 consecutive ticks (4s) stuck there; no_enemy/never_evaluated/disabled fall through immediately.
        if ( blk == "none" )
        {
            none_streak++;
            if ( none_streak < 2 )
                continue;
        }
        if ( !warned )
        {
            warned = true;
            dbg( "^1BOLT STARVED " + int( ( GetTime() - last ) / 1000 ) + "s (block=" + blk + ") - BT attack is broken, falling back to direct zaps" );
        }
        t acc_elites::acc_avogadro_zap();
        zap_damage( t, self );
        acc_boss_nameplate::zap_pulse( self );
    }
}

// Nearest UN-stunned valid player in range; falls back to nearest-any so he still fires when everyone
// near him is already slowed (keeps refreshing the lock). NO line-of-sight gate (user 2026-07-05: "he
// doesn't attack" - a strict LOS trace was suppressing fire; a stun boss zapping the nearest player in
// range is fine, and he's usually right on you anyway). `range_override` (optional) narrows the search
// (aura uses it); default = acc_avo_fire_range.
function pick_fire_target( range_override )
{
    range = ( isdefined( range_override ) ? range_override : getdvarfloat( "acc_avo_fire_range", ACC_AVO_FIRE_RANGE_DEF ) );
    range_sq = range * range;

    best_un = undefined;  best_un_d = 999999999;
    best_any = undefined; best_any_d = 999999999;

    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !zm_utility::is_player_valid( p ) )
            continue;
        d = DistanceSquared( self.origin, p.origin );
        if ( d > range_sq )
            continue;
        if ( d < best_any_d ) { best_any_d = d; best_any = p; }
        if ( !IS_TRUE( p.acc_avogadro_slowed ) && d < best_un_d ) { best_un_d = d; best_un = p; }
    }
    return ( isdefined( best_un ) ? best_un : best_any );
}

// ---------------------------------------------------------------------------
// Signature ability: hack machines (disable perk / PaP + kill its glow for 30s)
// ---------------------------------------------------------------------------

// The 5 targets and their SEEK origins (machines are static). Machine ENTs (for glow) are resolved
// lazily at hack time so timing can't miss a not-yet-initialised machine.
// TRAP: the map has a PARADISE DUPLICATE perk row + PaP at z=-1200 (a separate underground dimension)
// with the SAME script_noteworthy. Keep the LAB machine (nearest to the boss's Lab spawn), NOT the
// Paradise twin - else he'd try to path to z=-1200 (unreachable from the Lab) and never hack it.
// NAVMESH TRAP (2026-07-06 playtest log: moved=0 forever, every seek timed out at full distance): the
// vending-machine ENTITY origin sits INSIDE the machine geometry at z=60 - never on the navmesh - so
// SetGoal(raw origin) silently fails and he can't path AT ALL. Every cached origin is projected onto
// the navmesh via GetClosestPointOnNavMesh (the exact fix nsz_brutus.gsc:246 uses for the same bug);
// goal, arrival check and nearest-sort all use the projected point consistently.
function nav_project( org, label )
{
    nav = GetClosestPointOnNavMesh( org, 256, 34 );
    if ( isdefined( nav ) )
        return nav;
    dbg( "^1machine cache: " + label + " @ " + org + " has NO navmesh within 256u - he can never path to it" );
    return org;
}

function cache_target_origins()
{
    level.acc_avo_origin = [];
    s = struct::get( "acc_boss_spawn", "targetname" );
    lab_ref = ( isdefined( s ) ? s.origin : ( 19, 3648, 0 ) );
    best_d = [];
    vendors = GetEntArray( "zombie_vending", "targetname" );
    for ( i = 0; i < vendors.size; i++ )
    {
        t = vendors[ i ];
        if ( !isdefined( t.script_noteworthy ) )
            continue;
        key = t.script_noteworthy;
        if ( is_hackable_perk_key( key ) )   // Stamin-Up hackable too (user 2026-07-06; machine = the stock marathon prefab @ (-75,4195) in the Lab row)
        {
            d = DistanceSquared( lab_ref, t.origin );
            if ( !isdefined( level.acc_avo_origin[ key ] ) || d < best_d[ key ] )
            {
                level.acc_avo_origin[ key ] = nav_project( t.origin, key );   // the Lab copy, snapped onto the navmesh
                best_d[ key ] = d;
            }
        }
    }

    // PARADISE TWIN CACHE (user 2026-07-09 parity pass: "bosses must act the same in Paradise"). The arena
    // has its own DUPLICATE perk row at z=-1200 (gen_paradise_props.js .map entities - same zombie_vending
    // targetname + script_noteworthy as the surface machines), so the onslaught Avogadro can keep hacking
    // instead of pausing (the old pause's reason was "no reachable machines", true only of the LAB copies).
    // Twin = the same noteworthy, nearest the plaza centre, ACCEPTED only below the arena z-band (z < -600)
    // so a perk with no arena twin stays un-cached and is never sought down there. do_hack/perk_pause are
    // per-SPECIALTY (both dimensions at once), and the hack glow already handles the twin (see hack glow
    // notes below) - only the SEEK ORIGIN differs. target_origin() picks the cache by dimension.
    level.acc_avo_origin_paradise = [];
    par_ref = ( 0, -1300, -1200 );   // plaza centre (matches _acc_paradise::paradise_gather_point)
    pbest_d = [];
    for ( i = 0; i < vendors.size; i++ )
    {
        t = vendors[ i ];
        if ( !isdefined( t.script_noteworthy ) )
            continue;
        key = t.script_noteworthy;
        if ( !is_hackable_perk_key( key ) )
            continue;
        if ( t.origin[ 2 ] > -600 )
            continue;                 // surface/Lab copy - not an arena twin
        d = DistanceSquared( par_ref, t.origin );
        if ( !isdefined( level.acc_avo_origin_paradise[ key ] ) || d < pbest_d[ key ] )
        {
            level.acc_avo_origin_paradise[ key ] = nav_project( t.origin, key );
            pbest_d[ key ] = d;
        }
    }
    // Paradise PaP seek origin: the arena PaP is our CUSTOM standalone vendor (acc_pap_levels::
    // spawn_paradise_pap_at, NOT a vending_packapunch ent), so its spot is pinned to the spawn call in
    // _acc_glitch_altar::spawn_paradise - (0,-1700,-1200). *** COORD PINNED THERE - move both together. ***
    level.acc_avo_origin_paradise[ "pap" ] = nav_project( ( 0, -1700, -1200 ), "pap" );
    // PaP seek origin. Use GetEntArray, NOT GetEnt - a singular GetEnt("vending_packapunch") FATALS with
    // two of them (documented in _acc_pap_levels.gsc:711), and a throw here would abort init() before the
    // spawn thread starts. Pick the Lab PaP (nearest the boss spawn). Hardcoded fallback if none found.
    pap_org = ( -700, 3700, 7.5 );
    paps = GetEntArray( "vending_packapunch", "targetname" );
    pbest = -1;
    for ( i = 0; i < paps.size; i++ )
    {
        if ( !isdefined( paps[ i ] ) )
            continue;
        d = DistanceSquared( lab_ref, paps[ i ].origin );
        if ( pbest < 0 || d < pbest )
        {
            pbest = d;
            pap_org = paps[ i ].origin;
        }
    }
    level.acc_avo_origin[ "pap" ] = nav_project( pap_org, "pap" );

    // DEV: dump the resolved hack-target cache once - a playtest log then PROVES which machines he can
    // seek (a missing key here = that perk is silently never hackable, e.g. a renamed script_noteworthy).
    keys = target_keys();
    for ( i = 0; i < keys.size; i++ )
    {
        k = keys[ i ];
        if ( isdefined( level.acc_avo_origin[ k ] ) )
            dbg( "machine cache: " + k + " @ " + level.acc_avo_origin[ k ] );
        else
            dbg( "^1machine cache: " + k + " NOT FOUND - never hackable" );
    }
}

// Priority-ordered target list (perks FIRST, PaP last).
function target_keys()
{
    return array( "specialty_armorvest", "specialty_quickrevive", "specialty_staminup", "specialty_widowswine", "specialty_combat_efficiency", "pap" );
}

// The hackable PERK noteworthies (single source for both dimension caches; PaP is handled separately).
function is_hackable_perk_key( key )
{
    return ( key == "specialty_armorvest" || key == "specialty_quickrevive"
          || key == "specialty_widowswine" || key == "specialty_combat_efficiency"
          || key == "specialty_staminup" );
}

// Dimension-aware seek origin (user 2026-07-09 parity pass): the LAB cache normally; the PARADISE twin
// cache during the onslaught (the paradise wave is the sole Avogadro source then, so an onslaught boss is
// always IN the arena). Returns undefined for a key with no machine in the active dimension - the seek
// logic already treats that as not-seekable.
function target_origin( key )
{
    if ( IS_TRUE( level.acc_paradise_onslaught ) )
        return level.acc_avo_origin_paradise[ key ];
    return level.acc_avo_origin[ key ];
}

function is_key_enabled( key )
{
    return ( isdefined( target_origin( key ) ) && !IS_TRUE( level.acc_avo_hacked[ key ] ) );
}

// Nearest ENABLED target to `org`, perks preferred over PaP even if PaP is closer. `blacklist` (per-boss
// key->expiry-time map, optional) skips machines this boss recently couldn't reach.
function nearest_enabled_target( org, blacklist )
{
    keys = target_keys();
    best_perk = undefined; best_perk_d = 999999999;
    pap_ok = false;
    for ( i = 0; i < keys.size; i++ )
    {
        key = keys[ i ];
        if ( !is_key_enabled( key ) )
            continue;
        if ( isdefined( blacklist ) && isdefined( blacklist[ key ] ) && GetTime() < blacklist[ key ] )
            continue;                        // temporarily skipped (couldn't path within range)
        if ( key == "pap" ) { pap_ok = true; continue; }
        d = DistanceSquared( org, target_origin( key ) );   // dimension-aware (paradise twins during the onslaught)
        if ( d < best_perk_d ) { best_perk_d = d; best_perk = key; }
    }
    if ( isdefined( best_perk ) )
        return best_perk;
    if ( pap_ok )
        return "pap";
    return undefined;
}

function hack_director()
{
    self endon( "death" );
    self endon( "avogadro_death" );   // pack death notify (see fire_loop)
    level endon( "end_game" );
    self.acc_avo_blacklist = [];
    seek_key = undefined;
    seek_start = 0;
    no_seek_until = 0;
    hb_next = 0;
    hb_last_pos = self.origin;
    for ( ;; )
    {
        wait getdvarfloat( "acc_avo_hack_think", 0.4 );

        // PARADISE (user 2026-07-09 parity pass): hacking now WORKS during the onslaught - target_origin()
        // serves the arena's own duplicate perk row / PaP (the paradise twin cache) instead of the
        // unreachable Lab machines, so he behaves exactly like a normal-round Avogadro down there.
        // (The old 2026-07-05 skip-hacking-in-paradise pause is gone.)

        goal = undefined;
        desc = "player(service)";

        // PRIORITY (user 2026-07-05: "walk up to perk machines to disable"): seek the nearest enabled
        // machine (perks before PaP) and hack it in range. If he can't get within range in
        // acc_avo_seek_timeout (e.g. behind a locked door), blacklist it and chase players instead.
        // STICKY SEEK (2026-07-06 playtest fix): commit to the chosen machine until ARRIVAL, TIMEOUT or it
        // becomes invalid. The old "re-pick nearest every tick" ping-ponged between two far machines (the
        // nearest flipped as he nudged around + an 8s blacklist expired before the other's 9s timeout), so
        // the timeout timer RESET forever, the chase fallback lasted one 0.4s tick, and he stood still all
        // game. Timeouts now also blacklist for 30s (was 8) and open a 12s pure-chase window.
        if ( boss_hack_count( self ) < ACC_AVO_MAX_HACKS && GetTime() >= no_seek_until )   // PER-BOSS cap (user 2026-07-05)
        {
            key = undefined;
            if ( isdefined( seek_key ) && is_key_enabled( seek_key )
                 && !( isdefined( self.acc_avo_blacklist[ seek_key ] ) && GetTime() < self.acc_avo_blacklist[ seek_key ] ) )
                key = seek_key;                          // stick with the committed target
            if ( !isdefined( key ) )
                key = nearest_enabled_target( self.origin, self.acc_avo_blacklist );
            if ( isdefined( key ) )
            {
                mo = target_origin( key );   // dimension-aware (paradise twins during the onslaught)
                if ( !isdefined( mo ) )      // dimension flipped mid-seek (battle started/ended) - re-pick next tick
                {
                    seek_key = undefined;
                    continue;
                }
                range = getdvarfloat( "acc_avo_hack_range", ACC_AVO_HACK_RANGE_DEF );
                if ( DistanceSquared( self.origin, mo ) <= range * range )
                {
                    do_hack( self, key );               // arrived -> disable it (self = the owning boss)
                    seek_key = undefined;
                }
                else
                {
                    if ( !isdefined( seek_key ) || key != seek_key )   // guard: `string != undefined` THROWS in T7 GSC
                    {
                        seek_key = key;
                        seek_start = GetTime();
                        dbg( "SEEK " + key + " (dist=" + int( Distance( self.origin, mo ) ) + ")" );
                    }
                    else if ( GetTime() - seek_start > getdvarint( "acc_avo_seek_timeout_ms", 9000 ) )
                    {
                        self.acc_avo_blacklist[ key ] = GetTime() + getdvarint( "acc_avo_seek_blacklist_ms", 30000 );
                        seek_key = undefined;           // can't reach it -> long blacklist + a chase window
                        no_seek_until = GetTime() + getdvarint( "acc_avo_chase_after_timeout_ms", 12000 );
                        dbg( "^1SEEK TIMEOUT " + key + " (still " + int( Distance( self.origin, mo ) ) + "u away after 9s) - blacklisted 30s, chasing players 12s" );
                    }
                    if ( isdefined( seek_key ) )
                    {
                        goal = mo;
                        desc = "machine:" + key;
                    }
                }
            }
        }
        else
        {
            seek_key = undefined;                        // at cap / in a chase window - drop any commitment
        }

        if ( isdefined( goal ) )
        {
            self.acc_avo_seek = true;                   // machine goal: the BT target service honours acc_avo_goal_pos
            self.acc_avo_goal_pos = goal;
            self SetGoal( goal );                       // drive movement directly too
        }
        else
        {
            // PLAYER CHASE (2026-07-06): hand movement back to the BT target service, which SetGoals the
            // closest player ENTITY (auto-tracking, the pack's stock recipe). The old fallback fed a 0.4s-
            // stale position goal from here, resetting his path every tick.
            self.acc_avo_seek = false;
        }

        // DEV HEARTBEAT (enriched 2026-07-06 so a playtest log fully describes his state): moved = units
        // covered since the last HB (0 while a far goal exists = pathing/BT is broken -> STUCK? flag);
        // path = engine PathMode; gait = zombie_move_speed (drives the locomotion blackboard); enemy =
        // distance to .enemy (must ~always be set - "none" = target-service bug); bolt = the BT attack
        // gate reason from avoShouldShootBolt ("none"=ready/firing, cooldown/range/los legit) + cooldown.
        if ( ( ACC_AVO_TEST_MODE == 1 || getdvarint( "acc_avo_debug", 0 ) == 1 ) && GetTime() >= hb_next )   // acc_dev DECOUPLED 2026-07-10 (clean screen; heartbeat rides acc_avo_debug now)
        {
            hb_next = GetTime() + 2500;
            gd = ( isdefined( goal ) ? int( Distance( self.origin, goal ) ) : -1 );
            moved = int( Distance( self.origin, hb_last_pos ) );
            hb_last_pos = self.origin;
            pm = self GetPathMode();
            gait = ( isdefined( self.zombie_move_speed ) ? self.zombie_move_speed : "?" );
            en = "none";
            if ( isdefined( self.enemy ) )
                en = "" + int( Distance( self.origin, self.enemy.origin ) ) + "u";
            blk = ( isdefined( self.acc_avo_bolt_block ) ? self.acc_avo_bolt_block : "never_evaluated" );
            cd_s = 0;
            if ( isdefined( self.next_bolt_time ) && self.next_bolt_time > GetTime() )
                cd_s = int( ( self.next_bolt_time - GetTime() ) / 1000 );
            stuck = ( ( isdefined( goal ) && gd > 100 && moved < 10 ) ? " ^1STUCK?^7" : "" );
            dbg( "HB pos=" + self.origin + " moved=" + moved + " goal=" + desc + " dist=" + gd
                 + " path=" + pm + " gait=" + gait + " enemy=" + en + " bolt=" + blk + "/cd" + cd_s + "s"
                 + " mine=" + boss_hack_count( self ) + " tot=" + level.acc_avo_hack_count + stuck );
        }
    }
}

// (nearest_valid_player removed 2026-07-08 review cleanup: never called - pick_fire_target() is the
// live targeting path, and stock zm_utility::get_closest_valid_player covers the generic case.)

// How many machines THIS Avogadro currently owns. The 2-machine cap is per-boss (user 2026-07-05), so two
// Avogadros can disable up to 4 - all 4 perks. Compares the stored owner id (an INT), never an entity, which
// sidesteps the "entity == undefined throws" trap once an owner boss has been Delete()d.
function boss_hack_count( boss )
{
    if ( !isdefined( boss ) || !isdefined( boss.acc_avo_id ) )
        return 0;
    n = 0;
    keys = target_keys();
    for ( i = 0; i < keys.size; i++ )
    {
        k = keys[ i ];
        if ( IS_TRUE( level.acc_avo_hacked[ k ] ) && isdefined( level.acc_avo_hacked_by[ k ] ) && level.acc_avo_hacked_by[ k ] == boss.acc_avo_id )
            n++;
    }
    return n;
}

function do_hack( boss, key )
{
    // PER-BOSS cap: each Avogadro may hold up to ACC_AVO_MAX_HACKS of ITS OWN. A machine already disabled by
    // ANOTHER Avogadro is skipped (one hack per machine) - that sibling seeks a different one, so two together
    // knock out up to 4 machines (all 4 perks). "Doubly lethal" (user 2026-07-05).
    if ( boss_hack_count( boss ) >= ACC_AVO_MAX_HACKS )
        return;
    if ( IS_TRUE( level.acc_avo_hacked[ key ] ) )
        return;

    level.acc_avo_hacked[ key ]    = true;
    level.acc_avo_hacked_by[ key ] = boss.acc_avo_id;   // this boss owns it -> restored when IT dies
    level.acc_avo_hack_count++;
    if ( !isdefined( level.acc_avo_gen[ key ] ) )
        level.acc_avo_gen[ key ] = 0;
    level.acc_avo_gen[ key ]++;              // new generation -> any older expire timer for this key becomes a no-op

    // ISOLATE the effect on its own thread: if a stock call (perk_pause / glow) ever throws, it must NOT
    // kill hack_director (that's what froze him before). The hack STATE above is already committed.
    level thread apply_hack_effect( key );

    hack_alert( key, true );   // UI alert (user 2026-07-05): prominent all-player toast so everyone knows a perk/PaP just went down
    dbg( "hacked " + key + " (count=" + level.acc_avo_hack_count + ")" );

    level thread hack_expire( key, level.acc_avo_gen[ key ] );
}

// Restore after 30s - but ONLY if this is still the CURRENT hack of the key (M1, review 2026-07-04). A
// dead boss's leftover timer would otherwise cancel a NEW boss's fresh hack of the same machine early.
function hack_expire( key, gen )
{
    level endon( "end_game" );
    wait getdvarint( "acc_avo_hack_secs", ACC_AVO_HACK_SECS_DEF );
    if ( isdefined( level.acc_avo_gen[ key ] ) && level.acc_avo_gen[ key ] == gen )
        undo_hack( key );
}

// Idempotent: safe to call from the timer AND from clear_all_hacks() without double-restoring.
function undo_hack( key )
{
    if ( !IS_TRUE( level.acc_avo_hacked[ key ] ) )
        return;

    level.acc_avo_hacked[ key ]    = false;
    level.acc_avo_hacked_by[ key ] = undefined;
    level.acc_avo_hack_count--;
    if ( level.acc_avo_hack_count < 0 )
        level.acc_avo_hack_count = 0;

    level thread apply_unhack_effect( key );

    hack_alert( key, false );   // UI alert: it's back
    dbg( "restored " + key + " (count=" + level.acc_avo_hack_count + ")" );
}

// Restore ONLY the machines owned by the given Avogadro id - called when THAT boss dies, so a still-alive
// sibling keeps its own hacks (multi-Avogadro rounds, user 2026-07-05). undo_hack is idempotent and only
// fires for a key still hacked by this id (int compare, so a Delete()d owner never mismatches via a throw).
function restore_boss_hacks( id )
{
    if ( !isdefined( id ) )
        return;
    keys = target_keys();
    for ( i = 0; i < keys.size; i++ )
    {
        k = keys[ i ];
        if ( IS_TRUE( level.acc_avo_hacked[ k ] ) && isdefined( level.acc_avo_hacked_by[ k ] ) && level.acc_avo_hacked_by[ k ] == id )
            undo_hack( k );
    }
}

// Force-restore EVERYTHING when the LAST Avogadro dies (user 2026-07-05: a perk/PaP must NEVER stay stuck
// OFF as a bug). Each boss already restores its own hacks on its death (restore_boss_hacks), so this is the
// belt-and-suspenders: it restores ALL 5 targets unconditionally, clearing even a desynced/untracked pause.
// Safe: zm_perks::perk_unpause is a no-op if the perk wasn't paused, and the glow just re-lights. Each
// restore is threaded so one stock throw can't leave the rest stuck.
function clear_all_hacks()
{
    level.acc_avo_hack_count = 0;
    keys = target_keys();
    for ( i = 0; i < keys.size; i++ )
    {
        level.acc_avo_hacked[ keys[ i ] ]    = false;
        level.acc_avo_hacked_by[ keys[ i ] ] = undefined;
        level thread apply_unhack_effect( keys[ i ] );
    }
}

// The actual disable, threaded from do_hack so a throw in a stock call can never kill hack_director.
// FULL DISABLE CONTRACT (user 2026-07-06: "make sure when he disables a perk you cannot buy it, fx is
// off, and the actual ability for both base and mega are removed - check all cases"):
//   1. BASE ability off      = zm_perks::perk_pause (UnsetPerk for owners; stock).
//   2. MEGA abilities off    = owns_or_paused() in _acc_mega_bottles treats an avo-hacked perk as NOT
//                              owned (kills every has_active_mega_perk gate: spider drops, Power Surge,
//                              boss-special immunity, EMP immunity), the Widow's stance watcher pauses
//                              itself off level.acc_avo_hacked, and on_perk_hacked() drops the stateful
//                              Ultimate Tank +50 (and jugg's own +150) via a health_reboot recompute.
//   3. CANNOT BUY            = TriggerEnable(false) on every zombie_vending trigger of the specialty
//                              (both the Lab machine and the Paradise twin - matches perk_pause's
//                              global scope). Stock perk_pause alone leaves the machine buyable.
//   4. FX off                = set_machine_glow 0 (the machine's light rig goes dark).
function apply_hack_effect( key )
{
    level endon( "end_game" );
    if ( key == "pap" )
        level.acc_pap_hacked = true;        // _acc_pap_levels refuses to pack while set
    else
    {
        zm_perks::perk_pause( key );        // stops the BASE perk for owners
        set_vending_triggers( key, false ); // and nobody can buy it while hacked
        acc_mega_bottles::on_perk_hacked( key );   // stateful MEGA effects off (Ultimate Tank HP)
    }
    set_machine_glow( key, 0 );             // dark
}

// The restore, threaded from undo_hack (idempotent caller already guards double-restore).
function apply_unhack_effect( key )
{
    level endon( "end_game" );
    if ( key == "pap" )
    {
        level.acc_pap_hacked = false;
        set_machine_glow( "pap", 10 );
    }
    else
    {
        zm_perks::perk_unpause( key );
        set_vending_triggers( key, true );
        acc_mega_bottles::on_perk_restored( key );  // Ultimate Tank HP back + Widow's stance watcher re-applied
        set_machine_glow( key, acc_perk_lights::perk_color_index( key ) );
    }
}

// Enable/disable every buy trigger of this specialty (the zombie_vending trigger IS the purchase
// trigger - stock calls trigger methods on exactly this GetEntArray). Blanket re-enable is safe: stock
// gates power/cost INSIDE the vending think loop, not via TriggerEnable, so we're not fighting stock state.
function set_vending_triggers( key, enabled )
{
    vendors = GetEntArray( "zombie_vending", "targetname" );
    for ( i = 0; i < vendors.size; i++ )
    {
        v = vendors[ i ];
        if ( isdefined( v ) && isdefined( v.script_noteworthy ) && v.script_noteworthy == key )
            v TriggerEnable( enabled );
    }
}

// Set the glow index (0 = dark) on EVERY machine of this specialty (both the Lab machine AND the
// Paradise duplicate at z=-1200) - perk_pause is per-specialty (affects both dimensions), so the glow
// must match, and darkening all guarantees the Lab machine is never left lit while the perk is hacked.
function set_machine_glow( key, color_index )
{
    if ( key == "pap" )
    {
        if ( isdefined( level.acc_pap_glow_host ) )
            acc_perk_lights::set_glow( level.acc_pap_glow_host, color_index );
        return;
    }
    vendors = GetEntArray( "zombie_vending", "targetname" );
    for ( i = 0; i < vendors.size; i++ )
    {
        v = vendors[ i ];
        if ( isdefined( v.script_noteworthy ) && v.script_noteworthy == key && isdefined( v.machine ) )
            acc_perk_lights::set_glow( v.machine, color_index );
    }
}

function display_name( key )
{
    switch ( key )
    {
        case "specialty_armorvest":         return "Juggernog";
        case "specialty_quickrevive":       return "Quick Revive";
        case "specialty_staminup":          return "Stamin-Up";
        case "specialty_widowswine":        return "Widow's Wine";
        case "specialty_combat_efficiency": return "Electric Cherry";
        case "pap":                         return "Pack-a-Punch";
        default:                            return key;
    }
}

function announce( text )
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
        if ( isdefined( players[ i ] ) )
            players[ i ] iprintln( text );
}

// Prominent all-player UI alert when a machine goes down / comes back (user 2026-07-05: "there needs to be a
// UI alert so all players are aware" - e.g. Jugg off = back to 100 HP). Upper-center cyan toast to EVERY
// player, ALWAYS-ON (this is the normal-play tell now, not just dev). PAIRS WITH the perk-row BLINK: while a
// perk is hacked, level.acc_avo_hacked[ specialty ] stays true and acc_lui::perk_state_watch pulses that
// perk's row icon (1Hz base<->mega art flip - NO new clientfield, the clientuimodel pool is full; docs/11).
// The toast is the instant tell, the blink the persistent one. PaP is not on the perk row, so only the 4
// perk keys blink; "pap" shows just the toast.
function hack_alert( key, on )
{
    txt = ( on ? "^5AVOGADRO DISABLED ^7" : "^2RESTORED ^7" ) + display_name( key );
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
        if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
            players[ i ] acc_utility::hud_msg( txt );
}

// ---------------------------------------------------------------------------
// Death rewards (standard boss drops - item + mega bottle + shards, per player)
// ---------------------------------------------------------------------------

function grant_drops( org )
{
    if ( IS_TRUE( level.acc_paradise_onslaught ) )
        return;
    if ( !isdefined( org ) )
        return;

    // (Floor-snap pre-clamp removed 2026-07-08 review cleanup: acc_boss_items::spawn_pickup now
    // universally snaps EVERY drop to the floor - the duplicate trace here bypassed the
    // acc_drop_floor_snap dvar and had to be kept in sync by hand.)

    // Shared boss reward (user 2026-07-05: every boss identical) - 1 item + 1 bottle + round-scaled pts +
    // int(round/3) shards, per player. spawn_pickup floor-snaps the drop origin.
    acc_boss::grant_unified_boss_reward( org );
    dbg( "drops granted at " + org );
}
