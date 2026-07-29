// =============================================================================
// _acc_teleporter.gsc - the LAB <-> EXCHANGE teleporter (user 2026-07-17)
//
// Two linked floor pads that shuttle the squad across the map, bypassing the on-foot
// route entirely:
//   PAD A - the LAB (Pack-a-Punch room, far NORTH,  floor z=0).    BLUE pad.
//   PAD B - the EXCHANGE vault (under the Plaza,     floor z=-240). RED  pad.
//
// UNLOCKED BY BEATING PARADISE (user 2026-07-17; glow language FLIPPED 2026-07-18 to the
// STATION convention - "works like other stations except it has a few other cases"):
//   BROKEN  (pre-Paradise)      - DARK (no glow) + hint "Dead teleporter"; pressing it gives
//                                 the lore toast pointing at the trench ("maybe going deep
//                                 into the trench will fix it" - Paradise is at the bottom
//                                 of the abyss). No teleport.
//   READY   (won + off cooldown)- the STANDARD usable-station blink (0.7s flash / ~4s dark,
//                                 all 9 assembly pieces in lockstep via acc_glow_sync)
//                                 + "Hold [F] Teleport". First appears when first ready.
//   RECHARGE(won + cooldown)    - DARK + hint "Teleporter recharging" (+ the idle beam).
// level.acc_paradise_won (latched in acc_paradise::win()) is the unlock; the DEV sandbox
// (IS_TRUE(level.acc_dev)) unlocks at spawn, so dev NEVER SHOWS the BROKEN state - flip the
// dev branch in unlock_watcher to preview it. Kill switch: acc_teleporter_on 0.
//
// THE THIRD PAD (user 2026-07-17): the trench/abyss-L2 green disc at (-250,1850,-480) - it
// was the _acc_abyss_deco "fault pad" deco (now spawned HERE instead, same origin/model, so
// the room looks identical but the pad is functional). Identical state machine; its
// DESTINATION is a NEW MAP AREA THAT DOES NOT EXIST YET -> it spawns UNLINKED (dst
// undefined): READY shows the normal prompt, but activating fires the de-rez FX + a
// "no destination signal" toast, teleports nobody, and does NOT arm the shared cooldown.
// When the new area is built: give it real coords + yaw (+ a dst_zone if zonemgr-gated)
// in the init() spawn_pad call and it goes live - nothing else to wire.
//
// USABLE EITHER WAY, DOORS OPEN FROM INSIDE (user 2026-07-17): once unlocked the pads read
// no door flag - warp INTO the vault even with both doors closed, then open enter_exchange /
// enter_implant FROM THE INSIDE to walk out (both doors already spawn an interior buy-trigger
// on the slab's inner face - zm_abandoned_cyber_city.gsc::zone_door_buy_loop puts a radius-96
// trigger on BOTH faces of every slab; verified reachable from inside). Or just warp back.
//
// LANDING SAFETY (adversarial review, 2026-07-17): the far Lab is zonemgr-gated, and
// SetOrigin-ing a player into a NOT-yet-enabled zone trips the stock out-of-playable-area
// monitor -> full reset. So the lab-bound warp calls zm_zonemgr::enable_zone("lab_zone")
// on arrival (a no-op if it is already open - the usual post-Paradise case - and the thing
// that makes the DEV warp land safely before the lab doors are bought). The vault end needs
// none: it sits inside the player_in_vault OOB-safe band (_acc_bus_trench.gsc).
//
// 90-SECOND SHARED COOLDOWN (user 2026-07-17): using EITHER pad recharges BOTH (one device).
// Recharging -> a static hint + a hud_msg toast with the live remaining seconds on a deny.
// Live seconds deliberately stay OUT of SetHintString (the engine caps the triggerstring
// BG-cache at 250 UNIQUE strings - a per-second countdown would mint ~90) and OFF the
// clientfields (both pools full). Cooldown template lifted from _acc_jukebox.gsc.
//
// WHO WARPS + THE SEQUENCE (user 2026-07-17 "everyone on the pad" + "full Kino wind-up";
// REVISED 2026-07-18 "should not pause or stop you when you trigger" - NO FreezeControls, no
// slow, ever): trigger -> the pad CHARGES ~2.2s (charge FX + rising hum; players keep full
// control) -> DISCHARGE (bright flash + sparks + de-rez + loud warp boom) -> everyone standing
// within ACC_TP_GATHER of the pad AT THAT MOMENT warps (gather at FIRE time - step off during
// the charge and you stay), fanned onto a ring at the destination so capsules never stack
// (memory coop-teleport-fan-out-not-one-point) -> Kino materialize beam + boom at the far pad.
// ALL sequence FX ride acc_utility::play_fx_burst (PlayFxOnTag on tag_origin hosts) - bare
// `PlayFX( fx, origin )` does NOT render in this build (_acc_perk_lights.gsc:6-15 rule; the
// v3 sequence was invisible because of exactly this).
//
// PAD MODEL - the ASSEMBLED Der Eisendrache teleporter (user 2026-07-18 "add the program 115
// teleporter"), built in GSC as script_models from the stock p7_zm_der_teleporter* FRAGMENTS -
// 4 body wedges at yaw 0/90/180/270 tile the full circular pad, + blue/red energized wire pieces
// + a glass dome, all at SetScale 2.5 (~167u wide, ~63u tall - clears the vault's 144u headroom).
// Arrangement/scale lifted from Program115's teleporter prefab (CREDITS.md); the models are STOCK
// (no pack asset ships). Earlier v1 used ONE fragment standalone and it read "half-baked" - the fix
// was assembling them radially (their pivots are at the min corner exactly so 4 rotations tile a
// ring). Every assembly piece is a glow target (station blink=usable / dark otherwise; the
// CHARGING tell is the teleporter's own charge FX at +40, NOT the holo - user 2026-07-18).
// Pads are FLAT (FINAL 2026-07-18): the step-up clips
// were removed - 11u AND 8u entity-clip ledges both snagged zombies (navmesh-invisible walls)
// = a safe-spot exploit; players stand at floor level inside the walk-through ring.
// Idle Giant pad beam FX through the dome (dlc0/factory/fx_teleporter_beam_factory; toggle
// acc_teleporter_beam 0). Sit-height fine-tune: dvar acc_teleporter_pad_z (0 = base on floor).
//
// PLACEMENT: pad origins are GSC #defines (no .map edit -> -GscOnly, no LED bake).
// *** THE VAULT FLOOR IS z=-160, NOT -240 *** (v1 fell for the STALE _acc_transfer.gsc
// comment; ground truth = the tagged "vault floor slab" brush in the .map, line ~2603:
// top face -160, room x[-720,300] y[-448,360], ceiling -16). v1's pad at z=-240 spawned
// 80u UNDER the floor (invisible) and teleported riders into the void below it (the
// user's fall). Vault pad now sits WEST end (-640,40,-160) - clear of the 4 ATM stations
// (x~80 col, y[-280,200], trigger spheres reach x[-15,175]) and the stair landing
// (x[-620,-380] y[-440,-312]); arrival faces EAST into the room. Lab pad (150,3450,0)
// is confirmed in-game (v1 trigger worked there). Retune = edit the defines + rebuild.
// =============================================================================

#using scripts\shared\util_shared;

#using scripts\zm\_zm_utility;                                // is_player_valid (the co-op rider filter)
#using scripts\zm\_zm_zonemgr;                                // enable_zone (make the lab a valid playable area on arrival)

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;       // derez_burst / play_sound_at_origin / hud_msg / log
#using scripts\zm\zm_abandoned_cyber_city\_acc_interact_glow; // "usable" holo glow (lit on the Paradise win)
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;    // sentry_fleet_warp (bring each rider's Sentry Drones along)

#insert scripts\shared\shared.gsh;                            // IS_TRUE (dev / paradise-won / zone-enabled gates)

// Program115-style ASSEMBLED Der Eisendrache teleporter pad: 4 stock fragment models tiled radially
// (user 2026-07-18 "add the program 115 teleporter"). These are the same p7_zm_der_teleporter* pieces
// that read as "half-baked" standalone (v1) - they are QUARTER-wedges (pivot at the min corner) MEANT
// to be placed 4x at 0/90/180/270 to build the full circular pad (Program115's prefab trick).
#precache( "model", "p7_zm_der_teleporter" );              // the main body wedge (x4 rotated)
#precache( "model", "p7_zm_der_teleporter_pad_wires_blue" ); // energized wires (glow target)
#precache( "model", "p7_zm_der_teleporter_pad_wires_red" );  // energized wires (glow target)
#precache( "model", "p7_zm_der_teleporter_pad_glass" );     // the central glass dome
#precache( "fx", "dlc0/factory/fx_teleporter_beam_factory" );
// KINO wind-up sequence FX (user 2026-07-17) - all stock, already on disk (see docs/44 Workstream C):
#precache( "fx", "dlc4/genesis/fx_sophia_elec_charge_teleporter" );   // the CHARGE windup on the pad
#precache( "fx", "dlc1/castle/fx_elec_teleport_flash_lg" );           // the bright DISCHARGE flash
#precache( "fx", "dlc5/theater/fx_teleport_flashback_kino" );         // Kino arrival beam ("you materialized")

#namespace acc_teleporter;

#define ACC_TP_COOLDOWN_SEC  90                 // seconds to recharge - dvar acc_teleporter_cooldown
#define ACC_TP_TRIG_RADIUS   110                // use-trigger reach (the assembled Der pad is ~167 wide - stand in the ring)
#define ACC_TP_TRIG_HEIGHT   96
#define ACC_TP_GATHER        100                // co-op: warp any valid teammate within this of the used pad
#define ACC_TP_RING          48                 // fan-out ring radius at the destination (no capsule stack; inside the 64x64 clip)
#define ACC_TP_PAD_SCALE     2.5                // Program115 assembly scale (each ~33u fragment -> ~167u full pad)
#define ACC_TP_PAD_ZOFF      -52                // pad sink, EYEBALL-TUNED over 3 user passes (2026-07-18): 0 = the
                                                // whole assembly FLOATED ("in the sky"); the prefab's own -59 =
                                                // nearly flush = "too far in the ground"; -45 = "a little too high,
                                                // zombies can't even get up to it"; -52 = the halfway point (rim
                                                // ~11u proud = exactly the step-up clip height). Fine-tune: dvar
                                                // acc_teleporter_pad_z (read at SPAWN - needs a map restart to apply).
#define ACC_TP_CLIP_TOP      0                  // FLAT (FINAL 2026-07-18): the step-up clips are REMOVED from the map. 11u AND 8u entity-clip ledges both made zombies snag (entity clips are navmesh-INVISIBLE - zombies fight an unseen wall at ANY height) = a safe-spot exploit. Players stand at floor level inside the walk-through ring; riders land at floor z.
#define ACC_TP_CHARGE_SEC    2.2                // Kino wind-up: riders locked on the pad while it charges - dvar acc_teleporter_charge_sec

// PAD A - the LAB (Pack-a-Punch room, far north). floor z=0. Retune in-game.
#define ACC_TP_LAB_ORG   ( 150, 3450, 0 )
#define ACC_TP_LAB_YAW   90                     // arrival faces NORTH into the room (perks/PaP in view) - retune in-game
// PAD B - the EXCHANGE vault (under the Plaza). *** floor z=-160 *** (map ground truth, NOT the
// stale -240 in _acc_transfer's comment - v1's fell-through-the-world bug). West end, clear of
// the ATM stations + stair landing. Retune in-game.
#define ACC_TP_EXCH_ORG  ( -640, 40, -160 )
#define ACC_TP_EXCH_YAW  0                      // arrival faces EAST into the room (stations in view)
// PAD C - the TRENCH (abyss L2, the converted green fault-pad disc; floor z=-480). UNLINKED until
// the new destination area exists - see the header. Clip already in the map (l2_pad_green).
#define ACC_TP_TRENCH_ORG ( -250, 1850, -480 )
#define ACC_TP_TRENCH_YAW 0

function init()
{
    if ( getdvarint( "acc_teleporter_on", 1 ) != 1 )
        return;

    level.acc_tp_cooldown_until = 0;   // GetTime() ms; SHARED across both pads (one device)
    level.acc_tp_unlocked       = false;
    level.acc_tp_trigs = [];           // both use-triggers (a cooldown/unlock change refreshes BOTH hints)
    level.acc_tp_pads  = [];           // both energized-pad models (glow_on targets, lit on the Paradise win)

    // The pad network. GREEN disc in the Lab, RED disc in the vault, GREEN disc in the trench
    // (all already zoned + in-game proven as the abyss fault-pads). Args 5-7 = destination
    // origin/yaw/zonemgr-zone: do_teleport enable_zone()s the zone on arrival so we never drop
    // a player into a not-yet-playable zone (the vault is always OOB-safe -> undefined; the
    // Lab is door-gated -> "lab_zone"). The TRENCH pad is UNLINKED (dst undefined) until its
    // destination area is built - fill in real coords here and it goes live.
    level thread spawn_pad( "lab",      ACC_TP_LAB_ORG,    ACC_TP_LAB_YAW,    ACC_TP_EXCH_ORG, ACC_TP_EXCH_YAW, undefined );
    level thread spawn_pad( "exchange", ACC_TP_EXCH_ORG,   ACC_TP_EXCH_YAW,   ACC_TP_LAB_ORG,  ACC_TP_LAB_YAW,  "lab_zone" );
    level thread spawn_pad( "trench",   ACC_TP_TRENCH_ORG, ACC_TP_TRENCH_YAW, undefined,       0,               undefined );

    level thread unlock_watcher();
    acc_utility::log( "teleporter: 3 pads placed - lab <-> exchange + unlinked trench (BROKEN until Paradise; dev = unlocked at spawn)" );
}

// The pads run the BROKEN state (fast blink + "Dead teleporter" + lore toast on press) until the
// team beats Paradise. The dev sandbox unlocks immediately. level.acc_paradise_won is latched true
// in acc_paradise::win() (polled, not a notify, because the win/wipe share the acc_paradise_end
// notify - the bool is the unambiguous signal).
function unlock_watcher()
{
    level endon( "end_game" );

    if ( !IS_TRUE( level.acc_dev ) )
    {
        while ( !IS_TRUE( level.acc_paradise_won ) )
            wait 1;
    }
    unlock();
}

function unlock()
{
    if ( IS_TRUE( level.acc_tp_unlocked ) ) return;
    level.acc_tp_unlocked = true;

    refresh_all_hints();   // BROKEN -> ready prompts
    refresh_glows();       // dark -> the usable-station blink (first time it ever appears)

    acc_utility::log( "teleporter: UNLOCKED (" + ( IS_TRUE( level.acc_dev ) ? "dev sandbox" : "Paradise defeated" ) + ")" );
}

// Build the assembled Der Eisendrache teleporter pad from the 4 stock fragment models, the exact
// arrangement + scale (2.5) + sink (-59) from Program115's teleporter prefab (CREDITS.md; models
// are stock t7_props_zombie, no pack asset ships). The 4 body wedges tile the ring at 0/90/180/270;
// blue wires at 90/270, red at 0/180, glass dome at 180. Returns EVERY piece as a glow target
// (user 2026-07-18 "any blink we can add to the model" - the whole assembly pulses, not just the
// small wire clumps, so the usable blink is unmistakable). All pieces share the pad origin (differ by
// yaw) because each is a quarter-wedge pivoted at the pad centre - the prefab's shared "0 0 -59".
function spawn_der_teleporter( origin, yaw_base )
{
    base = origin + ( 0, 0, getdvarint( "acc_teleporter_pad_z", ACC_TP_PAD_ZOFF ) );

    glow = [];
    glow[ glow.size ] = spawn_der_piece( "p7_zm_der_teleporter", base, yaw_base + 0 );
    glow[ glow.size ] = spawn_der_piece( "p7_zm_der_teleporter", base, yaw_base + 90 );
    glow[ glow.size ] = spawn_der_piece( "p7_zm_der_teleporter", base, yaw_base + 180 );
    glow[ glow.size ] = spawn_der_piece( "p7_zm_der_teleporter", base, yaw_base + 270 );
    glow[ glow.size ] = spawn_der_piece( "p7_zm_der_teleporter_pad_glass", base, yaw_base + 180 );
    glow[ glow.size ] = spawn_der_piece( "p7_zm_der_teleporter_pad_wires_blue", base, yaw_base + 90 );
    glow[ glow.size ] = spawn_der_piece( "p7_zm_der_teleporter_pad_wires_blue", base, yaw_base + 270 );
    glow[ glow.size ] = spawn_der_piece( "p7_zm_der_teleporter_pad_wires_red",  base, yaw_base + 0 );
    glow[ glow.size ] = spawn_der_piece( "p7_zm_der_teleporter_pad_wires_red",  base, yaw_base + 180 );
    foreach ( g in glow )
    {
        if ( !isdefined( g ) ) continue;
        g.acc_glow_sync = true;   // ONE machine from 9 pieces: skip the per-ent random blink phase so
                                  // the whole assembly pulses in lockstep (user 2026-07-18 "not in sync")
    }
    return glow;
}

function spawn_der_piece( model, origin, yaw )
{
    m = spawn( "script_model", origin );
    if ( !isdefined( m ) ) return undefined;   // entity pool full - skip this piece, never throw
    m setmodel( model );
    m.angles = ( 0, yaw, 0 );
    m SetScale( ACC_TP_PAD_SCALE );
    return m;
}

// Spawn one pad (the assembled Der teleporter + idle beam), its use-trigger, and run the buy loop.
// src = this pad's origin, dst/dst_yaw = the other pad (where riders land + which way they face),
// dst_zone = the destination's zonemgr zone to enable on arrival (undefined = always-safe destination).
function spawn_pad( id, src, src_yaw, dst, dst_yaw, dst_zone )
{
    level endon( "end_game" );

    // Build the Program115-style assembled Der teleporter pad. Its energized WIRE pieces are the glow
    // targets (station blink = usable, dark otherwise). Players stand on the central add_prop_clips
    // step-up plate (teleporter_lab/_exch, or l2_pad_green in the trench) INSIDE the ring.
    glow_pieces = spawn_der_teleporter( src, src_yaw );
    foreach ( g in glow_pieces )
        level.acc_tp_pads[ level.acc_tp_pads.size ] = g;

    // Idle teleporter BEAM so the pad reads as an active device (the real Giant pad beam). A permanent
    // tag_origin host = the derez_burst host pattern, minus the delete. Toggle: acc_teleporter_beam 0.
    if ( getdvarint( "acc_teleporter_beam", 1 ) == 1 )
    {
        if ( !isdefined( level._effect ) ) level._effect = [];
        if ( !isdefined( level._effect[ "acc_tp_beam" ] ) )
            level._effect[ "acc_tp_beam" ] = "dlc0/factory/fx_teleporter_beam_factory";
        beam = spawn( "script_model", src + ( 0, 0, 2 ) );
        beam setmodel( "tag_origin" );
        PlayFxOnTag( level._effect[ "acc_tp_beam" ], beam, "tag_origin" );
    }

    // Script-spawned use-trigger => TriggerIgnoreTeam is REQUIRED (no team otherwise -
    // stock _zm_perks.gsc:1523; memory script-trigger-needs-ignoreteam). Raised 32u so the cursor lands.
    t = spawn( "trigger_radius_use", src + ( 0, 0, 32 ), 0, ACC_TP_TRIG_RADIUS, ACC_TP_TRIG_HEIGHT );
    t TriggerIgnoreTeam();
    t SetCursorHint( "HINT_NOICON" );
    t.acc_tp_src = src;
    t.acc_tp_dst = dst;
    t.acc_tp_dst_yaw = dst_yaw;

    level.acc_tp_trigs[ level.acc_tp_trigs.size ] = t;

    // The trigger is ALWAYS live (the BROKEN state is a visible, pressable prompt with a lore
    // deny - user 2026-07-17 revision; the old hidden-trigger design is gone). Current state:
    set_hint( t );
    refresh_glows();
    level thread hint_ticker( t );

    for ( ;; )
    {
        t waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) ) continue;

        // BROKEN (pre-Paradise): deny + the lore hint at the fix (Paradise, at the bottom of
        // the trench/abyss descent). Constant strings only (triggerstring cache).
        if ( !IS_TRUE( level.acc_tp_unlocked ) )
        {
            player PlaySound( "zmb_no_purchase" );
            player acc_utility::hud_msg( "^1Dead teleporter...^7 maybe going deep into the trench will fix it" );
            continue;
        }

        // SHARED 90s GATE: recharging -> deny with the live remaining seconds (toast, not a hint string).
        now = GetTime();
        if ( now < level.acc_tp_cooldown_until )
        {
            // Suppress the deny toast for ~1.2s after a warp so a still-held +activate on arrival (the
            // rider lands inside the far pad's trigger) doesn't false-flag "recharging" the instant you land.
            just_arrived = ( isdefined( player.acc_tp_arrived_ms ) && ( now - player.acc_tp_arrived_ms ) < 1200 );
            if ( !just_arrived )
            {
                remain = int( ( level.acc_tp_cooldown_until - now + 999 ) / 1000 );
                player PlaySound( "zmb_no_purchase" );
                player acc_utility::hud_msg( "^3Teleporter recharging^7 - " + remain + "s" );
            }
            continue;
        }

        // UNLINKED (the trench pad until its destination area exists): full send theater - the
        // de-rez flash fires but there is nowhere to go. No cooldown arm (nothing happened, and
        // it must not waste the lab<->exchange link's shared 90s).
        if ( !isdefined( dst ) )
        {
            acc_utility::derez_burst( src, "glitch" );
            player PlaySound( "zmb_no_purchase" );
            player acc_utility::hud_msg( "^1No destination signal^7 - the receiving pad does not respond" );
            continue;
        }

        // Arm the shared cooldown BEFORE the warp so a second player can't double-fire it, then
        // flip every pad's hint + glow to the recharging state (usable blink -> dark).
        level.acc_tp_cooldown_until = GetTime() + ( getdvarint( "acc_teleporter_cooldown", ACC_TP_COOLDOWN_SEC ) * 1000 );
        refresh_all_hints();
        refresh_glows();

        do_teleport( player, src, dst, dst_yaw, dst_zone );
    }
}

// Glow = the STATION convention (user 2026-07-18, supersedes the 07-17 blink-when-broken
// language): the standard usable-station blink ONLY while the network is usable RIGHT NOW
// (unlocked + off cooldown); DARK otherwise (BROKEN pre-Paradise = the "Dead teleporter"
// hint carries it; RECHARGING = the hint + idle beam carry it). "Works like other stations,
// except it has a few other cases" - same blink, same cadence, extra states stay dark.
// glow_on restarts blink threads (phase-synced via acc_glow_sync), so state EDGES only -
// never on a timer tick.
function refresh_glows()
{
    ready = ( IS_TRUE( level.acc_tp_unlocked ) && GetTime() >= level.acc_tp_cooldown_until );
    foreach ( pad in level.acc_tp_pads )
    {
        if ( !isdefined( pad ) ) continue;
        if ( ready )
            acc_interact_glow::glow_on( pad );
        else
            acc_interact_glow::glow_off( pad );
    }
}

// Lazy-register the Kino sequence FX (same store-path-string + PlayFX pattern as
// acc_utility::derez_burst, so it behaves identically to the proven de-rez FX path).
function tp_fx_register()
{
    if ( !isdefined( level._effect ) ) level._effect = [];
    if ( isdefined( level._effect[ "acc_tp_charge" ] ) ) return;
    level._effect[ "acc_tp_charge" ] = "dlc4/genesis/fx_sophia_elec_charge_teleporter";  // wind-up
    level._effect[ "acc_tp_flash" ]  = "dlc1/castle/fx_elec_teleport_flash_lg";           // bright discharge flash
    level._effect[ "acc_tp_kino" ]   = "dlc5/theater/fx_teleport_flashback_kino";         // arrival "materialize" beam
}

// The bright DISCHARGE at a pad: flash + electric sparks + the cyan de-rez accent + the loud warp
// boom. EVERY fx rides acc_utility::play_fx_burst (PlayFxOnTag on a throwaway tag_origin host) -
// bare `PlayFX( fx, origin )` does NOT render in this build (the _acc_perk_lights.gsc:6-15 rule;
// v3's whole sequence was silently invisible, user 2026-07-18 "there is no fx when you teleport").
function tp_discharge( origin )
{
    tp_fx_register();
    acc_utility::derez_register();                                  // for the acc_derez_sparks key
    level thread acc_utility::play_fx_burst( "acc_tp_flash", origin + ( 0, 0, 4 ), 2.0 );
    level thread acc_utility::play_fx_burst( "acc_derez_sparks", origin + ( 0, 0, 8 ), 1.0 );
    acc_utility::derez_burst( origin, "glitch" );                   // cyan numbers + zap accent (host-based)
    acc_utility::play_sound_at_origin( origin, "acc_teleport_warp", 3 );
}

// KINO teleport, NO player lock (user 2026-07-18 "should not pause or stop you when you trigger" -
// supersedes the 2026-07-17 freeze): the pad CHARGES for ~2.2s (charge FX + rising hum) while
// everyone keeps full control, then the DISCHARGE fires and warps whoever is ON the pad at that
// moment (gather at FIRE time, not at trigger time - step off during the charge = you stay).
// FX/SFX at BOTH ends.
function do_teleport( user, src, dst, dst_yaw, dst_zone )
{
    tp_fx_register();

    // ---- CHARGE: power the pad up. No lock, no slow. The charging tell is the TELEPORTER'S OWN
    // charge FX (user 2026-07-18: no station holo for this - "use the fx from the teleporter"),
    // riding a host at +40 = TORSO height above the pad; at the old +6 it played at floor level,
    // hidden inside/behind the sunken assembly (why the charge was unreadable). ----
    level thread acc_utility::play_fx_burst( "acc_tp_charge", src + ( 0, 0, 40 ), ACC_TP_CHARGE_SEC + 0.5 );
    acc_utility::play_sound_at_origin( src, "acc_teleport_charge", 4 );
    wait ACC_TP_CHARGE_SEC;

    // ---- DISCHARGE + WARP. Enable the destination zone FIRST (OOB-reset safety). ----
    ensure_zone_enabled( dst_zone );
    tp_discharge( src );                                            // departure flash + boom

    // Gather at FIRE time: whoever is standing on the pad NOW rides (the activator included only
    // if they stayed). Valid players only - a downer mid-charge simply doesn't warp.
    riders = [];
    foreach ( p in GetPlayers() )
        if ( isdefined( p ) && isplayer( p ) && zm_utility::is_player_valid( p ) && Distance2D( p.origin, src ) <= ACC_TP_GATHER )
            riders[ riders.size ] = p;

    for ( i = 0; i < riders.size; i++ )
    {
        ang = i * 360 / riders.size;
        off = ( cos( ang ) * ACC_TP_RING, sin( ang ) * ACC_TP_RING, 0 );   // ring so capsules don't stack
        riders[ i ] FreezeControls( false );                              // belt-and-braces only: never LAND frozen
        riders[ i ] SetOrigin( dst + off + ( 0, 0, ACC_TP_CLIP_TOP ) );   // land ON the raised pad clip
        riders[ i ] SetPlayerAngles( ( 0, dst_yaw, 0 ) );
        riders[ i ].acc_tp_arrived_ms = GetTime();                        // arm the held-button arrival-toast debounce
        acc_boss_items::sentry_fleet_warp( riders[ i ] );                 // Sentry Drones arrive WITH their owner (user 2026-07-25 "i took the teleporter and my drones disappeared") - structural, no reliance on the hover loop's leash snap
    }

    // ---- ARRIVAL: materialize beam + flash + boom at the far pad. ----
    level thread acc_utility::play_fx_burst( "acc_tp_kino", dst + ( 0, 0, 4 ), 3.0 );
    tp_discharge( dst );

    if ( riders.size == 0 )
        acc_utility::log( "teleporter: discharge fired with nobody on the pad (all riders stepped off)" );
}

// Enable the destination zone so the stock OOB monitor treats it as playable. Guarded so we never
// hit stock enable_zone's "zone has not been initialized" assert (_zm_zonemgr.gsc:490).
function ensure_zone_enabled( zname )
{
    if ( !isdefined( zname ) ) return;
    if ( !isdefined( level.zones ) || !isdefined( level.zones[ zname ] ) ) return;
    if ( IS_TRUE( level.zones[ zname ].is_enabled ) ) return;
    zm_zonemgr::enable_zone( zname );
    acc_utility::log( "teleporter: enabled destination zone '" + zname + "' on arrival" );
}

// THREE constant strings only (broken / recharging / ready) - dodges the 250-unique-triggerstring
// cache cap. Set-on-change so re-running the ticker each second never re-sets an unchanged hint.
function set_hint( t )
{
    if ( !isdefined( t ) ) return;
    want = hint_for( t );
    if ( !isdefined( t.acc_tp_hint ) || t.acc_tp_hint != want )
    {
        t SetHintString( want );
        t.acc_tp_hint = want;
    }
}

function hint_for( t )
{
    if ( !IS_TRUE( level.acc_tp_unlocked ) )
        return "^1Dead teleporter";                       // (user copy 2026-07-17) pressable: the deny toast carries the trench lore hint
    if ( GetTime() < level.acc_tp_cooldown_until )
        return "^1Teleporter recharging...";
    return "Hold ^3[{+activate}]^7  Teleport";            // unlinked trench pad shares this; its press explains itself
}

function refresh_all_hints()
{
    if ( !isdefined( level.acc_tp_trigs ) ) return;
    foreach ( t in level.acc_tp_trigs )
        set_hint( t );
}

// Re-evaluate each pad's hint every second - catches BOTH the cooldown-elapse edge and the
// unlock edge. set_hint no-ops unless the displayed string actually changed; when it DID
// change we're on a state edge, so the glows flip too (usable blink <-> dark) - edge-only,
// never per-tick (glow_on would reset the blink phase every second).
function hint_ticker( t )
{
    level endon( "end_game" );
    for ( ;; )
    {
        wait 1;
        if ( !isdefined( t ) ) return;
        prev = t.acc_tp_hint;
        set_hint( t );
        if ( !isdefined( prev ) || prev != t.acc_tp_hint )
            refresh_glows();
    }
}
