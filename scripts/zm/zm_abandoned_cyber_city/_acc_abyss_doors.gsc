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
//     cost SCALES BY LIVE PLAYER COUNT (user 2026-06-27) - solo = 50 Data Shards + 50,000 points, +25 shards
//     + 25,000 points per EXTRA player (2p 75/75k, 3p 100/100k, 4p 125/125k; hub_cost_watcher keeps it live
//     until the first payment locks it). Paid into two SEPARATE shared pools - any player holds [activate]
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
#using scripts\zm\zm_abandoned_cyber_city\_acc_leveling;   // +1 XP per soul banked (docs/45)
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_lights;   // set_glow() = the proven client glow pipeline (soul orb)
#using scripts\zm\zm_abandoned_cyber_city\_acc_abyss_deco;    // floor_lights_on() = soul-defeat dim lamps (user 2026-07-12)

#insert scripts\shared\shared.gsh;

#define ACC_ABYSS_DOORS     4
#define ACC_SOUL_DOOR_COST_FIRST  125   // souls PER PLAYER to open the FIRST descent gate (trench / layer 1) -
                                        // higher because everyone roams the trench early. x player count =
                                        // 125 solo .. 500 at a full 4-player lobby (user 2026-06-25).
#define ACC_SOUL_DOOR_COST        50    // BASE souls PER PLAYER for the first DEEP gate (L2->L3); deeper gates add STEP.
#define ACC_SOUL_DOOR_COST_STEP   25    // per-floor INCREASE for each gate below L2 (user 2026-07-12 "make it 125,50,75,100").
                                        // Deep gate cost/player = 50 + 25*(layer-2): L2 50 / L3 75 / L4 100. All x player count.

// Moving "soul light" (user 2026-06-25): a glowing orb that flies from each soul-banking kill INTO the box.
#define ACC_SOUL_TRAVEL_DEF  0.8     // seconds for a soul to fly from the kill spot to the box
#define ACC_SOUL_GLOW_INDEX  6       // accPerkGlow colour index for the orb (6 = blue; _acc_perk_lights palette)
#define ACC_SOUL_FX_MAX      14      // max concurrent soul orbs (caps a mass-wipe FX swarm)

// PARADISE door costs (two independent pools) + the gather geometry. The slab fills the L5 south doorway
// band y[1703,1723] at z[-1200,-1000]; players approach + gather from the L5 floor (north).
// Cost SCALES BY LIVE PLAYER COUNT (user 2026-06-27): solo = the SOLO base, +PER per EXTRA player.
// 1p = 50sh/50k, 2p = 75/75k, 3p = 100/100k, 4p = 125/125k. Computed by hub_cost_shards/hub_cost_points;
// kept aligned to the live count by hub_cost_watcher until the first contribution LOCKS the price in.
#define ACC_HUB_DOOR_SHARDS_SOLO   50      // Data Shards: solo base
#define ACC_HUB_DOOR_SHARDS_PER    25      // Data Shards: + per extra player
#define ACC_HUB_DOOR_POINTS_SOLO   50000   // points: solo base
#define ACC_HUB_DOOR_POINTS_PER    25000   // points: + per extra player
#define ACC_HUB_APPROACH_Y    1745     // contribute trigger sits just NORTH of the door, on the L5 floor
#define ACC_HUB_GATHER_Y      1740     // gather centre (door front, L5 side)
#define ACC_HUB_FLOOR_Z       -1200    // L5 floor
#define ACC_HUB_GATHER_RADIUS 256      // "decent size radius" (user) all survivors must be inside

#namespace acc_abyss_doors;

// Souls to open a descent gate, BY LAYER and SCALED BY LIVE PLAYER COUNT. The FIRST gate (layer 1 / trench)
// costs more per player (everyone roams there early); deeper gates cost less. The per-player base (dvars
// below) is multiplied by GetPlayers().size, so a gate needs e.g. 125 souls solo and 500 at a full 4-player
// lobby (first gate); 50 / 200 (deeper). Evaluated LIVE: the per-kill bank check always uses the CURRENT
// count, so the gate auto-rescales if a player dis/connects mid-grind. The floating hint is RE-SYNCED to this
// live value whenever the player count changes (soul_hint_watcher), so the displayed goal always matches what
// the per-kill check requires. Dev = a cheap flat value (no scaling) so the mechanic is quick to test.
function souls_needed( layer )
{
    if ( IS_TRUE( level.acc_dev ) ) return getdvarint( "acc_soul_door_cost", 10 );

    n = GetPlayers().size;
    if ( n < 1 ) n = 1;
    if ( isdefined( layer ) && layer == 1 )
        return getdvarint( "acc_soul_door_cost_first", ACC_SOUL_DOOR_COST_FIRST ) * n;
    // DEEP gates (L2/L3/L4) ESCALATE (user 2026-07-12): base + step per floor below L2.
    // deep = layer-2 -> L2:0  L3:1  L4:2 steps. Per-player: 50 / 75 / 100 (defaults). All
    // costs auto-scale by live GetPlayers().size below (re-evaluated per soul-bank check).
    base = getdvarint( "acc_soul_door_cost", ACC_SOUL_DOOR_COST );
    step = getdvarint( "acc_soul_door_cost_step", ACC_SOUL_DOOR_COST_STEP );
    deep = 0;
    if ( isdefined( layer ) && layer > 2 ) deep = layer - 2;   // guard: undefined/L2 = 0 steps
    return ( base + step * deep ) * n;
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

    // Keep the floating goal ALIGNED with the LIVE souls_needed (which scales by player count).
    level thread soul_hint_watcher();
}

// souls_needed() scales by GetPlayers().size, but the soul-box hint is otherwise only set once at door
// creation - so in co-op (or after a dis/connect) the DISPLAYED goal could drift from the actual live bank
// requirement the per-kill check uses (user 2026-06-27: "make sure the UI matches the code"). Re-set the
// hints ONLY when the player count CHANGES: that is a tiny fixed set of strings (<=4 counts x 4 doors = 16),
// so it stays far under the 250-triggerstring cap (the per-KILL re-set is what overflowed it - never do THAT).
function soul_hint_watcher()
{
    level endon( "end_game" );
    last_n = -1;
    for ( ;; )
    {
        n = GetPlayers().size;
        if ( n != last_n )
        {
            last_n = n;
            if ( isdefined( level.acc_soul_doors ) )
                foreach ( door in level.acc_soul_doors )
                    if ( isdefined( door ) && !IS_TRUE( door.acc_open ) )
                        soul_update_hint( door );
        }
        wait 1;
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
// via the IPrintLnBold milestone in on_zombie_death_souls (chat prints are NOT triggerstrings). Set at trigger
// creation + re-synced ONLY when the player count changes (soul_hint_watcher = a tiny fixed set of strings);
// NEVER re-call per kill (that minted a string per soul = the overflow). Rule: never interpolate an UNBOUNDED
// runtime value into a SetHintString literal (a BOUNDED one - player count 1..4 - is fine). Memory: triggerstring-cap-hint-strings.
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
        if ( isdefined( attacker ) && isplayer( attacker ) )
            acc_leveling::grant_soul_xp( attacker, 1 );   // [acc] leveling: +1 XP per soul you bank (user 2026-07-22, docs/45)
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

    // No descent gate matched -> if this was an L5 (the Maw) kill, bank it to the PARADISE hub SOUL
    // phase (user 2026-07-13). Same cost as gate 4 (souls_needed(4)); unlocks the currency payment.
    if ( layer >= 5 && isdefined( level.acc_hub_souls ) && !IS_TRUE( level.acc_hub_souls_complete ) )
    {
        need_hub = souls_needed( 4 );
        level.acc_hub_souls++;
        if ( isdefined( attacker ) && isplayer( attacker ) )
            acc_leveling::grant_soul_xp( attacker, 1 );   // [acc] leveling: +1 XP per hub soul banked (user 2026-07-22, docs/45)
        PlaySoundAtPosition( "acc_soul_steal", self.origin );
        level thread spawn_soul_light( self.origin, ( 0, ACC_HUB_APPROACH_Y, ACC_HUB_FLOOR_Z + 40 ) );
        if ( level.acc_hub_souls >= need_hub )
        {
            level.acc_hub_souls_complete = true;
            if ( isdefined( level.acc_hub_trigger ) ) hub_set_hint( level.acc_hub_trigger );
            foreach ( p in GetPlayers() )
                if ( isdefined( p ) ) p IPrintLnBold( "^5The PARADISE gate is UNLOCKED ^7- now pay to open it" );
        }
        else if ( ( level.acc_hub_souls % 25 ) == 0 )
            foreach ( p in GetPlayers() )
                if ( isdefined( p ) ) p IPrintLnBold( "^5Souls ^7" + level.acc_hub_souls + " / " + need_hub + "  (PARADISE gate)" );
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

    // Soul-defeat DIM LIGHTS (user 2026-07-12): filling a floor's soul door = "you
    // defeated the floor" -> its dim wall lamps wake up. Layer 1 = the lit trench
    // (floor_lights_on ignores <2); the Paradise gate lights L5 (see the hub-open path).
    acc_abyss_deco::floor_lights_on( door.acc_layer );

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

// PARADISE-gate cost, SCALED BY LIVE PLAYER COUNT (user 2026-06-27): solo = the SOLO base, +PER per EXTRA
// player. So 50/50k solo, then +25 shards + 25k points each additional player (2p 75/75k .. 4p 125/125k).
// Mirrors souls_needed() above (which also scales by GetPlayers().size). Dev keeps the cheap fixed override
// (acc_hub_door_shards / _points, 10 / 10k) so the gate stays a REAL testable currency gate, not auto-open.
function hub_cost_shards()
{
    if ( IS_TRUE( level.acc_dev ) ) return getdvarint( "acc_hub_door_shards", 10 );
    n = GetPlayers().size;
    if ( n < 1 ) n = 1;
    return getdvarint( "acc_hub_door_shards_solo", ACC_HUB_DOOR_SHARDS_SOLO ) +
           getdvarint( "acc_hub_door_shards_per",  ACC_HUB_DOOR_SHARDS_PER ) * ( n - 1 );
}

function hub_cost_points()
{
    if ( IS_TRUE( level.acc_dev ) ) return getdvarint( "acc_hub_door_points", 10000 );
    n = GetPlayers().size;
    if ( n < 1 ) n = 1;
    return getdvarint( "acc_hub_door_points_solo", ACC_HUB_DOOR_POINTS_SOLO ) +
           getdvarint( "acc_hub_door_points_per",  ACC_HUB_DOOR_POINTS_PER ) * ( n - 1 );
}

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

    // SOUL PHASE (user 2026-07-13 "the last door needs a soul box too before you even start paying;
    // make it same as the 4th floor souls"): before ANY currency, the team banks souls on L5 = the
    // SAME cost as the L4->L5 descent gate (souls_needed(4) = 100/player, scaled live). L5 kills bank
    // via on_zombie_death_souls; the currency payment (hub_door_loop) is LOCKED until souls complete.
    // Dev keeps the cheap souls_needed override (flat 10) so it stays testable.
    level.acc_hub_souls = 0;
    level.acc_hub_souls_complete = false;

    // [acc] DOOR BEACON (user 2026-07-06: the final gate is "so hard to see people don't even know
    // it's a door"): a small glow light on the player-side door face. Same tag_origin + accPerkGlow
    // clientfield recipe as spawn_soul_light above; BLUE (6) = the descent-gate soul colour, so the
    // final gate reads as the last "pay the door" beacon. y 1727 = just off the slab's north face
    // (band y[1703,1723], players approach from +y); z floor+72 = torso height. Kept lit after the
    // door opens - it then marks the passage into Paradise.
    beacon = spawn( "script_model", ( 0, 1727, ACC_HUB_FLOOR_Z + 72 ) );
    if ( isdefined( beacon ) )
    {
        beacon setmodel( "tag_origin" );
        acc_perk_lights::set_glow( beacon, 6 );
    }

    // Two SEPARATE shared pools, cost SCALED BY LIVE PLAYER COUNT (hub_cost_*). The door opens (after the
    // gather) only when BOTH reach 0. Dev keeps the gate a REAL currency gate (NOT auto-open) so it is
    // testable - just cheaper (10 shards + 10k points, handled inside the hub_cost_* helpers).
    level.acc_hub_shards_rem = hub_cost_shards();
    level.acc_hub_points_rem = hub_cost_points();

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
    level thread hub_cost_watcher();   // keep the price aligned to the live player count until the first payment
}

function hub_paid()
{
    return ( level.acc_hub_shards_rem <= 0 && level.acc_hub_points_rem <= 0 );
}

function hub_set_hint( t )
{
    if ( !IS_TRUE( level.acc_hub_souls_complete ) )
    {
        // SOUL PHASE hint - bounded value (souls_needed(4) = 100/200/300/400 by count), so <=4
        // distinct strings = triggerstring-cache-safe (re-set by hub_cost_watcher on a count change).
        t SetHintString( "^5SOUL BOX^7  -  slay the horde here to UNLOCK the gate to PARADISE  ^2[bank " +
            souls_needed( 4 ) + " souls]" );
        return;
    }
    if ( hub_paid() )
    {
        t SetHintString( "^5All survivors must gather here to enter PARADISE" );
        return;
    }
    // CONSTANT string (uses the snapshotted TOTALS, not the live remaining) so it never grows the
    // triggerstring cache - see the cap note in spawn/setup above. Remaining progress is announced
    // on each deposit via IPrintLnBold (not a triggerstring).
    // "(adds up to N + N per use)" replaced "(adds all you carry)" (user 2026-07-06 installments).
    // Still cache-safe: chunk dvars are fixed in play, so this stays ONE constant string per price snapshot.
    t SetHintString( "Hold ^3[{+activate}]^7  Open the gate to PARADISE  ^2[" + level.acc_hub_shards_total +
                     " Shards ^7+ ^2" + level.acc_hub_points_total + " Points total^7]  ^3(adds up to " +
                     getdvarint( "acc_hub_chunk_shards", 10 ) + " Shards + " +
                     getdvarint( "acc_hub_chunk_points", 10000 ) + " Points per use)" );
}

// Keep the PARADISE-gate price ALIGNED with the LIVE player count (hub_cost_*) until the first contribution
// LOCKS it in. Re-sets totals+remaining+hint ONLY when the count changes AND nobody has paid yet (both pools
// still sit at their snapshot total) - a tiny fixed string set (<=4 player counts), far under the 250-
// triggerstring cap (mirrors soul_hint_watcher; the per-DEPOSIT re-set is what overflowed it - never do THAT).
// Once a pool has been drawn down (rem < total) the price is COMMITTED, so we STOP - a partially-paid communal
// gate is never rescaled, even if a player then dis/connects.
function hub_cost_watcher()
{
    level endon( "end_game" );
    last_n = -1;
    for ( ;; )
    {
        // Committed the instant either pool drops below its snapshot total -> lock the price, stop watching.
        if ( level.acc_hub_shards_rem != level.acc_hub_shards_total ||
             level.acc_hub_points_rem != level.acc_hub_points_total )
            return;

        n = GetPlayers().size;
        if ( n != last_n )
        {
            last_n = n;
            level.acc_hub_shards_total = hub_cost_shards();
            level.acc_hub_points_total = hub_cost_points();
            level.acc_hub_shards_rem   = level.acc_hub_shards_total;
            level.acc_hub_points_rem   = level.acc_hub_points_total;
            if ( isdefined( level.acc_hub_trigger ) )
                hub_set_hint( level.acc_hub_trigger );
        }
        wait 1;
    }
}

function hub_door_loop( door )
{
    level endon( "end_game" );

    org = ( 0, ACC_HUB_APPROACH_Y, ACC_HUB_FLOOR_Z + 40 );
    t = spawn( "trigger_radius_use", org, 0, 110, 90 );
    t TriggerIgnoreTeam();
    t SetCursorHint( "HINT_NOICON" );
    level.acc_hub_trigger = t;   // hub_cost_watcher re-sets this hint when the live player count changes the price
    hub_set_hint( t );

    for ( ;; )
    {
        t waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) ) continue;
        if ( IS_TRUE( door.acc_open ) ) break;

        // SOUL PHASE gate (user 2026-07-13): no currency accepted until the L5 soul quota is banked.
        if ( !IS_TRUE( level.acc_hub_souls_complete ) )
        {
            player acc_utility::hud_msg( "Bank " + souls_needed( 4 ) + " souls first - slay the horde on this floor" );
            continue;
        }

        if ( hub_paid() )
        {
            player acc_utility::hud_msg( "All survivors must gather at the gate" );
            continue;
        }

        // INSTALLMENTS, not drain-all (user 2026-07-06: the old "contribute ALL you carry" from
        // 2026-06-24 was "killing people cause they lose everything at once"): each trigger press
        // deposits AT MOST 10 shards + 10k points (dvar-tunable), still capped by what the player
        // carries and what each pool has left. Repeat presses to keep paying - deliberately a
        // several-press ritual so nobody gets zeroed by one accidental hold.
        contributed = false;

        chunk_s = getdvarint( "acc_hub_chunk_shards", 10 );
        chunk_p = getdvarint( "acc_hub_chunk_points", 10000 );

        have_s = acc_data_shards::get_count( player );
        give_s = ( have_s < level.acc_hub_shards_rem ? have_s : level.acc_hub_shards_rem );
        if ( give_s > chunk_s ) give_s = chunk_s;
        if ( give_s > 0 && acc_data_shards::try_spend( player, give_s ) )
        {
            level.acc_hub_shards_rem -= give_s;
            contributed = true;
        }

        have_p = ( isdefined( player.score ) ? player.score : 0 );
        give_p = ( have_p < level.acc_hub_points_rem ? have_p : level.acc_hub_points_rem );
        if ( give_p > chunk_p ) give_p = chunk_p;
        if ( give_p > 0 )
        {
            // Debit the shared pool by the points ACTUALLY removed, not give_p (user 2026-06-27 audit): stock
            // minus_to_player_score deducts NOTHING under Shopping Free Gobblegum or level.intermission, so
            // trusting give_p let a player drain the communal gate cost for FREE. Measure the real score delta -
            // mirrors the shards branch above, which only debits its pool on a successful try_spend.
            before_p = player.score;
            player zm_score::minus_to_player_score( give_p );
            spent_p = before_p - player.score;
            if ( spent_p > 0 )
            {
                level.acc_hub_points_rem -= spent_p;
                contributed = true;
            }
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
        near  = 0;   // published for the pause-menu objective detail line ("Survivors at the gate: a/b",
        alive = 0;   // _acc_lui::acc_compute_objective_detail phase 6) - full count, no early break
        foreach ( p in GetPlayers() )
        {
            if ( !zm_utility::is_player_valid( p ) ) continue;   // skip downed/spectator
            any_alive = true;
            alive++;
            if ( Distance( p.origin, center ) > radius )
                all_near = false;
            else
                near++;
        }
        level.acc_hub_gather_near  = near;
        level.acc_hub_gather_alive = alive;

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

            // The bottom floor is "defeated" when the Paradise gate opens -> L5's dim lamps.
            acc_abyss_deco::floor_lights_on( 5 );

            foreach ( p in GetPlayers() )
                if ( isdefined( p ) ) p IPrintLnBold( "^5Welcome to PARADISE" );

            if ( isdefined( t ) ) t delete();
            return;
        }
    }
}
