// =============================================================================
// _acc_boss_avogadro.gsc - thin driver for the vendored Avogadro AI pack
//
// The Avogadro (BO2 electric boss, Dick_Nixon port) is a custom AITYPE
// archetype_zm_avogadro: model + xanims + behavior tree + animstate machine +
// FX + sounds, installed at the Mod Tools root (gitignored via
// tools/external_assets_manifest.ps1), with the control script vendored at
// scripts/zm/zm_abandoned_cyber_city/_zm_ai_avogadro.gsc (+ .csc).
//
// Same shape as _acc_boss_brutus driving the NSZ Brutus pack: the vendored
// _zm_ai_avogadro::init() (REGISTER_SYSTEM) REGISTERS the AI (behaviors, archetype
// spawn fn, AAT immunities, clientfield) and seeds level.avogadro_spawners from the
// map's `avogadro_spawner` entity - but its native every-4-6-round cadence call
// (spawn_the_avogadro) is COMMENTED OUT in the vendored copy, so spawns come from HERE.
//
// *** ROUND-1 TEST (user 2026-06-25): force ONE Avogadro shortly after blackscreen so
// it can be validated immediately. Flip acc_avo_test 0 (or remove the thread) for the
// real cadence later; the real boss cadence will be wired through _acc_boss like Brutus. ***
//
// Requires the map to contain an `avogadro_spawner` actor_spawner + at least one
// `avogadro_spawn_loc` script_struct (placed by tools/add_avogadro_spawn.js). Until
// those exist this no-ops cleanly (logs "no spawner").
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_zm_ai_avogadro;

#insert scripts\shared\shared.gsh;

#namespace acc_boss_avogadro;

// Threaded from the entry main() (level thread). Waits for blackscreen, then - in test
// mode - force-spawns one Avogadro. Self-guards if the spawner/spawn-loc aren't placed yet.
function init()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    if ( getdvarint( "acc_avo_test", 0 ) != 1 )   // round-1 test spawn (default OFF - Avogadro not shipping yet; the entry-script thread is also commented out)
        return;

    wait 8;   // let the AI system settle

    ensure_spawner();

    if ( !isdefined( level.avogadro_spawners ) || level.avogadro_spawners.size == 0 )
    {
        acc_utility::log( "avogadro: spawner unavailable - cannot test-spawn" );
        return;
    }

    acc_utility::log( "avogadro: round-1 TEST spawn firing (acc_avo_test 1)" );
    zm_ai_avogadro::avogadro_spawn();
}

// Script-create the actor_spawner at RUNTIME (the .map actor_spawner_zm_avogadro CRASHES the Radiant
// LED bake - its aitype model isn't APE-imported so the lightmapper can't load it; a runtime-spawned
// entity is invisible to Radiant). Mirrors the pack prefab's spawner KVPs. spawn_zombie() reads the
// archetype off the classname + needs origin/script_forcespawn/count (zombie_utility.gsc:1454-1540).
// NOTE: runtime-spawning a spawner classname is the UNCERTAIN bit - if the boss never appears in-game,
// the reliable fallback is to APE-import gwm_avogadro.gdt + place the spawner in the .map (Brutus pattern).
function ensure_spawner()
{
    if ( isdefined( level.avogadro_spawners ) && level.avogadro_spawners.size > 0 )
        return;   // a .map spawner already populated it

    sp = Spawn( "actor_spawner_zm_avogadro", ( 0, 243.45, 0 ) );
    if ( !isdefined( sp ) )
    {
        acc_utility::log( "avogadro: Spawn(actor_spawner_zm_avogadro) returned undefined - needs the APE-import + .map-spawner path" );
        return;
    }
    sp.script_noteworthy = "avogadro_spawner";
    sp.script_forcespawn = 1;
    sp.count = 999;
    level.avogadro_spawners = [];
    level.avogadro_spawners[ 0 ] = sp;
    acc_utility::log( "avogadro: runtime spawner created at (0,243,0)" );
}
