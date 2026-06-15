// =============================================================================
// _acc_corpse_cleanup.gsc - hold zombie corpses on the ground for a fixed time
// after death, then hide + de-collide them.
//
// User request (2026-06-15): dead zombies were vanishing the instant they were
// killed (the old behavior here was an immediate Ghost()+NotSolid() on the death
// event). They should now LINGER for ~5 seconds before disappearing so kills
// read on-screen and bodies pile believably.
//
// Lever: on every zombie death we thread a per-corpse timer. We NotSolid() the body
// IMMEDIATELY (drops physics collision so the fresh corpse never blocks player movement /
// pathing - that was the real problem with bodies hanging around), then after the linger
// window we Ghost() it (invisible + stops bullet collision, fr.gsc:816) and leave it for the
// engine's normal corpse recycling to free. The body stays fully VISIBLE during the window
// (you just walk through it); under heavy load the engine's own corpse cap can still recycle a
// body before the timer elapses - the timer is an upper bound on how long WE keep it, not a
// guarantee against engine culling.
//
// Hook: zm_spawner::register_zombie_death_event_callback (self = the killed
// zombie), the same per-death dispatch _acc_points / _acc_elites use. Bosses and
// mini-bosses are SKIPPED - they run their own death sequences (e.g. Brutus
// spawns a death-anim clone then deletes himself, _NSZ\nsz_brutus.gsc::new_death).
//
// Dvar: acc_corpse_linger_sec (default 5) - seconds a corpse stays before we
// remove it. Set 0 to restore the old instant-removal behavior.
// =============================================================================

#using scripts\zm\_zm_spawner;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#namespace acc_corpse_cleanup;

#define ACC_CORPSE_LINGER_DEFAULT 5

function init()
{
    acc_utility::log( "corpse_cleanup: init (corpses linger " + ACC_CORPSE_LINGER_DEFAULT + "s)" );
    zm_spawner::register_zombie_death_event_callback( &on_zombie_death_cleanup );
}

// self = the killed zombie. Runs once per zombie death.
function on_zombie_death_cleanup( attacker )
{
    if ( !isdefined( self ) ) return;

    // Leave bosses / mini-bosses alone - they own their death visuals.
    if ( isdefined( self.acc_is_boss ) || isdefined( self.acc_is_mini_boss ) ) return;

    self thread corpse_linger_remove();
}

// self = the corpse. De-collide it NOW, hold it visible for the linger window, then hide it.
// Threaded so it does not block the death-event dispatch (points / shard / item drops still
// run synchronously off the same callback chain).
function corpse_linger_remove()
{
    // De-collide IMMEDIATELY: NotSolid() drops physics collision so the fresh corpse never
    // blocks player movement / pathing. The body stays fully VISIBLE through the window.
    self NotSolid();

    linger = getdvarint( "acc_corpse_linger_sec", ACC_CORPSE_LINGER_DEFAULT );
    if ( linger > 0 )
        wait( linger );

    if ( !isdefined( self ) ) return;

    // Window elapsed: Ghost() hides the body (and stops any remaining bullet collision), then
    // leave it for the engine's normal corpse recycling to free. Other per-death callbacks
    // (points, shard/item drops) captured origin at death time, so hiding now doesn't affect them.
    self Ghost();
}
