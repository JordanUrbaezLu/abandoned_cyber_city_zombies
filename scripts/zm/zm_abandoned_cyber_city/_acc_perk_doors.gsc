// =============================================================================
// _acc_perk_doors.gsc - per-round random access to the 10 Lab perk alcoves
//
// *** STATUS 2026-06-22 (user): the per-round random-N-of-10 ROTATION IS ON (restored). Each round a
// RANDOM 4 of the 10 Lab perk alcove doors open and the others stay walled off; the 4 re-roll every
// round (and never immediately repeat the prior round's set). Runs in NORMAL play; force all open with
// `set acc_perk_doors_all_open 1`. ***
//
// *** DEV MODE 2026-07-07 (user): dev now runs the SAME per-round 4-of-10 rotation as normal play - the old
// "all 10 alcoves open in dev" auto-override was REMOVED (acc_resolve_dev_flags no longer SetDvar's
// acc_perk_doors_all_open). To test a walled-off perk in dev, BUY that closed door open with the permanent-
// unlock trigger below - dev keeps you stocked with Mega Bottles (_acc_mega_bottles::dev_unlimited_bottles).
// The manual `set acc_perk_doors_all_open 1` escape hatch still forces all open in either mode. ***
//
// *** NO-TRAP FIX 2026-06-25 (user): a player standing in an alcove at the round flip used to get SEALED
// IN when close_all() ran (the door went solid around them). Fixed: we no longer blanket-close every door.
// A reconcile pass (apply_round + a 0.25s enforce loop) only CLOSES a door whose alcove is EMPTY; if a
// player (alive OR downed) is inside that alcove the close is DEFERRED - the door stays open/passable until
// they leave, then it closes. Occupancy also force-OPENS, so even a fast-entry race can't seal anyone for
// more than one tick. See alcove_occupied()/reconcile_doors(). ***
//
// The 10 perks live in door-gated alcoves on the Lab north wall (geometry +
// `acc_perk_door_<specialty>` script_brushmodel gates authored by
// tools/add_perk_alcoves.js, later extended for the 10th perk). Each round a
// RANDOM 4 of the 10 doors open; the others stay closed (their machines are
// physically walled off, so they can't be bought that round). A door closing does
// NOT remove a perk the player already owns - perks are player state; the gate
// only blocks access to the machine. Which 4 open re-rolls every round.
//
// Door state = the _acc_lockdown seal idiom (VERIFIED there): OPEN =
// hide()/notsolid()/connectpaths(); CLOSED = show()/solid()/disconnectpaths().
//
// ALL-OPEN OVERRIDE: gated by the `acc_perk_doors_all_open` dvar (default 0). As of 2026-07-07 dev mode NO
// LONGER forces this on (dev runs the real rotation - user); it is now a pure MANUAL escape hatch for either
// mode. The per-round 4-of-10 rotation is the default everywhere; force all open by hand with:
//   set acc_perk_doors_all_open 1
//
// Public API:
//   init()  - set initial gate state + start the round watcher + the no-trap enforce loop. Call ONCE from
//             acc_main::init(), next to acc_lockdown::init() (both arm an acc_round_start listener before
//             watch_rounds fires).
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;   // try_consume_bottle / mega_hint_name (permanent-unlock buy)

#define ACC_PERK_DOORS_OPEN_PER_ROUND   4   // (user 2026-06-23: 3->4, more perk access per round)

// PERMANENT UNLOCK (user 2026-07-07): a per-alcove trigger lets a player pay Empty Mega Bottles to OPEN one
// currently-CLOSED perk door for the REST OF THE GAME. A permanently-unlocked door drops out of the per-round
// roll (candidates_excluding_last) and is force-open every reconcile (see is_permanent()), so it becomes a
// BONUS always-open alcove ON TOP of the 4 rotating ones - not one of the 4. Trigger only shows while the door
// is closed & not-yet-permanent (user: "you can only do this when it's closed").
#define ACC_PERK_DOOR_UNLOCK_COST     2    // Empty Mega Bottles per permanent unlock
#define ACC_PERK_DOOR_UNLOCK_RADIUS   60   // < half the 150u alcove pitch, so adjacent triggers never overlap
#define ACC_PERK_DOOR_UNLOCK_HEIGHT   100
#define ACC_PERK_DOOR_UNLOCK_Z        40   // trigger centre above the Lab floor (z=0), mirrors the glitch-altar trigger

// Alcove occupancy box (no-trap fix). X is per-door (alcove_x_span, read from the live .map door brushes);
// Y/Z are shared. A player whose origin falls in [door x-span] x [Y_SOUTH..Y_NORTH] x [Z_LO..Z_HI] is "inside"
// that alcove, so its door must not close. Y_SOUTH = the door's own south face (4150) so a player AT the door
// or behind it counts but a player walking the row to the south (y<4150) does not. Y_NORTH clears the Lab
// north interior wall (alcove back ~4228). Z is a deliberately generous window around the Lab floor (z=0) -
// nothing else in the map occupies this x/y, so a wide Z only ever errs toward keeping a door open (safe).
#define ACC_ALCOVE_Y_SOUTH      4150
#define ACC_ALCOVE_Y_NORTH      4232
#define ACC_ALCOVE_Z_LO         -96
#define ACC_ALCOVE_Z_HI         256
#define ACC_PERK_DOORS_ENFORCE_WAIT  0.25

#namespace acc_perk_doors;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

// The 10 perk-door specialties (one acc_perk_door_<spec> gate each). Order is the
// Lab row left-to-right; the per-round roll shuffles a copy, so order is cosmetic.
function get_perk_door_specs()
{
    s = [];
    s[ 0 ] = "specialty_quickrevive";
    s[ 1 ] = "specialty_armorvest";
    s[ 2 ] = "specialty_fastreload";
    s[ 3 ] = "specialty_doubletap2";
    s[ 4 ] = "specialty_staminup";
    s[ 5 ] = "specialty_additionalprimaryweapon";
    s[ 6 ] = "specialty_deadshot";
    s[ 7 ] = "specialty_widowswine";
    s[ 8 ] = "specialty_electriccherry";        // PhD Flopper (hijacks this pipeline)
    s[ 9 ] = "specialty_combat_efficiency";      // Electric Cherry (real 10th perk, _acc_perk_electric_cherry; gate acc_perk_door_specialty_combat_efficiency)
    return s;
}

function init()
{
    acc_utility::log( "perk_doors: init" );

    level.acc_perk_door_specs = get_perk_door_specs();
    level.acc_perk_door_state = [];        // spec -> "open"/"closed" (actual gate state; reconcile transitions only on change)
    level.acc_perk_doors_open_set = [];    // spec -> true = selected open THIS round (none until round 1 rolls)
    level.acc_perk_doors_permanent = [];   // spec -> true = bought open for the rest of the game (out of the roll, always force-open)

    // ===== RESTORED 2026-06-22 (user): per-round random-N-of-10 perk-door ROTATION IS BACK ON. =====
    // Initial state = reconcile with an empty open-set (all CLOSED in normal play; all OPEN under the dev
    // all-open dvar). watch_rounds() re-rolls a fresh set every round (apply_round). The enforce loop keeps
    // occupied alcoves open so nobody is ever sealed in (no-trap fix 2026-06-25).
    reconcile_doors();
    seal_ec_right_wall();   // permanent solid wall: seal the Electric Cherry alcove's open right side (never opened)
    level thread watch_rounds();
    level thread enforce_doors();
    level thread spawn_unlock_triggers();   // per-alcove "pay 2 Mega Bottles to open forever" buy triggers (user 2026-07-07)
    // ===================================================================================================
}

// All-open ONLY when the manual acc_perk_doors_all_open dvar == 1. As of 2026-07-07 dev mode does NOT set this
// (dev runs the real per-round rotation, same as normal play - user); it's a hand-set escape hatch for either
// mode. Name kept for history - it no longer implies "dev".
function dev_all_open()
{
    return ( getdvarint( "acc_perk_doors_all_open", 0 ) == 1 );
}

// ---------------------------------------------------------------------------
// Gate control (mirrors _acc_lockdown seal/unseal)
// ---------------------------------------------------------------------------

// Permanent solid wall sealing the OPEN right side of the Electric Cherry alcove. The rightmost stall
// has no end-cap partition (the row's end caps were dropped to keep the LED bake clean), so a player
// could flank EC's closed door (user 2026-06-25: "there is no wall on right side of electric cherry...
// add one"). The wall is a script_brushmodel (acc_ec_right_wall, in the .map) - a brushmodel, NOT world
// geometry, so the lightmapper ignores it (a world brush in that thin nook hung the bake). We force it
// solid+visible+path-blocking ONCE here and never open it.
function seal_ec_right_wall()
{
    wall = getent( "acc_ec_right_wall", "targetname" );
    if ( !isdefined( wall ) )
    {
        acc_utility::log( "perk_doors: acc_ec_right_wall not found (EC alcove right side NOT sealed)" );
        return;
    }
    wall show();
    wall solid();
    wall disconnectpaths();
}

function open_door( spec )
{
    doors = getentarray( "acc_perk_door_" + spec, "targetname" );
    for ( i = 0; i < doors.size; i++ )
    {
        doors[ i ] hide();
        doors[ i ] notsolid();
        doors[ i ] connectpaths();
    }
}

function close_door( spec )
{
    doors = getentarray( "acc_perk_door_" + spec, "targetname" );
    for ( i = 0; i < doors.size; i++ )
    {
        doors[ i ] show();
        doors[ i ] solid();
        doors[ i ] disconnectpaths();
    }
}

// ---------------------------------------------------------------------------
// Per-round rotation
// ---------------------------------------------------------------------------

function watch_rounds()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
        level thread apply_round( round_number );
    }
}

function apply_round( round_number )
{
    level endon( "end_game" );

    // Roll N NEW perks from the ones NOT open last round (user 2026-06-18: no immediate repeats). We only set
    // the intended open-set here; reconcile_doors() applies it WITHOUT sealing anyone in (occupied alcoves
    // stay open until empty - no-trap fix). dev_all_open is handled inside reconcile_doors().
    order = roll_order( candidates_excluding_last() );
    open_set = [];
    opened = [];
    opened_str = "";
    for ( i = 0; i < ACC_PERK_DOORS_OPEN_PER_ROUND && i < order.size; i++ )
    {
        open_set[ order[ i ] ] = true;
        opened[ opened.size ] = order[ i ];
        opened_str = opened_str + order[ i ] + " ";
    }
    level.acc_perk_doors_open_set = open_set;
    level.acc_perk_doors_last_open = opened;   // excluded from next round's roll

    reconcile_doors();

    acc_utility::log( "perk_doors: round " + round_number + " opened -> " + opened_str );
}

// Perks eligible to open this round = all 10 MINUS the set opened last round (no immediate repeats) MINUS any
// permanently-unlocked door (user 2026-07-07: a bought-open door is removed from the roll - it is always open,
// so re-rolling it would waste a slot). Round 1 with no permanents/history = all 10.
function candidates_excluding_last()
{
    all = get_perk_door_specs();
    last = level.acc_perk_doors_last_open;
    out = [];
    for ( i = 0; i < all.size; i++ )
    {
        if ( is_permanent( all[ i ] ) )   // already open forever - never roll it
            continue;

        is_last = false;
        if ( isdefined( last ) )
        {
            for ( j = 0; j < last.size; j++ )
            {
                if ( all[ i ] == last[ j ] )
                {
                    is_last = true;
                    break;
                }
            }
        }
        if ( !is_last )
        {
            out[ out.size ] = all[ i ];
        }
    }
    return out;
}

// Fisher-Yates via the project RNG wrapper (mirrors _acc_lockdown::roll_order).
function roll_order( specs )
{
    for ( i = specs.size - 1; i > 0; i-- )
    {
        j = acc_utility::acc_rand_int( i + 1 );
        tmp = specs[ i ];
        specs[ i ] = specs[ j ];
        specs[ j ] = tmp;
    }
    return specs;
}

// ---------------------------------------------------------------------------
// No-trap reconcile (user 2026-06-25)
// ---------------------------------------------------------------------------

// Bring every door to its intended state, but NEVER close one whose alcove still has a player in it. A door
// wants to be OPEN if: dev-all-open, OR it was selected this round, OR a player is currently inside its alcove
// (defer the close). Only OPENS/CLOSES on an actual state change, so connectpaths/disconnectpaths aren't spammed.
function reconcile_doors()
{
    specs = level.acc_perk_door_specs;
    dev = dev_all_open();
    open_set = level.acc_perk_doors_open_set;

    for ( i = 0; i < specs.size; i++ )
    {
        spec = specs[ i ];
        // A door wants OPEN if: dev-all-open, OR it was bought PERMANENT, OR selected this round, OR a player
        // is currently inside its alcove (defer the close - no-trap fix).
        want_open = dev || is_permanent( spec ) || ( isdefined( open_set ) && isdefined( open_set[ spec ] ) ) || alcove_occupied( spec );
        cur = level.acc_perk_door_state[ spec ];

        if ( want_open )
        {
            if ( !isdefined( cur ) || cur != "open" )
            {
                open_door( spec );
                level.acc_perk_door_state[ spec ] = "open";
            }
        }
        else
        {
            if ( !isdefined( cur ) || cur != "closed" )
            {
                close_door( spec );
                level.acc_perk_door_state[ spec ] = "closed";
            }
        }
    }
}

// Re-run the reconcile forever so a deferred close fires the moment its alcove drains, and a fast-entry race
// can't seal anyone for more than one tick (occupancy force-reopens).
function enforce_doors()
{
    level endon( "end_game" );

    for ( ;; )
    {
        wait ACC_PERK_DOORS_ENFORCE_WAIT;
        reconcile_doors();
    }
}

// Any player (alive OR downed - a downed player must stay reachable for revives) standing in spec's alcove?
function alcove_occupied( spec )
{
    span = alcove_x_span( spec );
    if ( !isdefined( span ) )
        return false;

    x1 = span[ 0 ];
    x2 = span[ 1 ];

    foreach ( p in GetPlayers() )
    {
        if ( !isdefined( p ) || !isdefined( p.origin ) )
            continue;

        o = p.origin;
        if ( o[ 0 ] >= x1 && o[ 0 ] <= x2 &&
             o[ 1 ] >= ACC_ALCOVE_Y_SOUTH && o[ 1 ] <= ACC_ALCOVE_Y_NORTH &&
             o[ 2 ] >= ACC_ALCOVE_Z_LO && o[ 2 ] <= ACC_ALCOVE_Z_HI )
        {
            return true;
        }
    }
    return false;
}

// Per-spec alcove interior x-span (= the door brush's own x extent, read from the live .map door entities,
// which is the GROUND TRUTH - they sit at x-centers -675..675 step 150, NOT the generator's -600..600).
// Returned as a 2-component span via a vector ( x1, x2, 0 ); read [0]/[1].
function alcove_x_span( spec )
{
    switch ( spec )
    {
        case "specialty_quickrevive":             return ( -746, -604, 0 );
        case "specialty_armorvest":               return ( -596, -454, 0 );
        case "specialty_fastreload":              return ( -446, -304, 0 );
        case "specialty_doubletap2":              return ( -296, -154, 0 );
        case "specialty_staminup":                return ( -146,   -4, 0 );
        case "specialty_additionalprimaryweapon": return (    4,  146, 0 );
        case "specialty_deadshot":                return (  154,  296, 0 );
        case "specialty_widowswine":              return (  304,  446, 0 );
        case "specialty_electriccherry":          return (  454,  596, 0 );
        case "specialty_combat_efficiency":       return (  604,  746, 0 );
    }
    return undefined;
}

// ---------------------------------------------------------------------------
// Permanent unlock (user 2026-07-07): pay ACC_PERK_DOOR_UNLOCK_COST Empty Mega Bottles to open one CLOSED
// alcove for the rest of the game. It then drops out of the per-round roll and is force-open every reconcile.
//
// One trigger_radius_use per alcove, parked at the alcove's door face (x = alcove centre, y = the door's south
// face, z = chest height over the Lab floor). It shows/uses ONLY while that door is CLOSED and not-yet-permanent
// (mirrors the mega-machine SetInvisibleToPlayer visibility idiom); when the door is open via rotation - or once
// permanent - it's hidden. The buy is a LEVEL unlock (benefits the whole team) charged to the buyer's bottles.
// ---------------------------------------------------------------------------

// True once this spec's door has been bought permanently open.
function is_permanent( spec )
{
    if ( !isdefined( level.acc_perk_doors_permanent ) ) return false;
    if ( !isdefined( level.acc_perk_doors_permanent[ spec ] ) ) return false;
    return level.acc_perk_doors_permanent[ spec ] == true;
}

// True while this spec's gate is in the CLOSED (solid/walled-off) state. The buy trigger only lives while closed.
function door_is_closed( spec )
{
    return isdefined( level.acc_perk_door_state[ spec ] ) && level.acc_perk_door_state[ spec ] == "closed";
}

// Static per-perk hint (10 distinct, all bounded - never embed a live count, or it burns the permanent
// triggerstring cap; memory triggerstring-cap-hint-strings). Base perk name via the mega module's map.
function unlock_hint( spec )
{
    return "Hold ^3[{+activate}]^7  Open ^5" + acc_mega_bottles::mega_hint_name( spec ) +
           "^7 permanently for ^2" + ACC_PERK_DOOR_UNLOCK_COST + " Mega Bottles";
}

function spawn_unlock_triggers()
{
    level endon( "end_game" );

    specs = level.acc_perk_door_specs;
    for ( i = 0; i < specs.size; i++ )
        spawn_one_unlock_trigger( specs[ i ] );

    acc_utility::log( "perk_doors: " + specs.size + " permanent-unlock buy triggers spawned" );
}

function spawn_one_unlock_trigger( spec )
{
    span = alcove_x_span( spec );
    if ( !isdefined( span ) )
        return;

    cx = ( span[ 0 ] + span[ 1 ] ) / 2;
    org = ( cx, ACC_ALCOVE_Y_SOUTH, ACC_PERK_DOOR_UNLOCK_Z );

    t = Spawn( "trigger_radius_use", org, 0, ACC_PERK_DOOR_UNLOCK_RADIUS, ACC_PERK_DOOR_UNLOCK_HEIGHT );
    t.targetname = "acc_perk_door_unlock";
    t.acc_spec = spec;
    t TriggerIgnoreTeam();
    t UseTriggerRequireLookAt();
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( unlock_hint( spec ) );

    t thread unlock_trigger_visibility( spec );
    t thread unlock_trigger_think( spec );
}

// Per-player show/hide: visible ONLY while the door is closed and not-yet-permanent. Loops forever (like the
// mega machine's visibility watcher) so late-joining players are covered too. An invisible trigger is unusable,
// so this doubles as the "only while closed" access gate; the think loop re-guards for safety.
function unlock_trigger_visibility( spec )
{
    level endon( "end_game" );
    self endon( "death" );

    for ( ;; )
    {
        b_show = !is_permanent( spec ) && door_is_closed( spec );
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            if ( isdefined( players[ i ] ) )
                self SetInvisibleToPlayer( players[ i ], !b_show );
        }
        wait 0.25;
    }
}

function unlock_trigger_think( spec )
{
    level endon( "end_game" );
    self endon( "death" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) ) continue;
        if ( is_permanent( spec ) ) continue;        // already bought open
        if ( !door_is_closed( spec ) ) continue;      // user: only when it's CLOSED
        try_unlock_door( player, spec );
        wait 0.5;                                     // debounce a held use
    }
}

// Charge the buyer ACC_PERK_DOOR_UNLOCK_COST bottles and flag the door permanent for the whole team. Returns
// true on success.
function try_unlock_door( player, spec )
{
    if ( is_permanent( spec ) )
        return false;

    if ( !acc_mega_bottles::try_consume_bottle( player, ACC_PERK_DOOR_UNLOCK_COST ) )
    {
        player iprintln( "Need " + ACC_PERK_DOOR_UNLOCK_COST + " Empty Mega Bottles" );
        return false;
    }

    level.acc_perk_doors_permanent[ spec ] = true;   // out of the roll + force-open every reconcile, for good
    reconcile_doors();                                // open it right now (don't wait for the 0.25s enforce tick)

    name = acc_mega_bottles::mega_hint_name( spec );
    player PlaySound( "evt_bottle_dispense" );
    player iprintln( "^5" + name + "^7 unlocked for the rest of the game" );
    acc_utility::log( "perk_doors: " + spec + " PERMANENTLY unlocked (" + ACC_PERK_DOOR_UNLOCK_COST + " mega bottles)" );
    return true;
}
