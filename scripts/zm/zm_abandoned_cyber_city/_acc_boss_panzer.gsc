// =============================================================================
// _acc_boss_panzer.gsc - wrapper for the Spiki Panzer (stock-mechz archetype "mechz")
//
// The Panzer (Spiki's asset dump) is a full custom archetype: its scripts
// (scripts\zm\mechz_spiki.gsc/.csc, vendored) self-register via REGISTER_SYSTEM
// ("zm_ai_mechz") and install the "mechz" archetype behaviour + clientfields. We
// spawn it via OUR own spawner like Brutus (the pack's own decompiled spawn logic
// has lost strings), then promote it through _acc_boss in stage 2. Full audit:
// docs/research/BO3_Panzer_mechz_usermap_method.txt.
//
// STAGE 1 (this file): prove a base Panzer spawns in-game (auto-spawns on round 2).
//   Spawn = an actor_spawner_zm_castle_mechz placed with targetname
//   "mechz_genesis_spawner" + an "acc_panzer_spot" struct on the perk/lab floor.
// STAGE 2: drive it from _acc_boss as the separate every-7-from-7 boss with our
//   health bar + HP + speed + Mega-Bottle/boss-item rewards.
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\util_shared;
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#namespace acc_boss_panzer;

function init()
{
    acc_utility::log( "boss_panzer: init (Spiki Panzer, stage 1 test)" );
    level thread test_loop();
}

// Spawn the Panzer on ROUND 2 (before Brutus's r3) so it's visible for the go/no-go.
// Temporary placement while the Brutus bug is investigated separately; stage 2 will
// move the Panzer to its own every-7-from-7 cadence via _acc_boss.
function test_loop()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
        // ISOLATION (2026-06-14): gated OFF by default so it can't confound the base
        // Brutus crash hunt (it auto-spawned round 2, the round before Brutus). Set
        // dvar `acc_panzer_test 1` to re-enable the round-2 test spawn.
        if ( getdvarint( "acc_panzer_test", 0 ) != 1 ) continue;
        if ( round_number != 2 ) continue;

        wait 5; // let round 2 get going
        acc_utility::log( "PANZER spawning (round 2)" );
        spawn_one();
    }
}

// Spawn one Panzer at the lab spot via our spawner. Returns the actor (or undefined).
function spawn_one()
{
    spawners = GetEntArray( "mechz_genesis_spawner", "targetname" );
    if ( spawners.size == 0 )
    {
        acc_utility::log( "panzer: no mechz_genesis_spawner placed" );
        return undefined;
    }
    spawner = spawners[ 0 ];

    spot = struct::get( "acc_panzer_spot", "targetname" );
    org = ( isdefined( spot ) ? spot.origin : spawner.origin );

    host = zombie_utility::spawn_zombie( spawner, undefined, org );
    if ( !isdefined( host ) )
    {
        acc_utility::log( "panzer: spawn_zombie returned undefined (spawner missing script_forcespawn?)" );
        return undefined;
    }

    acc_utility::log( "panzer: spawned" );
    return host;
}
