// =============================================================================
// _acc_boss_scientist.gsc - "The Scientist" special enemy (docs/44 workstream B)
//
// The Pentagon Thief homage (BO1 "Five" / Dr. Yuri Zavoyski): a crazed lab-coat
// scientist wreathed in RED 115-numbers who sprints at a player, STEALS their
// held gun on touch, then RUNS AWAY ON FOOT at round+5 sprint (NO TELEPORTS EVER -
// user 2026-07-18: teleporting belongs to the Glitch/Phantom only; every teleport
// path removed, containment + flee are goal-driven walking). Kill him before he escapes
// and the gun comes back + Max Ammo (+ a Fire Sale if he never got a gun at all,
// the BO1 "Bonfire" nod). If he escapes (60s), the gun is GONE FOREVER (user
// 2026-07-17 - superseded the BO1 hostage-return draft). Home turf = THE LAB.
//
// Blueprint = the real BO1 thief AI (tmp/bo1_reimagined_ref/maps/_zombiemode_ai_thief.gsc,
// asset names in docs/44). Deliberate deltas from BO1, all forced by what a
// promoted STOCK zombie can do headlessly (docs/44 fidelity table):
//   - body = Ninjamanny ZC-Ascension labcoat (p7_zm_dlchd_cosmo_labcoat_body) via
//     the trench-skins SetModel+Detach+Attach idiom, NOT the BO1 thief mesh;
//   - run = stock sprint gait, NOT the simianaut crouch-run (no custom xanims);
//   - steal = BOSS-SIDE PROXIMITY (0.2s ring check), NOT a damage-callback hook.
//     CRITICAL: god mode suppresses the whole player-damage callback chain
//     (EnableInvulnerability - the Phantom chain-slow hit this exact wall,
//     _acc_elites.gsc ~L540 comment), so a MOD_MELEE hook would make the steal
//     UNTESTABLE in the dev/god sandbox. Touch-steal also IS the BO1 mechanic.
//   - flee = goal-driven RUNNING via v_zombie_custom_goal_pos (2026-07-18 rewrite;
//     the v1 phantom-style blink flee is GONE - no-teleport rule, see flee_loop).
//
// CADENCE: own special-enemy schedule (like BO1's thief round replacing dog
// rounds), NOT a 5th slot in the shared r9/18/27 roster deck - the deck +
// debt/re-home machinery in _acc_civil_protector stays untouched (docs/44
// records this supersedes the earlier "join the deck" plan line). Debt-based
// director clone (spawn can be DELAYED, never dropped).
//
// Scaffold: _acc_boss_phantom (spawn_promoted_zombie is CALLED cross-module, not
// cloned). Skin idiom: _acc_trench_skins.gsc:97-100. FX: red numbers trail on a
// linked tag_origin fx_org = the exact BO1 fx_zombie_tech_trail recipe; bursts
// ride acc_utility::derez_burst( ..., "scientist" ).
// =============================================================================

#using scripts\shared\util_shared;
#using scripts\codescripts\struct;   // struct::get_array (script_structs are NOT ents - GetEntArray misses them)
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss;             // grant_unified_boss_reward (shared boss death payout)
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_nameplate;   // attach (LUI bar row; the 3D plate is removed) + bb_release (escape = graceful row drop, no kill flash)
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_phantom;   // scale_phantom_hp(round, exp) = the SHARED boss HP curve (65k base, r5 anchor); we pass our own 1.04 exponent
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;       // force_playable_emergence (below-volume melee unlock)

#using scripts\zm\_zm_powerups;   // specific_powerup_drop (Max Ammo / Fire Sale)
#using scripts\zm\_zm_zonemgr;    // zone_is_enabled (no spawn while the lab is still closed)
#using scripts\zm\_zm_utility;    // is_player_valid + get_player_weapon_limit (armory idiom)
#using scripts\zm\_zm_weapons;    // give_fallback_weapon (stock laststand idiom - victim must never be left hands-empty)

#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;   // true_base (dupe-guard across base/_up/twin forms)
#using scripts\zm\zm_abandoned_cyber_city\_acc_zombie_speed;      // tier_for_round + rate_for_round (the round+5 speed ask)

#insert scripts\shared\shared.gsh;

// --- Tunables (live dvars, acc_scientist_*) ---------------------------------
#define ACC_SCI_ENABLE_DEF          1     // master on/off (gates the cadence; dev bypasses like the Phantom's gate)
#define ACC_SCI_FIRST_ROUND_DEF     15    // SHIP debut round (user 2026-07-18 release spec)
#define ACC_SCI_RESPAWN_ROUNDS_DEF  4     // rounds after a death/escape before the next Scientist (die r16 -> next r20)
// (ACC_SCI_HP_MULT_DEF removed 2026-07-18: HP now rides the SHARED boss curve at exponent 1.04
//  - see the spawn_scientist HP block; live dvar acc_scientist_hp_exp.)
#define ACC_SCI_STEAL_RANGE_DEF     96    // 3D proximity (units) that triggers the steal (user test 2026-07-17: 56 was touch-tight - "i got close and he never took my gun"; 96 = a confident grab radius)
#define ACC_SCI_ESCAPE_SEC_DEF      60    // flee seconds before he de-rezzes out with the gun (user 2026-07-17: "1 minute for now")
#define ACC_SCI_FLEE_DIST_DEF       420   // how far ahead the flee RUN goal is projected away from the nearest player (blink cadence defines removed 2026-07-18 with the teleports)
#define ACC_SCI_MELEE_DMG_DEF       1     // he is a THIEF, not a bruiser (BO1 thief deals no damage; 1 not 0 - stock treats 0 as unset)
#define ACC_SCI_CHASE_RANGE_DEF     450   // roam_loop switches from lab patrol to CHASE when a valid player is inside this range

// [ACC-SCI-SCALE REMOVED 2026-07-19 - IT WAS THE LIVE-CTD ROOT CAUSE. DO NOT RE-ADD.]
// The 2026-07-18 "1.3x body scale" experiment deliberately retested the project-wide
// "no SetScale on live AI" ban (0xC0000005, minidump-verified on Brutus 2026-06-15) on
// the theory that a STOCK-skeleton actor + a single deferred post-emerge write avoided
// Brutus's aggravating factors. EMPIRICALLY REFUTED: with it in, every Scientist spawn
// hard-CTD'd the server thread ~4-6s after his rise - exactly the deleted scale_pin()
// fire window (emerge-complete + 0.5s poll + 1.0s settle) - READ AV at exe+0x15bf48f
// (minidump 2026-07-19; a NEW offset, matching no prior crash class), and it reproduced
// on SUBSCRIBER machines via the 2026-07-18 published build ("the Scientist breaks the
// map") at the r15 ship cadence, killing every local-env explanation. Every OTHER write
// in that window (sprint gait + ASMSetAnimationRate, custom-goal driving, the SetModel
// reskin) is field-proven on this map's other bosses and ran clean in the pre-scale
// 2026-07-17/18 live sessions. VERDICT: the SetScale ban is UNCONDITIONAL - skeleton,
// deferral, and write-count do not matter. He ships at 1.0x; his size identity is the
// red numbers aura, not scale. Docs/44 workstream B records the incident.

#define ACC_SCI_DISPLAY_NAME "THE SCIENTIST"

#namespace acc_boss_scientist;

// ---------------------------------------------------------------------------
// Lifecycle + cadence (thief-style special rounds; debt director like the Phantom)
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "boss_scientist: init (Pentagon Thief homage - lab-lurking weapon thief, docs/44)" );
    sci_log( "init: TRACE v3 module live" );   // version tag - proves the tested build carries the full trace
    acc_utility::derez_register();   // acc_sci_trail must exist before the first spawn's PlayFxOnTag

    // THE LAB is his territory (user 2026-07-17): spawns there and is LEASHED there until he
    // steals. ANCHOR = the lab mystery-box struct (guaranteed ROOM INTERIOR) - NOT the zone's
    // spawner structs: those are riser/behind-barrier points OUTSIDE the playable volume (user
    // test: "he doesn't move, he teleports" = anchors outside the lab_zone volume put the 3s
    // leash into an endless snap-loop). Fallback anchor = the spawner CENTROID (~room middle
    // even when individual structs are risers).
    level.acc_sci_lab_volume = GetEnt( "lab_zone", "targetname" );
    level.acc_sci_lab_center = undefined;
    a_box = struct::get_array( "acc_awbox_lab", "targetname" );
    if ( isdefined( a_box ) && a_box.size > 0 )
    {
        level.acc_sci_lab_center = a_box[ 0 ].origin;
    }
    else
    {
        a_sp = struct::get_array( "lab_zone_spawners", "targetname" );
        if ( isdefined( a_sp ) && a_sp.size > 0 )
        {
            sum = ( 0, 0, 0 );
            for ( i = 0; i < a_sp.size; i++ )
                sum += a_sp[ i ].origin;
            level.acc_sci_lab_center = sum * ( 1.0 / a_sp.size );
        }
    }

    // Flee shuttle anchor (user 2026-07-18 "run all the way to spawn to plaza... back and
    // forth between lab and plaza once he has a gun"): plaza = the CENTROID of the actual
    // player spawn structs (initial_spawn_points - guaranteed present + navigable, it IS the
    // spawn). The lab end reuses acc_sci_lab_center.
    level.acc_sci_plaza_center = undefined;
    a_isp = struct::get_array( "initial_spawn_points", "targetname" );
    if ( isdefined( a_isp ) && a_isp.size > 0 )
    {
        psum = ( 0, 0, 0 );
        for ( i = 0; i < a_isp.size; i++ )
            psum += a_isp[ i ].origin;
        level.acc_sci_plaza_center = psum * ( 1.0 / a_isp.size );
    }

    level.acc_sci_debt = 0;
    level.acc_sci_pending = [];   // LEVEL-side mirror of every carried loot struct (review 2026-07-17):
                                  // the death notify can wake with self already reaped (the phantom 4p
                                  // race) - without this mirror that race would EAT the victim's gun.
    level thread round_watch();
    level thread director();

    // Trace the lab wiring resolution - a bad anchor/volume is diagnosed at init, not mid-test.
    vol = "MISSING!";
    if ( isdefined( level.acc_sci_lab_volume ) ) vol = "ok";
    ctr = "MISSING!";
    if ( isdefined( level.acc_sci_lab_center ) )
        ctr = "" + int( level.acc_sci_lab_center[ 0 ] ) + " " + int( level.acc_sci_lab_center[ 1 ] );
    sci_log( "init: lab volume=" + vol + " center=" + ctr );
}

// A random navigable point INSIDE the lab: a ring sample around the room-interior anchor
// (60-320u out, random bearing), nav-clamped, 3 attempts, center itself as the last resort.
// (v1 used raw lab_zone_spawners structs - riser/behind-barrier points OUTSIDE the volume,
// which fed the leash snap-loop. NO (0,0,0)-volume-origin fallback either - callers all
// handle undefined by staying put.)
function lab_point()
{
    if ( !isdefined( level.acc_sci_lab_center ) ) return undefined;

    for ( i = 0; i < 3; i++ )
    {
        ang = RandomFloatRange( 0, 360 );
        r   = RandomFloatRange( 60, 320 );
        cand = level.acc_sci_lab_center + ( Cos( ang ) * r, Sin( ang ) * r, 0 );
        nav = GetClosestPointOnNavMesh( cand, 120, 40 );
        if ( isdefined( nav ) ) return nav;
    }
    return GetClosestPointOnNavMesh( level.acc_sci_lab_center, 120, 40 );
}

function round_watch()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
        // Debt caps at 1 + accrual skips while a pre-steal Scientist is still lurking (review
        // 2026-07-17): an untriggered lurker persists indefinitely, so uncapped accrual would
        // pile multiple leashed Scientists into the lab over the ignored rounds.
        if ( level.acc_sci_debt >= 1 ) { sci_log( "round " + round_number + ": debt already 1, no accrual" ); continue; }
        if ( isdefined( level.acc_sci_lurker ) && isalive( level.acc_sci_lurker )
             && !IS_TRUE( level.acc_sci_lurker.acc_sci_fleeing ) )
        { sci_log( "round " + round_number + ": lurker alive, no accrual" ); continue; }
        if ( due_this_round( round_number ) )
        {
            level.acc_sci_debt++;
            sci_log( "round " + round_number + ": DUE - debt now " + level.acc_sci_debt );
        }
    }
}

function due_this_round( round_number )
{
    // RELEASED 2026-07-18 (user: "he is ready for release" - the dev-only gate is gone).
    if ( getdvarint( "acc_scientist_enable", ACC_SCI_ENABLE_DEF ) != 1 && !IS_TRUE( level.acc_dev ) )
        return false;   // ship kill-switch (dev bypasses, matching the phantom's gate shape)

    // NO SPAWN WHILE THE LAB IS CLOSED (user 2026-07-18): his territory must be reachable.
    // zone_is_enabled = the stock zonemgr accessibility check, flips when any lab door opens.
    if ( !zm_zonemgr::zone_is_enabled( "lab_zone" ) )
    {
        sci_log( "round " + round_number + ": lab still closed - no spawn" );
        return false;
    }

    // DEV accelerator kept for future test sessions: every round from 3.
    if ( IS_TRUE( level.acc_dev ) )
        return ( round_number >= 3 );

    // SHIP CADENCE (user 2026-07-18): debut round 15; after each death OR escape the next
    // spawn comes ACC_SCI_RESPAWN_ROUNDS later (die r16 -> next r20) - set by death_watch /
    // the escape path via level.acc_sci_next_round. An unkilled lurker persists across rounds
    // (the single-lurker gate blocks re-accrual until he's gone).
    next = getdvarint( "acc_scientist_first_round", ACC_SCI_FIRST_ROUND_DEF );
    if ( isdefined( level.acc_sci_next_round ) ) next = level.acc_sci_next_round;
    return ( round_number >= next );
}

// Debt director (Phantom pattern): keeps retrying while owed, spends 1 per live spawn.
function director()
{
    level endon( "end_game" );
    for ( ;; )
    {
        wait 3;
        if ( level.acc_sci_debt <= 0 ) continue;
        if ( !isdefined( level.round_number ) ) continue;   // pre-round-1 init window
        // Hold while a pre-steal lurker is alive (one resident thief at a time).
        if ( isdefined( level.acc_sci_lurker ) && isalive( level.acc_sci_lurker )
             && !IS_TRUE( level.acc_sci_lurker.acc_sci_fleeing ) ) continue;
        sci_log( "director: attempting spawn (debt " + level.acc_sci_debt + ")" );
        host = spawn_scientist( level.round_number );
        if ( isdefined( host ) )
        {
            level.acc_sci_lurker = host;
            level.acc_sci_debt--;
        }
        else
        {
            sci_log( "director: spawn FAILED (promote factory returned nothing) - retrying in 3s" );
        }
    }
}

// ---------------------------------------------------------------------------
// Spawn + identity
// ---------------------------------------------------------------------------

// [acc] FX-ORG GUARDIAN (red-trail audit 2026-08-02, belt-and-braces): every NORMAL Scientist
// exit deletes acc_sci_fx_org (death_watch both branches + the escape path), but death_watch
// blocks in a waittill("death") that a host freed WITHOUT a death notify (forced Delete /
// engine cull - the documented brutus_guard_failsafe case, _acc_boss.gsc:484-501) never wakes -
// that would strand the LOOPING red-digit trail as an orphaned static column (host-delete is
// the ONLY server-side stop for a looping PlayFxOnTag fx). Poll: if the host vanishes while
// the org still exists, delete the org. Self-ends once the org is gone. (No leak was ever
// OBSERVED - the 2026-08-02 "phantom had red digits" sighting was the Scientist's ~2s glyph
// WAKE overlapping a warping Phantom under the every-round dev cadence.)
function sci_fx_org_guardian( host, fx_org )
{
    level endon( "end_game" );
    for ( ;; )
    {
        wait 1;
        if ( !isdefined( fx_org ) ) return;   // normal exit cleaned it up - done
        if ( !isdefined( host ) )
        {
            fx_org Delete();
            return;
        }
    }
}

function spawn_scientist( round_number )
{
    // NATIVE LAB-RISER SPAWN (2026-07-18, the step-back fix - LOG-PROVEN diagnosis: the old
    // promote-then-cross-map-teleport was OVERRIDDEN by the stock emerge system, which yanked
    // him 1289u back out of the lab in the first heartbeat and left the BT never-properly-
    // started - statue until damage force-restarts the tree. The pattern every working spawn
    // on this map uses is NEVER FIGHT THE SPAWN PIPELINE: stock spawn_zombie takes a
    // spawn_point param (zombie_utility.gsc:1454) - hand it a LAB riser struct and he RISES
    // IN THE LAB like any zombie: full natural emerge, ignoreall/ai_state handled by stock,
    // healthy behavior tree, ZERO teleports, nothing to repair afterwards.
    risers = struct::get_array( "lab_zone_spawners", "targetname" );
    if ( !isdefined( risers ) || risers.size == 0 )
    {
        sci_log( "spawn: NO lab_zone_spawners structs - cannot spawn" );
        return undefined;
    }
    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
        return undefined;

    host = undefined;
    attempts = 0;
    while ( attempts < 10 && !isdefined( host ) )
    {
        spot    = risers[ acc_utility::acc_rand_int( risers.size ) ];
        spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];
        spawner.script_forcespawn = true;   // REQUIRED or spawn_zombie returns undefined (stock)
        host = zombie_utility::spawn_zombie( spawner, undefined, spot );
        if ( !isdefined( host ) )
        {
            attempts++;
            sci_log( "spawn: attempt " + attempts + " failed, retrying" );
            wait 1;
        }
        else
        {
            sci_log( "spawn: rising at lab riser " + int( spot.origin[ 0 ] ) + " " + int( spot.origin[ 1 ] ) );
        }
    }
    if ( !isdefined( host ) )
    {
        sci_log( "spawn: gave up after 10 attempts" );
        return undefined;
    }

    // Init-gate: stock zombie_spawn_init clobbers fields at frame end (phantom factory precedent).
    n = 0;
    while ( isdefined( host ) && !isdefined( host.zombie_init_done ) && n < 100 )
    {
        util::wait_network_frame();
        n++;
    }
    if ( !isdefined( host ) || !isalive( host ) )
        return undefined;

    host.acc_is_mini_boss = true;    // boss headshot mult + corpse-cleanup skip + speed-keepalive skip + octobomb/splash boss filters
    host.acc_is_scientist = true;

    // LOOK: labcoat scientist body + a cosmo head (trench-skins idiom - heads self-align; the
    // charred head must come OFF first or two heads stack). Attach'd models survive SetModel.
    host SetModel( "p7_zm_dlchd_cosmo_labcoat_body" );
    host Detach( "c_zom_dlc4_zombie_charred_head" );
    host Attach( "p7_zm_dlchd_cosmo_cosmo_head" + ( acc_utility::acc_rand_int( 5 ) + 1 ) );

    // BOSS-TIER HP (user 2026-07-18 "boss level scaling"; exponent 1.03 -> 1.04 -> 1.05 user
    // 2026-07-25): the shared boss curve - 65k base @ the round-5 anchor, compounding
    // x1.05/round = still the SOFTEST tier (tank ladder: Brutus 1.12 > Panzer 1.1 > Rogue 1.09 >
    // Phantom/Avo 1.07 > Scientist 1.05 - he's a chase target, not a sponge), x the coop
    // boss-HP table like every boss. r15 solo ~106k. Live dvar acc_scientist_hp_exp. Written AFTER the init-gate.
    // DEV: flat 1000 HP (user 2026-07-17) - hardcoded on the one flag per the dev doctrine.
    if ( IS_TRUE( level.acc_dev ) )
    {
        host.maxhealth = 1000;
    }
    else
    {
        // user 2026-07-26: -0.01 all-boss health nerf, exp 1.05 -> 1.04 (the SOFTEST tier stays softest).
        host.maxhealth = int( acc_boss_phantom::scale_phantom_hp( round_number,
                                  getdvarfloat( "acc_scientist_hp_exp", 1.04 ) )
                              * acc_coop_scaling::boss_hp_player_mult() );
    }
    host.health = host.maxhealth;

    host.meleeDamage = getdvarint( "acc_scientist_melee_dmg", ACC_SCI_MELEE_DMG_DEF );

    host DisableAimAssist();
    host.disableAmmoDrop = true;
    host.no_gib = true;                  // the labcoat gib set exists but is NOT zoned - gibbing would swap to a missing model
    host.ignore_nuke = true;
    host.ignore_enemy_count = true;      // fights alongside the wave; never gates round end
    host.acc_boss_custom_speed = true;   // _acc_zombie_speed keep-alive skips us (we pin sprint below)
    host.ignore_round_spawn_failsafe = true;   // review 2026-07-17: the stock 30s/24u no-move failsafe
                                               // (zombie_utility:1869 dodamage) would silently execute a
                                               // leashed lurker with no players near the lab

    // (The force_playable_emergence thread, the cross-map teleport-home, AND the manual
    // ignoreall/BT repair kit are all GONE with the native lab-riser spawn (2026-07-18):
    // the NATURAL emerge clears ignoreall / sets ai_state / completes the tree by itself -
    // that is the entire point of not fighting the pipeline. Only the goal-radius companion
    // stays: it tunes OUR custom-goal driving on a healthy zombie.)
    host.n_zombie_custom_goal_radius = 40;   // official companion (zombie.gsc:465) - stops "already at goal" idling on patrol points

    sci_log( "spawn state: ignoreall=" + ( IS_TRUE( host.ignoreall ) ? "y" : "n" )
             + " emerged=" + ( IS_TRUE( host.completed_emerging_into_playable_area ) ? "y" : "n" )
             + " ground=" + ( IS_TRUE( host.in_the_ground ) ? "y" : "n" )
             + " init=" + ( isdefined( host.zombie_init_done ) ? "y" : "n" ) );

    // RED numbers trail - the exact BO1 fx_zombie_tech_trail recipe: PlayFxOnTag on a tag_origin
    // script_model linked to the actor (fx dies with the ent; ent deleted on death).
    host.acc_sci_fx_org = Spawn( "script_model", host.origin + ( 0, 0, 40 ) );
    if ( isdefined( host.acc_sci_fx_org ) )
    {
        host.acc_sci_fx_org SetModel( "tag_origin" );
        host.acc_sci_fx_org LinkTo( host );
        PlayFxOnTag( level._effect[ "acc_sci_trail" ], host.acc_sci_fx_org, "tag_origin" );
        level thread sci_fx_org_guardian( host, host.acc_sci_fx_org );
    }

    // BOSS UI (REVERSAL 2026-07-24, user "Lets add the scientist in as well and he will be
    // white" - supersedes 2026-07-17 "I dont even want a name above him"): direct attach()
    // like Brutus - deliberately NOT the acc_boss_spawned notify (that implies boss music +
    // the Kortifex sendoff; he's a lurker). Gets a peach-white CoD.AccBossBars row (the 3D
    // plate was removed 2026-07-25; name index 4 = the repurposed unused Glitch slot).
    // health/maxhealth are already set above (the bar reads them).
    acc_boss_nameplate::attach( host, ACC_SCI_DISPLAY_NAME );

    // CONSTANT NUMBERS HUM (user 2026-07-17 "he needs a constant number sfx that you hear when
    // you get close to him"). No wav could be sourced, so it is SYNTHESIZED - a numbers-station
    // loop (digital tone blips + static bed + 52Hz menace hum), 4s seamless, generated by
    // tools/gen_scientist_numbers_wav.js -> sound_assets/acc/fx/scientist_numbers_lp.wav
    // (deterministic PRNG - regen reproduces it; replace the wav at the same path to reskin).
    // Alias acc_scientist_numbers_lp: LOOPING 3D, full volume inside grab range (DistMin 80),
    // fades out ~chase range (450/600) = "you HEAR him before he has you". The loop rides the
    // boss ent and dies with it (death cleanup + escape both Delete()).
    host PlayLoopSound( "acc_scientist_numbers_lp" );

    // Arrival: red de-rez burst + the crazed (pitched-UP) warp cackle + a line so players know
    // to protect their gun. acc_utility::derez_burst registers the fx keys lazily incl. acc_sci_trail.
    // (acc_scientist_warp PlaySound REMOVED 2026-07-18 with the whole warp-family sound kit -
    // "I still hear him trying to teleport". His audio identity = the constant numbers hum.)
    acc_utility::derez_burst( host.origin, "scientist" );
    // ONCE PER MATCH (user 2026-08-01): he respawns every ~4 rounds - the first arrival explains
    // the threat; after that the nameplate/hum/derez burst are the tell. The steal/escape
    // warnings below stay always-on (actionable). Direct announce_once, NOT announce() - that
    // wrapper has always-on callers.
    acc_utility::announce_once( "sci_arrival", "^1" + ACC_SCI_DISPLAY_NAME + " ^7- he wants your weapon. Don't let him touch you." );

    // (scale_pin REMOVED 2026-07-19: the 1.3x SetScale was the live-CTD root cause - see the
    // ACC-SCI-SCALE post-mortem at the top of this file. Never scale a live actor.)
    host thread sprint_pin();
    host thread roam_loop();    // the movement driver - lab patrol / whole-lab chase / walk-home containment
    host thread steal_watch();
    host thread death_watch( round_number, host.acc_sci_fx_org );   // fx_org passed by value: still deletable when self is reaped
    host thread dev_status_loop();                                  // 3s dev heartbeat (no-op in ship)

    sci_log( "spawned in lab r" + round_number + " hp=" + host.maxhealth );
    acc_utility::log( "scientist: spawned r" + round_number + " hp " + host.maxhealth );
    return host;
}

// Pin the sprint gait (stock resets zombie_move_speed on round/speed sweeps; the keep-alive
// skips us via acc_boss_custom_speed, so we are the single writer - NO ASMSetAnimationRate,
// the confirmed crasher class).
function sprint_pin()
{
    self endon( "death" );
    level endon( "end_game" );
    // Speed pinning only starts once the natural emerge is done - writing ANY tree/anim state
    // during the rise is the log-proven statue cause. On a healthy zombie the tree runs its
    // own targeting (find_flesh), facing, and path modes - we deliberately touch NOTHING but
    // the gait tier + anim rate (the minimal-intervention lesson of this whole hunt).
    while ( isdefined( self ) && !IS_TRUE( self.completed_emerging_into_playable_area ) )
        wait 0.5;

    wait 0.5;   // 2026-07-19 hardening: keep the FIRST gait/rate write off the emerge-completion
                // frame itself (the CTD window sat right on that transition; costs nothing)

    for ( ;; )
    {
        // Delete() does NOT fire "death" (repo-proven: avogadro nameplate guard) - the ESCAPE
        // path removes the ent without tripping our endon, so guard every write (review 2026-07-17).
        // isalive too (2026-07-19): never write gait/anim state into a dying/ragdolling actor.
        if ( !isdefined( self ) || !isalive( self ) ) return;

        // ROUND+5 SPEED (user 2026-07-17 "if he gets you on round 15 he runs as fast as a
        // zombie does on round 20") with a SPRINT FLOOR (user test 2026-07-18 "he is slower
        // than zombies"): tier ALWAYS sprint (thief identity), rate = the +5 curve evaluated
        // no lower than the sprint start round. acc_boss_custom_speed keeps the global
        // keep-alive OFF this actor = we are its SINGLE ASMSetAnimationRate writer.
        // RAMPAGE-aware base (user 2026-08-03): BOTH his +5 curve AND the anti-horde floor
        // below must read the rampaged round (+7 while the spawn toggle is ON) - if `cur`
        // stayed un-rampaged, a rampaged horde could outrun him at high rounds, silently
        // breaking the "always visibly quicker" invariant (the exact 2026-07-18 bug class).
        // effective_round() handles the undefined-round load window (returns 1).
        cur = acc_zombie_speed::effective_round();
        r5 = cur + 5;
        sr = acc_zombie_speed::sprint_start_round();
        if ( r5 < sr ) r5 = sr;
        rate = acc_zombie_speed::rate_for_round( r5 );
        // HARD FLOOR vs the horde (self-caught from the 2026-07-18 log: rate=1 vs horde=1.026 -
        // the +5 curve clamps to 1.0 early in the sprint phase while the jog curve is already
        // above it): his RATE must also be strictly above this round's horde rate, not just his
        // TIER. x1.10 = always visibly quicker, whatever phase either curve is in.
        floor_rate = acc_zombie_speed::rate_for_round( cur ) * 1.10;
        if ( rate < floor_rate ) rate = floor_rate;
        self.zombie_move_speed = "sprint";
        self ASMSetAnimationRate( rate );

        wait 2;
    }
}

// (lab_leash REMOVED 2026-07-18 - it teleport-snapped him home, violating the no-teleport
// rule the same way the flee blinks did. Containment is now a WALK-HOME branch inside
// roam_loop: outside the lab pre-steal -> his goal becomes a lab anchor and he runs back.)

// THE ROAM DRIVER (user 2026-07-17 "I was in the lab and he wasn't chasing me... he needs to
// be roaming the lab similar to how brutus roams the trench"). Root cause of the statue: the
// stock zombie BT had NO goal after the cross-map promote+teleport (favoriteenemy alone does
// not re-arm it), so he stood in the lab until proximity melee triggered. Fix = WE drive his
// movement every tick via `v_zombie_custom_goal_pos` - the STOCK zombie BT's custom-goal hook
// (zombie.gsc:460 / _zm_behavior.gsc:276; the SAME hook the NSZ pack chase and the Trench
// Warden patrol write). Behavior mirror of warden_patrol_step:
//   - a valid player within acc_scientist_chase_range -> goal = THEM every tick (real chase;
//     if it drags him out of the lab the 3s leash yanks him home = doorway prowling);
//   - nobody near -> patrol: wander random lab spawner points (new point on arrival/4s dwell).
// Ends at the steal - flee_loop owns movement after (and writes the same hook to keep him
// RUNNING AWAY between blinks).
function roam_loop()
{
    self endon( "death" );
    level endon( "end_game" );

    // LET THE NATURAL EMERGE FINISH before driving any goals (log-proven: fighting the rise
    // is what broke the tree). On a healthy lab-riser spawn this takes a few seconds; the
    // 15s fallback re-applies the old repair kit and should NEVER fire - if you see its log
    // line, the spawn pipeline itself failed and that is the bug to chase.
    t0 = GetTime();
    while ( isdefined( self ) && !IS_TRUE( self.completed_emerging_into_playable_area ) )
    {
        wait 0.25;
        if ( !isdefined( self ) ) return;
        if ( ( GetTime() - t0 ) > 15000 )
        {
            sci_log( "roam: emerge TIMED OUT after 15s - repair-kit fallback (should never happen)" );
            self.ignoreall = false;
            self thread acc_bus_trench::force_playable_emergence();
            break;
        }
    }
    sci_log( "roam: emerge complete after " + int( ( GetTime() - t0 ) / 1000 ) + "s - goal driving live" );

    goal  = undefined;
    ticks = 0;
    for ( ;; )
    {
        wait 0.1;
        if ( !isdefined( self ) ) return;
        if ( IS_TRUE( self.acc_sci_fleeing ) ) return;   // flee_loop owns the hook now

        // CONTAINMENT BY WALKING (2026-07-18, replaces the teleport leash): outside the lab
        // pre-steal -> goal = home, he RUNS back; chase is suppressed until he's inside again.
        if ( isdefined( level.acc_sci_lab_volume ) && !( self IsTouching( level.acc_sci_lab_volume ) ) )
        {
            if ( !isdefined( goal ) || ( ticks % 20 ) == 0 )   // re-anchor every ~2s while outside
            {
                home = lab_point();
                if ( isdefined( home ) ) goal = home;
            }
            ticks++;
            if ( isdefined( goal ) )
            {
                self.v_zombie_custom_goal_pos = goal;
                self SetGoal( goal );
                self.acc_sci_written_goal = goal;   // hijack-detector reference
            }
            if ( IS_TRUE( self.acc_sci_chasing ) )
            {
                self.acc_sci_chasing = false;
                sci_log( "chase suspended: outside the lab, running home" );
            }
            continue;
        }

        // CHASE = THE WHOLE LAB (user 2026-07-18 "his target area doesn't seem like the whole
        // lab"): any valid player INSIDE the lab volume is a target regardless of distance;
        // the range check only extends the chase to just-outside-the-door players.
        near = nearest_player( self.origin );
        target_in_lab = ( isdefined( near ) && isdefined( level.acc_sci_lab_volume )
                          && near IsTouching( level.acc_sci_lab_volume ) );
        d_near = 999999;
        if ( isdefined( near ) ) d_near = Distance( self.origin, near.origin );
        if ( isdefined( near )
             && ( target_in_lab || d_near < getdvarint( "acc_scientist_chase_range", ACC_SCI_CHASE_RANGE_DEF ) ) )
        {
            if ( !IS_TRUE( self.acc_sci_chasing ) )
            {
                self.acc_sci_chasing = true;
                sci_log( "CHASE acquired: dist=" + int( d_near ) + ( target_in_lab ? " (in-lab)" : " (in-range)" ) );
            }
            // 2026-07-19 hardening: navmesh-project the chase goal - a player standing on a
            // prop/clip (537 misc statics since the deco sweep) is an OFF-MESH point; never
            // hand SetGoal one raw. Fall back to the raw origin (the NSZ-chase precedent
            // behavior) only if the projection finds nothing within the search radius.
            chase_goal = GetClosestPointOnNavMesh( near.origin, 120, 40 );
            if ( !isdefined( chase_goal ) ) chase_goal = near.origin;
            self.v_zombie_custom_goal_pos = chase_goal;
            self SetGoal( chase_goal );   // engine-level goal alongside the BT hook (unstick combo)
            self.acc_sci_written_goal = chase_goal;   // hijack-detector reference
            goal = undefined;   // fresh patrol point when they leave
            continue;
        }
        if ( IS_TRUE( self.acc_sci_chasing ) )
        {
            self.acc_sci_chasing = false;
            sci_log( "chase lost (nearest " + int( d_near ) + "u, not in lab)" );
        }

        // PATROL between lab points (warden_patrol_step pattern).
        ticks++;
        pick = !isdefined( goal );
        if ( !pick && Distance( self.origin, goal ) < 80 )
        {
            pick = true;   // arrived
            sci_log( "patrol: reached point, picking next" );
        }
        if ( !pick && ticks > 40 )
        {
            pick = true;   // 4s dwell cap
            sci_log( "patrol: dwell timeout at " + int( Distance( self.origin, goal ) ) + "u short, repicking" );
        }
        if ( pick )
        {
            p = lab_point();
            if ( isdefined( p ) )
            {
                goal = p; ticks = 0;
                sci_log( "patrol: new point " + int( Distance( self.origin, goal ) ) + "u away" );
            }
            else
            {
                sci_log( "patrol: lab_point returned NOTHING (no navmesh around center?)" );
            }
        }
        if ( isdefined( goal ) )
        {
            self.v_zombie_custom_goal_pos = goal;
            self SetGoal( goal );   // engine-level goal alongside the BT hook (unstick combo)
            self.acc_sci_written_goal = goal;   // hijack-detector reference (heartbeat compares)
        }
    }
}

// ---------------------------------------------------------------------------
// The STEAL (boss-side proximity - works in god mode, see header)
// ---------------------------------------------------------------------------

function steal_watch()
{
    self endon( "death" );
    level endon( "end_game" );

    // No stealing while he's still rising out of the floor.
    while ( isdefined( self ) && !IS_TRUE( self.completed_emerging_into_playable_area ) )
        wait 0.5;

    range = getdvarint( "acc_scientist_steal_range", ACC_SCI_STEAL_RANGE_DEF );
    last_diag = 0;
    for ( ;; )
    {
        wait 0.2;
        if ( !isdefined( self ) ) return;
        if ( IS_TRUE( self.acc_sci_fleeing ) ) return;   // one gun per thief

        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            dsq = DistanceSquared( self.origin, p.origin );
            if ( dsq > ( 300 * 300 ) ) continue;   // diagnostics only care about nearby players

            // Rate-limited gate diagnostics (1/s max) - each rejection names its reason so a
            // silent no-steal is impossible to misdiagnose again (user test 2026-07-17).
            diag = ( ( GetTime() - last_diag ) > 1000 );

            if ( !zm_utility::is_player_valid( p ) )
            {
                if ( diag ) { sci_log( "steal gate: player not valid (downed/spectating?)" ); last_diag = GetTime(); }
                continue;
            }
            if ( IS_TRUE( p.acc_box_grabbing ) )   // mid box-grab = weapon state transitional (memory box-grab-defer)
            {
                if ( diag ) { sci_log( "steal gate: box grab in progress" ); last_diag = GetTime(); }
                continue;
            }
            if ( dsq > ( range * range ) )
            {
                if ( diag && dsq < ( 200 * 200 ) )
                {
                    sci_log( "closing: dist=" + int( Distance( self.origin, p.origin ) ) + " grab<=" + range );
                    last_diag = GetTime();
                }
                continue;
            }

            if ( self try_steal_from( p ) )
            {
                self thread flee_loop();
                return;
            }
            if ( diag ) last_diag = GetTime();   // try_steal_from logged its own miss reason
        }
    }
}

// self = the Scientist. Take the victim's HELD gun if it's a primary (BO1 priority); store
// weapon + ammo, wear the gun on our back, go evasive. Returns true on a successful steal.
function try_steal_from( p )
{
    w = p GetCurrentWeapon();
    if ( !isdefined( w ) ) { sci_log( "steal miss: no current weapon" ); return false; }

    prims = p GetWeaponsListPrimaries();
    held_is_primary = false;
    for ( i = 0; i < prims.size; i++ )
    {
        if ( prims[ i ] == w ) { held_is_primary = true; break; }
    }

    if ( held_is_primary )
    {
        // NEVER the CYBERJACK (quest-only signature weapon - a permanent steal could soft-lock
        // the quest; matcher = the module's own IsSubStr recipe, _acc_cyberjack.gsc:100).
        if ( isdefined( w.name ) && IsSubStr( w.name, "apex_lstar" ) )
        {
            sci_log( "steal miss: held gun is the cyberjack (protected)" );
            return false;
        }
    }
    else
    {
        // HELD-NOT-A-GUN FALLBACK (user test 2026-07-17 "i got close and he never took my gun":
        // in DEV the starting weapon is the Leviathan AXE - a melee, NOT a primary - so the old
        // held-only rule silently rejected every steal). BO1's own priority was "primary first":
        // if the held weapon isn't a primary gun, rob the first stealable HOLSTERED primary.
        w = undefined;
        for ( i = 0; i < prims.size; i++ )
        {
            cand = prims[ i ];
            if ( !isdefined( cand ) ) continue;
            if ( isdefined( cand.name ) && IsSubStr( cand.name, "apex_lstar" ) ) continue;   // cyberjack protected
            w = cand;
            break;
        }
        if ( !isdefined( w ) )
        {
            sci_log( "steal miss: no stealable primary in inventory (holding a non-gun, no primaries)" );
            return false;
        }
        sci_log( "held weapon is not a primary - robbing holstered " + w.name );
    }

    // Snapshot ammo BEFORE the take (restore exactly on return).
    self.acc_sci_loot = SpawnStruct();
    self.acc_sci_loot.weapon = w;
    self.acc_sci_loot.clip   = p GetWeaponAmmoClip( w );
    self.acc_sci_loot.stock  = p GetWeaponAmmoStock( w );
    self.acc_sci_loot.owner  = p;

    p TakeWeapon( w );
    // Land the victim on a survivable weapon - ONLY needed when we took the gun out of their
    // HANDS (a holstered rob leaves the held axe/whatever in place). Stock does NOT auto-switch
    // after TakeWeapon; a 1-gun victim would hold weaponNone for the whole chase and the "kill
    // him to get it back" contract would be unwinnable - stock fallback pistol (laststand idiom).
    if ( held_is_primary )
    {
        remaining = p GetWeaponsListPrimaries();
        if ( remaining.size > 0 )
            p SwitchToWeapon( remaining[ 0 ] );
        else
            p zm_weapons::give_fallback_weapon( 1 );
    }

    // Mirror the loot at LEVEL scope (review 2026-07-17): if the corpse is reaped the same frame
    // as the death notify (the phantom 4p race), death_watch wakes with self undefined - the
    // mirror is the only path that can still return the gun.
    level.acc_sci_pending[ level.acc_sci_pending.size ] = self.acc_sci_loot;

    // HOLD the stolen gun's world model IN HAND (user 2026-07-18) - probe the weapon hand tag
    // first (GetTagOrigin returns undefined for missing tags, the stock existence idiom; blind
    // Attach on a missing tag is a script error), fall back to the j_spine4 back-carry (exists
    // on all zombie-skeleton bodies - trench-skins note). worldModel undefined for exotics - skip.
    if ( isdefined( w.worldModel ) )
    {
        self.acc_sci_loot_model = w.worldModel;
        // ANIMATED bone, not tag_weapon_right (user 2026-07-18 "off to the side and behind
        // him, like a lagging gun"): the weapon tag EXISTS on the zombie rig but zombie anims
        // never animate it, so it floats at BIND POSE off the moving body. j_wrist_ri is an
        // animated skeleton bone - the gun rides his actual hand. j_spine4 = last resort.
        tag = "j_wrist_ri";
        if ( !isdefined( self GetTagOrigin( tag ) ) ) tag = "j_spine4";
        self Attach( w.worldModel, tag );
        sci_log( "carrying " + w.worldModel + " on " + tag );
    }

    acc_utility::derez_burst( self.origin, "scientist" );
    // Generic wording on purpose (review 2026-07-17): weapon.name is the internal codename
    // ("ar_accurate"), not a display name - naming it would read like debug text.
    p IPrintLnBold( "^1" + ACC_SCI_DISPLAY_NAME + " ^7stole your weapon! Kill him before he escapes!" );
    sci_log( "STOLE " + w.name + " (clip " + self.acc_sci_loot.clip + " stock " + self.acc_sci_loot.stock + ")" );
    return true;
}

// ---------------------------------------------------------------------------
// FLEE + escape (phantom-style away-blinks; red bursts both ends)
// ---------------------------------------------------------------------------

function flee_loop()
{
    self endon( "death" );
    level endon( "end_game" );

    self.acc_sci_fleeing = true;
    escape_at = GetTime() + ( getdvarint( "acc_scientist_escape_sec", ACC_SCI_ESCAPE_SEC_DEF ) * 1000 );
    sci_log( "FLEEING with the gun (ON FOOT) - " + getdvarint( "acc_scientist_escape_sec", ACC_SCI_ESCAPE_SEC_DEF ) + "s to kill him" );

    // NO TELEPORTS - EVER (user hard rule). FLEE v3 (user 2026-07-18 "run all the way to
    // spawn to plaza... back and forth between lab and plaza, still avoiding players"): a
    // SHUTTLE ROUTE between the lab and the plaza spawn - he sprints the whole leg, flips
    // ends on arrival, and any player closing within the avoid radius temporarily bends him
    // onto an away-vector (+/-75deg corner-escape bearings) until he shakes them.
    self.acc_sci_wp = "plaza";   // first leg: bolt for the spawn (away from the lab crime scene)
    while ( GetTime() < escape_at )
    {
        wait 0.5;
        if ( !isdefined( self ) ) return;

        wp = level.acc_sci_plaza_center;
        if ( self.acc_sci_wp == "lab" ) wp = level.acc_sci_lab_center;
        if ( isdefined( wp ) && Distance2D( self.origin, wp ) < 150 )
        {
            if ( self.acc_sci_wp == "plaza" ) { self.acc_sci_wp = "lab"; }
            else                              { self.acc_sci_wp = "plaza"; }
            sci_log( "flee shuttle: reached " + ( ( self.acc_sci_wp == "lab" ) ? "plaza" : "lab" ) + ", heading " + self.acc_sci_wp );
            wp = ( ( self.acc_sci_wp == "plaza" ) ? level.acc_sci_plaza_center : level.acc_sci_lab_center );
        }

        // CORNER-FREEZE PROOFING (user 2026-07-18 "make sure you can't just push him into a
        // corner where he freezes"): three guarantees stack so he ALWAYS has a live goal -
        //   1. STUCK DETECTOR: moved <40u over the last 3s while fleeing -> avoid is
        //      suppressed for 2s and he commits to the shuttle waypoint THROUGH the players
        //      (the pathfinder routes around bodies; reads as a desperate juke past you).
        //   2. The avoid fan is FULL-CIRCLE (0/+-75/+-130/180 deg) at full range, then
        //      retried at short range (160u hop) - a deep corner always has SOME bearing.
        //   3. FALLTHROUGH: if avoid still found nothing, the goal falls back to the shuttle
        //      waypoint (never an ELSE that leaves the tick goal-less - the old freeze hole).
        if ( !isdefined( self.acc_sci_breakout_until ) ) self.acc_sci_breakout_until = 0;   // BEFORE the stuck block (it reads this)
        if ( !isdefined( self.acc_sci_stuck_org ) || ( GetTime() - self.acc_sci_stuck_t ) > 3000 )
        {
            if ( isdefined( self.acc_sci_stuck_org )
                 && Distance( self.origin, self.acc_sci_stuck_org ) < 40
                 && GetTime() > self.acc_sci_breakout_until )
            {
                self.acc_sci_breakout_until = GetTime() + 2000;
                sci_log( "flee: CORNERED (moved <40u in 3s) - breaking out past players for 2s" );
            }
            self.acc_sci_stuck_org = self.origin;
            self.acc_sci_stuck_t   = GetTime();
        }
        breaking_out = ( GetTime() < self.acc_sci_breakout_until );

        near = nearest_player( self.origin );
        goalpos = undefined;
        if ( !breaking_out && isdefined( near ) && Distance( self.origin, near.origin ) < 220 )
        {
            // AVOID: bend away (inverse-distance-weighted from ALL players).
            away = ( 0, 0, 0 );
            players = GetPlayers();
            for ( pi = 0; pi < players.size; pi++ )
            {
                p = players[ pi ];
                if ( !zm_utility::is_player_valid( p ) ) continue;
                pd = Distance( self.origin, p.origin );
                if ( pd < 1 ) pd = 1;
                away += VectorNormalize( self.origin - p.origin ) * ( 1000.0 / pd );
            }
            if ( LengthSquared( away ) < 0.01 )
                away = self.origin - near.origin;
            away = VectorNormalize( away );
            dist = getdvarint( "acc_scientist_flee_dist", ACC_SCI_FLEE_DIST_DEF );
            yaw  = VectorToAngles( away )[ 1 ];
            offs = [];
            offs[ 0 ] = 0; offs[ 1 ] = 75; offs[ 2 ] = -75; offs[ 3 ] = 130; offs[ 4 ] = -130; offs[ 5 ] = 180;
            for ( i = 0; i < offs.size && !isdefined( goalpos ); i++ )
            {
                dir = AnglesToForward( ( 0, yaw + offs[ i ], 0 ) );
                goalpos = GetClosestPointOnNavMesh( self.origin + ( dir[ 0 ] * dist, dir[ 1 ] * dist, 0 ), 120, 40 );
                if ( !isdefined( goalpos ) )   // short-hop retry: deep corners reject long projections
                    goalpos = GetClosestPointOnNavMesh( self.origin + ( dir[ 0 ] * 160, dir[ 1 ] * 160, 0 ), 120, 40 );
            }
        }
        if ( !isdefined( goalpos ) && isdefined( wp ) )
            goalpos = GetClosestPointOnNavMesh( wp, 150, 60 );   // the shuttle leg / breakout commit

        if ( isdefined( goalpos ) )
        {
            self.v_zombie_custom_goal_pos = goalpos;
            self SetGoal( goalpos );
            self.acc_sci_written_goal = goalpos;   // hijack-detector reference
        }
        else if ( IS_TRUE( level.acc_dev ) )
        {
            sci_log( "flee: no nav goal this tick (wp=" + self.acc_sci_wp + ")" );
        }

        // (The 3s warp cackle REMOVED 2026-07-18 - it was warp.wav DNA and read as teleport
        // attempts. The constant numbers hum rides him everywhere; that IS his voice.)

        // Escape countdown markers (once each at ~30s and ~10s remaining).
        remain = int( ( escape_at - GetTime() ) / 1000 );
        if ( !IS_TRUE( self.acc_sci_warned30 ) && remain <= 30 ) { self.acc_sci_warned30 = true; sci_log( "flee: 30s until escape" ); }
        if ( !IS_TRUE( self.acc_sci_warned10 ) && remain <= 10 ) { self.acc_sci_warned10 = true; sci_log( "flee: 10s until escape" ); }
    }

    // ESCAPED: the gun is GONE FOREVER (user 2026-07-17 "If you dont kill him within the
    // time he will steal the gun forever" - supersedes the earlier hostage-return design).
    // The announce makes the loss legible punishment, not a silent bug.
    if ( isdefined( self.acc_sci_loot ) )
    {
        remove_pending( self.acc_sci_loot );   // the level mirror must not resurrect an escaped gun
        announce( "^1" + ACC_SCI_DISPLAY_NAME + " ^7escaped. That weapon is gone for good." );
        schedule_next_spawn( "escaped" );
        self.acc_sci_loot = undefined;
    }
    acc_utility::derez_burst( self.origin, "scientist" );
    if ( isdefined( self.acc_sci_fx_org ) ) self.acc_sci_fx_org Delete();
    self.acc_sci_escaped = true;   // belt+braces: whatever Delete()'s death-notify semantics are, death_watch bails on this flag
    // Drop his bar row GRACEFULLY (state-2 hide) BEFORE the Delete - he escaped alive, so
    // the row must not play the white kill-pop (bb_pump would read the Delete as a death).
    acc_boss_nameplate::bb_release( self );
    self Delete();   // escape = no rewards for letting him go
}

function nearest_player( origin )
{
    players = GetPlayers();
    best = undefined;
    best_d = undefined;   // review 2026-07-17: 999999*999999 OVERFLOWS T7's 32-bit int (wraps
                          // negative) so `d < best_d` was never true and this ALWAYS returned
                          // undefined - every flee blink silently skipped. The isdefined idiom
                          // is the phantom's own.
    for ( i = 0; i < players.size; i++ )
    {
        if ( !zm_utility::is_player_valid( players[ i ] ) ) continue;
        d = DistanceSquared( origin, players[ i ].origin );
        if ( !isdefined( best_d ) || d < best_d ) { best_d = d; best = players[ i ]; }
    }
    return best;
}

// ---------------------------------------------------------------------------
// Death: return the carried loot, pay out, clean up
// ---------------------------------------------------------------------------

function death_watch( round_number, fx_org )
{
    self waittill( "death", attacker );

    // Same-frame corpse reap (the phantom 4p race): self can be GONE here. The old bail-out
    // would have eaten the victim's gun - the harshest possible outcome on a SUCCESSFUL kill.
    // Recover from the by-value fx_org + the level loot mirror instead (review 2026-07-17).
    if ( !isdefined( self ) )
    {
        if ( isdefined( fx_org ) ) fx_org Delete();
        // Return every mirrored loot (in the common one-carrier case = exactly his gun; with
        // multiple simultaneous carriers this over-returns in an engine-race corner we accept).
        for ( i = 0; i < level.acc_sci_pending.size; i++ )
            return_loot( level.acc_sci_pending[ i ] );
        level.acc_sci_pending = [];
        acc_utility::announce_once( "sci_down", "^2" + ACC_SCI_DISPLAY_NAME + " ^7is down." );   // once per match (user 2026-08-01); same key as the normal-death site
        schedule_next_spawn( "killed (reaped)" );
        return;
    }
    if ( IS_TRUE( self.acc_sci_escaped ) ) return;   // the ESCAPE path despawned him - no kill rewards

    drop_origin = self.origin;
    stole_this_life = ( isdefined( self.acc_sci_loot ) || IS_TRUE( self.acc_sci_fleeing ) );
    sci_log( "DEATH: carrying=" + ( isdefined( self.acc_sci_loot ) ? "y" : "n" )
             + " stole_this_life=" + ( stole_this_life ? "y" : "n" )
             + " pending=" + level.acc_sci_pending.size );

    if ( isdefined( self.acc_sci_fx_org ) ) self.acc_sci_fx_org Delete();

    // Return the carried gun (escaped guns are gone forever - user 2026-07-17, no hostage pool).
    if ( isdefined( self.acc_sci_loot ) )
    {
        remove_pending( self.acc_sci_loot );
        return_loot( self.acc_sci_loot );
    }

    // Rewards (BO1: kill = Max Ammo; kill BEFORE any steal = the Bonfire-Sale nod -> Fire Sale,
    // which acc_box_prompt already prices at 10). Plus the shared every-boss payout.
    level thread zm_powerups::specific_powerup_drop( "full_ammo", drop_origin );
    if ( !stole_this_life )
        level thread zm_powerups::specific_powerup_drop( "fire_sale", drop_origin );
    // b_skip_item TRUE (user 2026-07-17 "he should not drop an item when he dies"): no boss-item
    // pickup - the shared points/shards/bottle payout still lands, and the powerups above are his drops.
    // a_dmg = damage ledger for the leveling XP damage-share (docs/45 4a; guarded - reap race).
    a_dmg = ( isdefined( self ) ? self.acc_damage_contrib : undefined );
    acc_boss::grant_unified_boss_reward( drop_origin, true, a_dmg );

    acc_utility::derez_burst( drop_origin, "scientist" );
    acc_utility::announce_once( "sci_down", "^2" + ACC_SCI_DISPLAY_NAME + " ^7is down." );   // once per match (user 2026-08-01); same key as the reap-race site
    schedule_next_spawn( "killed" );

    if ( isdefined( self ) )
        self thread cleanup_corpse();
}

// Drop one loot struct from the level mirror (identity compare - structs are refs).
function remove_pending( loot )
{
    kept = [];
    for ( i = 0; i < level.acc_sci_pending.size; i++ )
    {
        if ( level.acc_sci_pending[ i ] != loot )
            kept[ kept.size ] = level.acc_sci_pending[ i ];
    }
    level.acc_sci_pending = kept;
}

// Give the stolen gun back with its exact ammo. Owner gone/disconnected -> the gun dies with
// him (BO1 did the same across map transitions; announcing a return to nobody is worse).
// Hardened per review 2026-07-17: dead/spectating owners get a DEFERRED regrant on respawn
// (a give now would be wiped by the respawn loadout - the riot-shield regrant idiom), and the
// give is dupe-guarded across weapon FORMS (true_base) + weapon-limit checked (raw GiveWeapon
// bypasses the 2/3-gun limit, which would desync Mule Kick accounting).
function return_loot( loot )
{
    if ( !isdefined( loot ) || !isdefined( loot.owner ) || !isdefined( loot.weapon ) ) return;
    p = loot.owner;
    if ( !isplayer( p ) ) return;

    if ( !zm_utility::is_player_valid( p ) )
    {
        sci_log( "return: owner not valid (downed/spectating) - DEFERRED to respawn" );
        p thread deferred_return( loot );   // downed-bleeding-out / spectating: regrant on respawn
        return;
    }
    sci_log( "return: giving back " + loot.weapon.name + " (clip " + loot.clip + " stock " + loot.stock + ")" );
    p give_returned_loot( loot );
}

function deferred_return( loot )   // self = the owner
{
    self endon( "disconnect" );
    level endon( "end_game" );
    self waittill( "spawned_player" );
    wait 0.5;   // let the respawn loadout settle before we add to it
    self give_returned_loot( loot );
}

function give_returned_loot( loot )   // self = the owner
{
    // Dupe-guard across FORMS: skip if any current primary shares the same true_base (he
    // re-bought the base of a stolen PaP'd gun, a Mega twin, etc. - memory variant-twin-clobber).
    stolen_base = acc_weapon_variants::true_base( loot.weapon );
    prims = self GetWeaponsListPrimaries();
    for ( i = 0; i < prims.size; i++ )
    {
        if ( acc_weapon_variants::true_base( prims[ i ] ) == stolen_base )
        {
            acc_utility::log( "scientist: return skipped - owner already carries a form of " + loot.weapon.name );
            return;
        }
    }
    // Limit-guard: raw GiveWeapon ignores the 2/3-gun limit (the armory idiom check).
    if ( prims.size >= self zm_utility::get_player_weapon_limit( self ) )
    {
        self IPrintLnBold( "^3No room for your returned weapon - it is lost." );
        return;
    }

    self GiveWeapon( loot.weapon );
    self SetWeaponAmmoClip( loot.weapon, loot.clip );
    self SetWeaponAmmoStock( loot.weapon, loot.stock );
    // Deliberately NO forced SwitchToWeapon: mid-action switches are how the box/mule bugs
    // happen (memories box-grab-defer / mulekick-stable-order). The gun lands in the inventory.
    self IPrintLnBold( "^2Your weapon is back." );
}

function cleanup_corpse()   // mirrors cleanup_phantom_corpse (acc_is_mini_boss skips _acc_corpse_cleanup)
{
    self NotSolid();
    self Ghost();
    wait( 0.05 );
    if ( isdefined( self ) )
        self Delete();
}

// SHIP respawn scheduling (user 2026-07-18): after every death/escape the next Scientist is
// owed ACC_SCI_RESPAWN_ROUNDS later (die r16 -> next r20). Dev ignores this (every round).
function schedule_next_spawn( why )
{
    r = 1;
    if ( isdefined( level.round_number ) ) r = level.round_number;
    level.acc_sci_next_round = r + getdvarint( "acc_scientist_respawn_rounds", ACC_SCI_RESPAWN_ROUNDS_DEF );
    sci_log( why + " on r" + r + " - next Scientist at r" + level.acc_sci_next_round );
}

function announce( msg )
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
            players[ i ] IPrintLnBold( msg );
    }
}

// ---------------------------------------------------------------------------
// DEV diagnostics (user 2026-07-17 "add logs to capture what he is doing...
// make sure all logs are behind dev mode"). Player IPrintLn = the proof-of-life
// channel that reliably lands in console_mp.log as [ SCRIPTER] (CLAUDE.md launch
// findings; the /# println #/ dev-block does NOT route there).
// ---------------------------------------------------------------------------

function sci_log( msg )
{
    if ( !IS_TRUE( level.acc_dev ) ) return;
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
            players[ i ] IPrintLn( "^3[SCI]^7 " + msg );
    }
}

// self = the Scientist. 3s heartbeat of everything relevant to "is he working":
// state, distance to nearest player, gait, stock-targeting + emerge status, hp.
function dev_status_loop()
{
    self endon( "death" );
    level endon( "end_game" );
    if ( !IS_TRUE( level.acc_dev ) ) return;

    last_org = self.origin;
    for ( ;; )
    {
        wait 3;
        if ( !isdefined( self ) ) return;
        state = "lurk";
        if ( IS_TRUE( self.acc_sci_fleeing ) ) state = "flee";
        d = -1;
        near = nearest_player( self.origin );
        if ( isdefined( near ) ) d = int( Distance( self.origin, near.origin ) );
        fav = "none";
        if ( isdefined( self.favoriteenemy ) ) fav = "set";   // stock BT may still set this itself; we no longer force it
        speed = "unset";
        if ( isdefined( self.zombie_move_speed ) ) speed = self.zombie_move_speed;
        g = "none";
        if ( isdefined( self.v_zombie_custom_goal_pos ) )
            g = "" + int( Distance( self.origin, self.v_zombie_custom_goal_pos ) ) + "u";
        // moved= is the GROUND TRUTH (origin delta over the 3s beat): >0 while roaming = pathing
        // works, 0 with goal set = something re-blocked the BT - the log then shows WHICH flag.
        moved = int( Distance( last_org, self.origin ) );
        last_org = self.origin;
        // GOAL-HIJACK DETECTOR: if the BT/another system rewrote v_zombie_custom_goal_pos to
        // something we did not write, hij=Y! names the contamination the user suspected.
        hij = "n";
        if ( isdefined( self.v_zombie_custom_goal_pos ) && isdefined( self.acc_sci_written_goal )
             && Distance( self.v_zombie_custom_goal_pos, self.acc_sci_written_goal ) > 1 )
            hij = "Y!";
        // Speed forensics (user 2026-07-18 "he is slower than zombies"): OUR rate vs the
        // HORDE's this round - if ours is not strictly higher, the speed pipeline is at fault.
        r5 = acc_zombie_speed::effective_round();   // rampage-aware, mirrors sprint_pin (2026-08-03)
        hr = acc_zombie_speed::rate_for_round( r5 );
        r5 += 5;
        sr = acc_zombie_speed::sprint_start_round();
        if ( r5 < sr ) r5 = sr;
        mr = acc_zombie_speed::rate_for_round( r5 );
        if ( mr < ( hr * 1.10 ) ) mr = hr * 1.10;   // mirror sprint_pin's hard floor so rate= shows the APPLIED value
        sci_log( state + " moved=" + moved + "u dist=" + d + " goal=" + g + " speed=" + speed
                 + " rate=" + mr + " horde=" + hr
                 + " chase=" + ( IS_TRUE( self.acc_sci_chasing ) ? "y" : "n" )
                 + " fav=" + fav
                 + " enemy=" + ( isdefined( self.enemy ) ? "set" : "none" )
                 + " hij=" + hij
                 + " ign=" + ( IS_TRUE( self.ignoreall ) ? "Y!" : "n" )
                 + " emerg=" + ( IS_TRUE( self.completed_emerging_into_playable_area ) ? "y" : "N!" )
                 + " grnd=" + ( IS_TRUE( self.in_the_ground ) ? "Y!" : "n" )
                 + " inlab=" + ( ( isdefined( level.acc_sci_lab_volume ) && self IsTouching( level.acc_sci_lab_volume ) ) ? "y" : "n" )
                 + " hp=" + self.health );
    }
}
