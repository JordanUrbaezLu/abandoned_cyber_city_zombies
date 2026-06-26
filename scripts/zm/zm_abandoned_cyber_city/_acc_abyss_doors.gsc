// =============================================================================
// _acc_abyss_doors.gsc - the abyss descent gates + the communal "Paradise" door
//
// (1) DESCENT DOORS (acc_abyss_door_1..4) = SOUL BOXES (user 2026-06-25). One upright door per descent
//     (script_brushmodel slabs from tools/gen_abyss_doors.js, standing in each stairwell's WEST entry),
//     each sealing the way to the next layer. It is NOT bought with currency - it opens when the team
//     banks souls by SLAYING the horde ON that door's layer (a soul per kill), SCALED BY LIVE PLAYER COUNT:
//     **125 souls/player for the FIRST gate** (the trench / layer 1, where everyone roams early) and **50/player
//     for each deeper gate** - i.e. 125..500 solo..4p (first), 50..200 (deeper) (user 2026-06-25). Each death
//     credits the one door that gates the layer the zombie died on (`acc_bus_trench::underground_layer`), so
//     the gates fill sequentially as you fight your way down. Dvars `acc_soul_door_cost_first` (125/player)
//     + `acc_soul_door_cost` (50/player, the rest).
//
// (2) PARADISE DOOR (acc_abyss_hub_door) - the COMMUNAL gate at the bottom (L5) into PARADISE (the
//     open-air plaza hub; geometry: gen_descent_hub.js). This one KEEPS currency (user 2026-06-25):
//     100 Data Shards + 100,000 points, paid into two SEPARATE shared pools - any player holds [activate]
//     to dump ALL they carry of both (each capped to its pool), so the pools draw down separately. Once
//     BOTH hit 0, ALL living players must GATHER within a generous radius, then it opens for everyone.
//
// Toggle = the PROVEN _acc_perk_doors mechanism: CLOSED = show/solid/disconnectpaths, OPEN =
// hide/notsolid/connectpaths (so the baked descent navmesh reconnects on open). Script-spawned triggers
// need TriggerIgnoreTeam(). Souls hook = zm_spawner::register_zombie_death_event_callback. Shards API =
// _acc_data_shards; points API = zm_score (rounds up to /10; reads via player.score).
//
// Wired from _acc_main: acc_abyss_doors::init() in init().
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_lights;   // set_glow() = the proven client glow pipeline (soul orb)

#insert scripts\shared\shared.gsh;

#define ACC_ABYSS_DOORS     4
#define ACC_SOUL_DOOR_COST_FIRST  125   // souls PER PLAYER to open the FIRST descent gate (trench / layer 1) -
                                        // higher because everyone roams the trench early. x player count =
                                        // 125 solo .. 500 at a full 4-player lobby (user 2026-06-25).
#define ACC_SOUL_DOOR_COST        50    // souls PER PLAYER to open each DEEPER descent gate (layers 2+); 50 solo .. 200 at 4p.

// Moving "soul light" (user 2026-06-25): a glowing orb that flies from each soul-banking kill INTO the box.
#define ACC_SOUL_TRAVEL_DEF  0.8     // seconds for a soul to fly from the kill spot to the box
#define ACC_SOUL_GLOW_INDEX  6       // accPerkGlow colour index for the orb (6 = blue; _acc_perk_lights palette)
#define ACC_SOUL_FX_MAX      14      // max concurrent soul orbs (caps a mass-wipe FX swarm)

// PARADISE door costs (two independent pools) + the gather geometry. The slab fills the L5 south doorway
// band y[1703,1723] at z[-1200,-1000]; players approach + gather from the L5 floor (north).
#define ACC_HUB_DOOR_SHARDS   100
#define ACC_HUB_DOOR_POINTS   100000
#define ACC_HUB_APPROACH_Y    1745     // contribute trigger sits just NORTH of the door, on the L5 floor
#define ACC_HUB_GATHER_Y      1740     // gather centre (door front, L5 side)
#define ACC_HUB_FLOOR_Z       -1200    // L5 floor
#define ACC_HUB_GATHER_RADIUS 256      // "decent size radius" (user) all survivors must be inside

#namespace acc_abyss_doors;

// Souls to open a descent gate, BY LAYER and SCALED BY LIVE PLAYER COUNT. The FIRST gate (layer 1 / trench)
// costs more per player (everyone roams there early); deeper gates cost less. The per-player base (dvars
// below) is multiplied by GetPlayers().size, so a gate needs e.g. 125 souls solo and 500 at a full 4-player
// lobby (first gate); 50 / 200 (deeper). Evaluated LIVE: the per-kill bank check always uses the CURRENT
// count, so the gate auto-rescales if a player dis/connects mid-grind. (The floating hint is set once at
// door creation - after all players have loaded - so it reads the starting count; the live check is the
// source of truth if that later drifts.) Dev = a cheap flat value (no scaling) so the mechanic is quick to test.
function souls_needed( layer )
{
    if ( IS_TRUE( level.acc_dev ) ) return getdvarint( "acc_soul_door_cost", 10 );

    n = GetPlayers().size;
    if ( n < 1 ) n = 1;
    if ( isdefined( layer ) && layer == 1 )
        return getdvarint( "acc_soul_door_cost_first", ACC_SOUL_DOOR_COST_FIRST ) * n;
    return getdvarint( "acc_soul_door_cost", ACC_SOUL_DOOR_COST ) * n;
}

// Info-trigger origin: stands by the door in the well's WEST entry (x ~ -112). Centered on the well's Y,
// floor z drops 240/layer. (Soul boxes have no purchase - this trigger just shows the running count.)
function door_trigger_origin( k )
{
    floorz = -240 - ( k - 1 ) * 240;
    if ( k % 2 == 1 )                       // XS south well y[1723,1851] -> Y-center 1787
        return ( -136, 1787, floorz + 40 );
    return ( -136, 2109, floorz + 40 );     // XN north well y[2045,2173] -> Y-center 2109
}

function init()
{
    acc_utility::log( "abyss doors: init (" + ACC_ABYSS_DOORS + " SOUL-BOX descent gates + Paradise door)" );
    // VERIFIED(acc): per-death hook, self = the killed zombie (precedent _acc_points/_acc_elites).
    zm_spawner::register_zombie_death_event_callback( &on_zombie_death_souls );
    level thread setup_doors();
    level thread setup_hub_door();
}

// ---------------------------------------------------------------------------
// Descent gates = SOUL BOXES
// ---------------------------------------------------------------------------

function setup_doors()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    level.acc_soul_doors = [];

    for ( k = 1; k <= ACC_ABYSS_DOORS; k++ )
    {
        door = GetEnt( "acc_abyss_door_" + k, "targetname" );
        if ( !isdefined( door ) )
        {
            acc_utility::log( "abyss doors: acc_abyss_door_" + k + " MISSING - regen the .map (tools/gen_abyss_doors.js)" );
            continue;
        }

        // Start CLOSED (seal the descent). The brush bakes solid; assert the nav cut so zombies
        // can't path down before the souls are banked.
        door show();
        door solid();
        door disconnectpaths();
        door.acc_open  = false;
        door.acc_layer = k;        // the layer this door gates FROM - a kill on layer k banks a soul here
        door.acc_souls = 0;

        // NOTE: dev mode keeps these as REAL soul boxes (cheap via souls_needed) so the mechanic is
        // testable, NOT auto-open. Only the Paradise gate (setup_hub_door) auto-opens in dev.

        // Info trigger by the door (no purchase; just shows the soul count climbing).
        t = spawn( "trigger_radius_use", door_trigger_origin( k ), 0, 110, 90 );
        t TriggerIgnoreTeam();
        t SetCursorHint( "HINT_NOICON" );
        door.acc_soul_trigger = t;
        soul_update_hint( door );

        level.acc_soul_doors[ level.acc_soul_doors.size ] = door;
    }
}

// CONSTANT hint - shows the FIXED goal, NEVER the live door.acc_souls counter. THE round-~18 crash:
// the "triggerstring" BG-cache caps at 250 UNIQUE strings per match and every distinct string ever
// passed to SetHintString burns one PERMANENT slot (never freed). The old hint embedded door.acc_souls
// and was re-set on EVERY soul-banking kill, minting a brand-new string per soul (0..souls_needed() =
// up to 500 PER layer door, x multiple layers) - it overflowed the cache mid-match
// (BG_Cache_GetIndexInternal - Exceeded '250' items for type 'triggerstring'). This is structurally the
// same bug as the Paradise-gate hint (hub_set_hint) but PER-KILL, so it burns slots far faster - exactly
// what surfaced while grinding souls underground to test the descent. Live progress is shown cache-free
// via the IPrintLnBold milestone in on_zombie_death_souls (chat prints are NOT triggerstrings). Set ONCE
// at trigger creation; do NOT re-call per kill. Rule: never interpolate an unbounded runtime value into a
// SetHintString literal. Memory: triggerstring-cap-hint-strings.
function soul_update_hint( door )
{
    if ( !isdefined( door.acc_soul_trigger ) ) return;
    door.acc_soul_trigger SetHintString( "^5SOUL BOX^7  -  slay the horde here to open the descent to Layer " +
        ( door.acc_layer + 1 ) + "  ^2[bank " + souls_needed( door.acc_layer ) + " souls]" );
}

// Per zombie death (self = the killed zombie). Bank one soul to the (single) descent gate whose layer the
// zombie died on; open it at the threshold. Cheap: one underground_layer() + a tiny loop per death.
function on_zombie_death_souls( attacker )
{
    if ( !isdefined( self ) || !isdefined( level.acc_soul_doors ) ) return;

    layer = acc_bus_trench::underground_layer( self.origin );
    if ( layer <= 0 ) return;                                  // died on the surface - no gate

    need = souls_needed( layer );
    foreach ( door in level.acc_soul_doors )
    {
        if ( !isdefined( door ) || IS_TRUE( door.acc_open ) ) continue;
        if ( door.acc_layer != layer ) continue;               // each death feeds at most one gate

        door.acc_souls++;
        // Soul-steal SFX at the spot the zombie died (user 2026-06-25), every kill that banks a soul.
        // PlaySoundAtPosition is an engine builtin (stock _globallogic.gsc:4069) - plays at a WORLD point,
        // independent of the dying actor (which corpse-cleanup deletes ~immediately). acc_soul_steal = 3D
        // NONLOOPING alias (sound/aliases/acc_audio.csv -> acc\fx\soul_steal.wav, 48k mono).
        PlaySoundAtPosition( "acc_soul_steal", self.origin );
        // A glowing soul flies from the kill INTO this box (user 2026-06-25). Capture the death origin NOW
        // (corpse-cleanup deletes the actor ~0.05s later) + the box origin, then thread the MoveTo flight.
        level thread spawn_soul_light( self.origin, door_trigger_origin( door.acc_layer ) );
        // Do NOT refresh the soul-box hint here - it is a CONSTANT now (set once at trigger creation).
        // Re-setting a live count per kill is what overflowed the 250-cap triggerstring cache. Progress
        // is shown via the cache-free IPrintLnBold milestone just below. See soul_update_hint.

        if ( door.acc_souls >= need )
            open_soul_door( door );
        else if ( ( door.acc_souls % 25 ) == 0 )
            foreach ( p in GetPlayers() )
                if ( isdefined( p ) ) p IPrintLnBold( "^5Souls ^7" + door.acc_souls + " / " + need + "  (Layer " + ( door.acc_layer + 1 ) + " descent)" );
        return;
    }
}

// A glowing "soul" that flies from the kill spot INTO the soul box (user 2026-06-25). Reuses the PROVEN client
// glow pipeline: acc_perk_lights::set_glow() sets the accPerkGlow clientfield on a scriptmover, and
// _acc_perk_lights.csc renders the FX client-side (server-side PlayFX does NOT render in this build - that's
// the whole reason that pipeline exists, see _acc_perk_lights.gsc:6-15). The orb is an INVISIBLE "tag_origin"
// script_model (no mesh, just the glow) flown via the stock MoveTo + "movedone" primitive. Threaded per
// banking kill; capped so a mass wipe can't spawn a swarm of FX hosts. from = death origin (captured live in
// the callback before the corpse is deleted), to = this door's soul-box origin.
function spawn_soul_light( from, to )
{
    level endon( "end_game" );

    if ( getdvarint( "acc_soul_fx", 1 ) != 1 ) return;     // master toggle for the visual
    // Concurrent-orb cap: a nuke can wipe a whole layer at once - the soul still banks + the departure SFX
    // already played; only the VISUAL is throttled here.
    if ( !isdefined( level.acc_soul_fx_active ) ) level.acc_soul_fx_active = 0;
    if ( level.acc_soul_fx_active >= getdvarint( "acc_soul_fx_max", ACC_SOUL_FX_MAX ) ) return;
    level.acc_soul_fx_active++;

    // Fresh invisible host at ~chest height (NEVER ride the corpse - it's deleted ~0.05s after death).
    host = spawn( "script_model", from + ( 0, 0, 32 ) );
    host setmodel( "tag_origin" );                         // no visible mesh; the glow rides tag_origin
    host acc_perk_lights::set_glow( host, getdvarint( "acc_soul_glow_index", ACC_SOUL_GLOW_INDEX ) );

    // Streak to the box. Land AT the door origin with NO upward offset: the glow FX carries a built-in ~25u
    // LIFT_Z (it was tuned to ride UP a perk-machine cabinet), so a host at the trigger z (floorZ+40) renders
    // the visible glow at ~floorZ+65 = the 128-tall door's vertical MIDDLE. The old +30 here pushed the
    // visible glow to ~floorZ+95 = the door's TOP (user 2026-06-25: "make it go towards the middle").
    // waittill_notify_or_timeout guarantees we never orphan a soul if "movedone" is ever missed.
    travel = getdvarfloat( "acc_soul_travel_time", ACC_SOUL_TRAVEL_DEF );
    host MoveTo( to, travel );
    host util::waittill_notify_or_timeout( "movedone", travel + 1.0 );

    if ( isdefined( host ) )
    {
        host acc_perk_lights::set_glow( host, 0 );          // stop the glow FX (zero the field BEFORE delete = leak-safe)
        if ( getdvarint( "acc_soul_arrive_sfx", 1 ) == 1 )
            PlaySoundAtPosition( "acc_soul_steal", to );    // the soul whooshes INTO the box
        wait 0.05;                                          // let the clientfield=0 (StopFX) network before delete
        if ( isdefined( host ) ) host Delete();
    }
    level.acc_soul_fx_active--;
}

function open_soul_door( door )
{
    door hide();
    door notsolid();
    door connectpaths();           // reconnect the descent navmesh (players AND zombies)
    door.acc_open = true;

    foreach ( p in GetPlayers() )
    {
        if ( !isdefined( p ) ) continue;
        p IPrintLnBold( "^5The souls are paid ^7- Descent open to Layer " + ( door.acc_layer + 1 ) );
        p PlaySound( "zmb_cha_ching" );
    }

    if ( isdefined( door.acc_soul_trigger ) )
    {
        door.acc_soul_trigger delete();
        door.acc_soul_trigger = undefined;
    }
}

// ---------------------------------------------------------------------------
// PARADISE door - the communal money+shards gate into the plaza hub.
// ---------------------------------------------------------------------------

function setup_hub_door()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    door = GetEnt( "acc_abyss_hub_door", "targetname" );
    if ( !isdefined( door ) )
    {
        acc_utility::log( "abyss doors: acc_abyss_hub_door MISSING - regen the .map (tools/gen_descent_hub.js)" );
        return;
    }

    door show();
    door solid();
    door disconnectpaths();
    door.acc_open = false;

    // Two SEPARATE shared pools (dvar-tunable). The door opens (after the gather) only when BOTH reach 0.
    // Dev keeps the gate a REAL currency gate (NOT auto-open) so it is testable - just cheaper: 10 shards +
    // 10k points instead of 100 + 100k (user 2026-06-25).
    level.acc_hub_shards_rem = getdvarint( "acc_hub_door_shards", ( IS_TRUE( level.acc_dev ) ? 10 : ACC_HUB_DOOR_SHARDS ) );
    level.acc_hub_points_rem = getdvarint( "acc_hub_door_points", ( IS_TRUE( level.acc_dev ) ? 10000 : ACC_HUB_DOOR_POINTS ) );

    // Snapshot the FIXED totals so the gate hint can be a CONSTANT string. The engine caps the
    // "triggerstring" BG-cache at 250 UNIQUE strings (BG_Cache_GetIndexInternal); every distinct
    // string ever passed to SetHintString burns one slot for the whole match. The old hint embedded
    // the LIVE remaining (points = "all you carry", an arbitrary number) and was re-set on every
    // deposit, so it minted a NEW unique string per deposit until the cache overflowed and the game
    // hard-errored mid-session. Showing the fixed TOTAL keeps the price on-screen as ONE cached
    // string forever; live progress is announced via IPrintLnBold below (chat prints do NOT use the
    // triggerstring cache). Rule for future hints: never interpolate an unbounded runtime value into
    // a SetHintString literal (memory triggerstring-cap-hint-strings).
    level.acc_hub_shards_total = level.acc_hub_shards_rem;
    level.acc_hub_points_total = level.acc_hub_points_rem;

    level thread hub_door_loop( door );
}

function hub_paid()
{
    return ( level.acc_hub_shards_rem <= 0 && level.acc_hub_points_rem <= 0 );
}

function hub_set_hint( t )
{
    if ( hub_paid() )
    {
        t SetHintString( "^5All survivors must gather here to enter PARADISE" );
        return;
    }
    // CONSTANT string (uses the snapshotted TOTALS, not the live remaining) so it never grows the
    // triggerstring cache - see the cap note in spawn/setup above. Remaining progress is announced
    // on each deposit via IPrintLnBold (not a triggerstring).
    t SetHintString( "Hold ^3[{+activate}]^7  Open the gate to PARADISE  ^2[" + level.acc_hub_shards_total +
                     " Shards ^7+ ^2" + level.acc_hub_points_total + " Points total^7]  ^3(adds all you carry)" );
}

function hub_door_loop( door )
{
    level endon( "end_game" );

    org = ( 0, ACC_HUB_APPROACH_Y, ACC_HUB_FLOOR_Z + 40 );
    t = spawn( "trigger_radius_use", org, 0, 110, 90 );
    t TriggerIgnoreTeam();
    t SetCursorHint( "HINT_NOICON" );
    hub_set_hint( t );

    for ( ;; )
    {
        t waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) ) continue;
        if ( IS_TRUE( door.acc_open ) ) break;

        if ( hub_paid() )
        {
            player acc_utility::hud_msg( "All survivors must gather at the gate" );
            continue;
        }

        // Contribute ALL the player carries of BOTH currencies, each capped to its remaining pool
        // (so the two pools draw down separately - user 2026-06-24).
        contributed = false;

        have_s = acc_data_shards::get_count( player );
        give_s = ( have_s < level.acc_hub_shards_rem ? have_s : level.acc_hub_shards_rem );
        if ( give_s > 0 && acc_data_shards::try_spend( player, give_s ) )
        {
            level.acc_hub_shards_rem -= give_s;
            contributed = true;
        }

        have_p = ( isdefined( player.score ) ? player.score : 0 );
        give_p = ( have_p < level.acc_hub_points_rem ? have_p : level.acc_hub_points_rem );
        if ( give_p > 0 )
        {
            player zm_score::minus_to_player_score( give_p );
            level.acc_hub_points_rem -= give_p;
            contributed = true;
        }

        if ( !contributed )
        {
            player PlaySound( "zmb_no_purchase" );
            player acc_utility::hud_msg( "Nothing to contribute" );
            continue;
        }

        player PlaySound( "zmb_cha_ching" );
        hub_set_hint( t );

        foreach ( p in GetPlayers() )
        {
            if ( isdefined( p ) )
                p IPrintLnBold( "^5" + player.name + "^7 paid toward PARADISE  -  ^2" + level.acc_hub_shards_rem +
                                " Shards ^7+ ^2" + level.acc_hub_points_rem + " Points^7 left" );
        }

        if ( hub_paid() )
        {
            hub_set_hint( t );
            foreach ( p in GetPlayers() )
                if ( isdefined( p ) ) p IPrintLnBold( "^5The gate is paid ^7- gather all survivors to enter PARADISE" );
            level thread hub_gather_watch( door, t );
        }
    }
}

// Once funded, poll until EVERY living (non-downed) player is within the gather radius, then open the door
// for everyone. Downed/spectating players are ignored (they can't walk there); if nobody is alive it waits.
function hub_gather_watch( door, t )
{
    level endon( "end_game" );

    center = ( 0, ACC_HUB_GATHER_Y, ACC_HUB_FLOOR_Z );
    radius = getdvarint( "acc_hub_gather_radius", ACC_HUB_GATHER_RADIUS );

    for ( ;; )
    {
        wait 0.25;
        if ( IS_TRUE( door.acc_open ) ) return;

        all_near = true;
        any_alive = false;
        foreach ( p in GetPlayers() )
        {
            if ( !zm_utility::is_player_valid( p ) ) continue;   // skip downed/spectator
            any_alive = true;
            if ( Distance( p.origin, center ) > radius )
            {
                all_near = false;
                break;
            }
        }

        if ( any_alive && all_near )
        {
            door hide();
            door notsolid();
            door connectpaths();
            door.acc_open = true;

            // Arm the PARADISE FINAL ONSLAUGHT (_acc_paradise.gsc): the timed 5-min survival fight + WIN
            // condition starts once the team drops into paradise (user 2026-06-25).
            level.acc_paradise_open = true;
            level notify( "acc_paradise_open" );

            foreach ( p in GetPlayers() )
                if ( isdefined( p ) ) p IPrintLnBold( "^5Welcome to PARADISE" );

            if ( isdefined( t ) ) t delete();
            return;
        }
    }
}
