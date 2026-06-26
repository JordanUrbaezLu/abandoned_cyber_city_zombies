// =============================================================================
// _acc_perk_doors.gsc - per-round random access to the 10 Lab perk alcoves
//
// *** STATUS 2026-06-22 (user): the per-round random-N-of-10 ROTATION IS ON (restored). Each round a
// RANDOM 4 of the 10 Lab perk alcove doors open and the others stay walled off; the 4 re-roll every
// round (and never immediately repeat the prior round's set). Runs in BOTH normal play and the dev
// sandbox; force all open only with `set acc_perk_doors_all_open 1`. ***
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
// ALL-OPEN OVERRIDE: gated ONLY by `acc_perk_doors_all_open` (default 0) - NOT by level.acc_dev or
// acc_open_map. So the per-round rotation is the DEFAULT in BOTH normal play AND the dev sandbox (the walls
// close in dev too, by design - user 2026-06-18). Force all open with:  set acc_perk_doors_all_open 1
//
// Public API:
//   init()  - set initial gate state + start the round watcher + the no-trap enforce loop. Call ONCE from
//             acc_main::init(), next to acc_lockdown::init() (both arm an acc_round_start listener before
//             watch_rounds fires).
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_PERK_DOORS_OPEN_PER_ROUND   4   // (user 2026-06-23: 3->4, more perk access per round)

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

    // ===== RESTORED 2026-06-22 (user): per-round random-N-of-10 perk-door ROTATION IS BACK ON. =====
    // Initial state = reconcile with an empty open-set (all CLOSED in normal play; all OPEN under the dev
    // all-open dvar). watch_rounds() re-rolls a fresh set every round (apply_round). The enforce loop keeps
    // occupied alcoves open so nobody is ever sealed in (no-trap fix 2026-06-25).
    reconcile_doors();
    seal_ec_right_wall();   // permanent solid wall: seal the Electric Cherry alcove's open right side (never opened)
    level thread watch_rounds();
    level thread enforce_doors();
    // ===================================================================================================
}

// The per-round rotation is the DEFAULT now (user 2026-06-18: the walls MUST close). Force ALL open ONLY by
// explicitly setting acc_perk_doors_all_open 1 (dev/testing).
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

// Perks eligible to open this round = all 10 MINUS the set opened last round (no immediate
// repeats). Round 1 (no history) = all 10.
function candidates_excluding_last()
{
    all = get_perk_door_specs();
    last = level.acc_perk_doors_last_open;
    if ( !isdefined( last ) || last.size == 0 )
    {
        return all;
    }
    out = [];
    for ( i = 0; i < all.size; i++ )
    {
        is_last = false;
        for ( j = 0; j < last.size; j++ )
        {
            if ( all[ i ] == last[ j ] )
            {
                is_last = true;
                break;
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
        want_open = dev || ( isdefined( open_set ) && isdefined( open_set[ spec ] ) ) || alcove_occupied( spec );
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
