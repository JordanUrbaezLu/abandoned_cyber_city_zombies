// =============================================================================
// _acc_perk_doors.gsc - per-round random access to the 9 Lab perk alcoves
//
// The 9 perks live in door-gated alcoves on the Lab north wall (geometry +
// `acc_perk_door_<specialty>` script_brushmodel gates authored by
// tools/add_perk_alcoves.js). Each round, a RANDOM 3 of the 9 doors open;
// the other 6 stay closed (their machines are physically walled off, so they
// can't be bought that round). A door closing does NOT remove a perk the player
// already owns - perks are player state; the gate only blocks access to the
// machine. Which 3 open re-rolls every round.
//
// Door state = the _acc_lockdown seal idiom (VERIFIED there): OPEN =
// hide()/notsolid()/connectpaths(); CLOSED = show()/solid()/disconnectpaths().
//
// DEV: doors all open. Gated by dev_all_open() which honors `acc_perk_doors_all_open`
// and, by default, the map-wide `acc_open_map` dev flag (entry script default 1).
// A ship build launches with `acc_open_map 0`, which switches perk doors to the
// per-round random-3 rotation. Force either way with:
//   set acc_perk_doors_all_open 1   all 9 always open (dev)
//   set acc_open_map 0              enable the per-round random-3 rotation
//
// Public API:
//   init()  - set initial gate state + start the round watcher. Call ONCE from
//             acc_main::init(), next to acc_lockdown::init() (both arm an
//             acc_round_start listener before watch_round_transitions fires).
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_PERK_DOORS_OPEN_PER_ROUND   3

#namespace acc_perk_doors;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

// The 9 perk-door specialties (one acc_perk_door_<spec> gate each). Order is the
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
    s[ 8 ] = "specialty_electriccherry";
    return s;
}

function init()
{
    acc_utility::log( "perk_doors: init" );

    level.acc_perk_door_specs = get_perk_door_specs();

    // Pre-round-1 state. Dev: all open. Ship: all closed until round 1 rolls 3.
    if ( dev_all_open() )
    {
        open_all();
    }
    else
    {
        close_all();
    }

    level thread watch_rounds();
}

// DEV master switch (live each round). See header.
function dev_all_open()
{
    if ( getdvarint( "acc_perk_doors_all_open", 0 ) == 1 )
    {
        return true;
    }
    if ( getdvarint( "acc_open_map", 1 ) == 1 )
    {
        return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Gate control (mirrors _acc_lockdown seal/unseal)
// ---------------------------------------------------------------------------

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

function open_all()
{
    specs = level.acc_perk_door_specs;
    for ( i = 0; i < specs.size; i++ )
    {
        open_door( specs[ i ] );
    }
}

function close_all()
{
    specs = level.acc_perk_door_specs;
    for ( i = 0; i < specs.size; i++ )
    {
        close_door( specs[ i ] );
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

    if ( dev_all_open() )
    {
        open_all();
        return;
    }

    close_all();

    order = roll_order();
    opened = "";
    for ( i = 0; i < ACC_PERK_DOORS_OPEN_PER_ROUND && i < order.size; i++ )
    {
        open_door( order[ i ] );
        opened = opened + order[ i ] + " ";
    }

    acc_utility::log( "perk_doors: round " + round_number + " opened -> " + opened );
}

// Fisher-Yates via the project RNG wrapper (mirrors _acc_lockdown::roll_order).
function roll_order()
{
    specs = get_perk_door_specs();
    for ( i = specs.size - 1; i > 0; i-- )
    {
        j = acc_utility::acc_rand_int( i + 1 );
        tmp = specs[ i ];
        specs[ i ] = specs[ j ];
        specs[ j ] = tmp;
    }
    return specs;
}
