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
//
// -----------------------------------------------------------------------------
// FLYING-GIB SUPPRESSION (user 2026-06-24): "bodies vanish on death but the GIBS
// (severed limbs/chunks) lie around the map - will they crash it?"
//
// First, the crash fear: those loose limbs are CLIENT-SIDE dynents - the engine
// spawns them via CreateDynEntAndLaunch on the client when a gib clientfield flips
// (scripts\shared\ai\systems\gib.csc::_GibPiece). They are NOT server entities, do
// NOT count toward level.zombie_actor_limit, and live in a FIXED engine pool that
// auto-recycles the oldest when it fills - so they cannot overflow / crash anything.
// The real crash vector (corpse ACTOR count) is the body-delete above.
//
// Still, to match this map's instant-vanish look and de-clutter the ground, we stop
// the loose limbs from spawning in the first place. The lever: set a zombie's gib
// "don't spawn flying pieces" bit (GIB_TOGGLE_GIB_MODEL_FLAG, gib.gsh:21) at spawn via
// gibserverutils::ToggleSpawnGibs(z,false). That bit PERSISTS through every later gib
// (SET_GIBBED OR-preserves it, gib.gsh:51), and the client reads it as SHOULD_SPAWN_GIBS
// == false (gib.gsh:53) - so when a limb/head is gibbed the client still swaps in the
// stump model + plays the blood-burst FX, but SKIPS the CreateDynEntAndLaunch loose-limb
// (gib.csc:280-283). Net: kills still dismember + spray, but nothing physical is left on
// the floor. Stock uses the same call on death-anim clones (gib.gsc CopyGibState), so this
// is a verified-safe use of the lever, not an invented one. Live toggle: acc_suppress_flying_gibs.
// =============================================================================

#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\callbacks_shared;

#using scripts\zm\_zm_spawner;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_CORPSE_LINGER_DEFAULT 0       // 0 = disappear + free the actor slot on death
#define ACC_SUPPRESS_FLYING_GIBS_DEFAULT 1 // 1 = no loose severed-limb chunks left on the ground

#namespace acc_corpse_cleanup;

function init()
{
    acc_utility::log( "corpse_cleanup: init (delete on death; linger default " + ACC_CORPSE_LINGER_DEFAULT +
                      "s; suppress flying gibs " + ACC_SUPPRESS_FLYING_GIBS_DEFAULT + ")" );
    zm_spawner::register_zombie_death_event_callback( &on_zombie_death_cleanup );

    // Stop loose severed-limb chunks from spawning in the first place (see header). Per spawn.
    callback::on_ai_spawned( &on_zombie_spawned_suppress_gibs );
}

// self = a freshly spawned actor. Pre-set the gib "don't spawn flying pieces" bit so a later
// dismemberment swaps the stump model + sprays blood but leaves NO loose limb on the ground.
// VERIFIED(acc): callback::on_ai_spawned dispatches with NO args ON the spawned actor
// (callbacks_shared.gsc); is_zombie() gates out dogs/bosses/specials (mirrors _acc_zombie_speed).
function on_zombie_spawned_suppress_gibs()
{
    if ( !isdefined( self ) ) return;
    if ( getdvarint( "acc_suppress_flying_gibs", ACC_SUPPRESS_FLYING_GIBS_DEFAULT ) != 1 ) return;

    // Regular zombies only. Bosses/specials already set self.no_gib (they never gib at all).
    if ( !( self zombie_utility::is_zombie() ) ) return;

    // Setting the toggle bit at spawn triggers NOTHING visible (the client gib loop starts above
    // this flag's value, gib.csc:272), so it's a pure no-op until the first real gib - which then
    // dismembers WITHOUT the loose limb. See header for the full mechanism.
    gibserverutils::ToggleSpawnGibs( self, false );
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
