// =============================================================================
// _acc_corpse_cleanup.gsc - remove zombie corpses on death (free the AI slot).
//
// User request (2026-06-18): bodies should DISAPPEAR on death - no linger - so the
// raised concurrent cap (_acc_main ACC_AI_LIMIT = 50) can refill freely. The reason
// this matters: the stock spawn loop also gates on level.zombie_actor_limit, and
// get_current_actor_count() = live zombie-team AI + GetCorpseArray() (zombie_utility.gsc
// :2264). A merely Ghost()'d corpse is invisible but STILL COUNTS as an actor, so it
// eats a slot until the engine recycles it - which would stall spawning at a high cap.
// DELETING the body removes it from both counts immediately, so corpses never throttle
// the horde.
//
// Lever: on every zombie death we thread a per-corpse routine. NotSolid() the body NOW
// (so a fresh corpse never blocks player movement / pathing); by default also Ghost() it
// NOW (visual vanish on death); then - mirroring stock giant-cleanup
// (zm_giant_cleanup_mgr.gsc:236-241: brief wait lets death finish, then Delete) - Delete()
// it to free the actor slot. The cleanup is THREADED so the synchronous death-event
// callbacks (points / shard / item drops) all run first.
//
// Hook: zm_spawner::register_zombie_death_event_callback (self = the killed
// zombie), the same per-death dispatch _acc_points / _acc_elites use. Bosses and
// mini-bosses are SKIPPED - they run their own death sequences (e.g. Brutus
// spawns a death-anim clone then deletes himself, _NSZ\nsz_brutus.gsc::new_death).
//
// Dvar: acc_corpse_linger_sec (default 0 = vanish on death). Set > 0 to instead keep
// the body VISIBLE on the ground that many seconds before it is deleted (the old
// "bodies pile" behavior, now slot-freeing too since it ends in a Delete).
// =============================================================================

#using scripts\zm\_zm_spawner;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_CORPSE_LINGER_DEFAULT 0   // 0 = disappear + free the actor slot on death

#namespace acc_corpse_cleanup;

function init()
{
    acc_utility::log( "corpse_cleanup: init (delete on death; linger default " + ACC_CORPSE_LINGER_DEFAULT + "s)" );
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

// self = the killed zombie/corpse. De-collide NOW; by default hide on death and DELETE to
// free the actor slot; or, if acc_corpse_linger_sec > 0, keep it visible that long first.
// Threaded so it never blocks the death-event dispatch (points / shard / item drops run
// synchronously off the same callback chain BEFORE this yields).
function corpse_linger_remove()
{
    // NotSolid() immediately so the fresh corpse never blocks player movement / pathing.
    self NotSolid();

    linger = getdvarint( "acc_corpse_linger_sec", ACC_CORPSE_LINGER_DEFAULT );
    if ( linger > 0 )
    {
        // Legacy "bodies pile" mode: stay fully VISIBLE on the ground for the window.
        wait( linger );
        if ( !isdefined( self ) ) return;
    }
    else
    {
        // Default: hide on death so the body visually vanishes immediately.
        self Ghost();
    }

    // FREE THE ACTOR SLOT. Ghost() only hides - a corpse still counts toward
    // level.zombie_actor_limit (get_current_actor_count = live AI + GetCorpseArray,
    // zombie_utility.gsc:2264), which would throttle the raised ACC_AI_LIMIT. Delete()
    // removes it from the count entirely. Mirror stock giant-cleanup
    // (zm_giant_cleanup_mgr.gsc:236-241): a brief wait lets the engine finish death
    // processing (notetracks / drops), then Delete if the body is still valid. Other
    // per-death callbacks captured origin at death time, so this doesn't affect them.
    wait( 0.05 );
    if ( isdefined( self ) )
        self Delete();
}
