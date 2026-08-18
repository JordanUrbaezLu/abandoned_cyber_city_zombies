// =============================================================================
// _acc_perk_scatter.gsc - MAP-WIDE PERK SCATTER (user 2026-07-24)
//
// Replaces the Lab-alcove 4-of-10 door rotation (_acc_perk_doors, retired the
// same day) with a map-wide layout: the 10 perk machines live on 10 fixed PADS
// spread across the map, and every 3rd round (3, 6, 9, ...) the perk->pad
// assignment reshuffles at random. Quick Revive is the exception - it sits
// permanently on the Plaza pad (and keeps stock solo auto-power behaviour).
// The opening layout is ALSO random (rolled per run, applied during load
// before the blackscreen lifts - players never see the old Lab row).
//
// PIN MECHANIC: a player who owns the MEGA version of a perk can spend
// 2 Empty Mega Bottles at its machine to LOCK that perk onto its current pad
// for the rest of the game - the pad AND the perk both drop out of the
// rotation (the direct successor of the retired 2-bottle perk-door permanent
// unlock: same currency, same cost, same "spend bottles to make perk access
// permanent" role).
//
// HOW MACHINES MOVE (the hack, and why it is safe): stock perk_machine_spawn_init
// (_zm_perks.gsc:1513-1561) builds each machine out of 4 SCRIPT ENTITIES -
// t_use ("zombie_vending" trigger at origin+z60, r40 h80), t_use.machine (the
// vending script_model), t_use.bump (audio trigger at +z20) and t_use.clip
// (solid "zm_collision_perks1" script_model, DisconnectPaths'd). Nothing is
// baked world geometry, so we simply REWRITE THE ORIGINS. Shipped precedent:
// zm_nuked displaces vending triggers +-10000z and flies a whole machine in on
// a vehicle mid-game (docs/16:60-72), its relocatable PaP rewrites trigger +
// machine + clip origins (docs/16:88-93), and ohm-nabar/zm_building ships the
// literal move_perk_machine utility (docs/16:116-121). Our own
// force_perk_machine_facing (_acc_perks.gsc:144) already mutates these same
// handles at runtime. Everything downstream resolves machines BY NAME
// ("zombie_vending" / radiant_machine_name), never by position, so the stock
// purchase pipeline, drink anims, jingles, power gating and _acc_ integrations
// (mega triggers, perk_info pricing, perk_lights glow) all survive the move.
//
// MOVE RECIPE (order matters; apply_scatter phases the nav calls across ALL
// machines - all ConnectPaths first, then all moves + DisconnectPaths):
//   clip ConnectPaths() at the OLD pad  ->  move clip/machine/t_use/bump (+ the
//   paired acc_mega_vending + acc_perk_pin triggers + the s_fxloc FX host)  ->
//   clip DisconnectPaths() at the NEW pad  ->  unstick any player overlapped by
//   the arrival  ->  re-pulse the accPerkGlow aura 0->idx post-power (auras
//   restored 2026-07-25 - the native model swap showed nothing in this build;
//   a latched CF set far from a viewer never renders on approach). Live scatters
//   also play the SWAP PRESENTATION: de-rez burst + warp boom at both pads and
//   a 60u materialize-glide on the model (silent for the opening layout).
//
// PARADISE: the z=-1200 duplicate perk row is NOT part of the scatter - capture
// filters to surface machines (trigger z > -600, same z-band split
// _acc_perk_lights/pulse_deep_glows and the Avogadro twin cache use). Avogadro's
// hack-seek cache IS position-based, so _acc_boss_avogadro re-runs
// cache_target_origins() on our "acc_perk_scatter_applied" notify.
//
// EMP safety: t.machine.b_keep_when_turned_off = true on every captured machine
// (stock-sanctioned field, _zm_perks.gsc:244) so no power-off path can ever
// Delete-and-respawn a machine model out from under our captured handles.
//
// DEV: no flags, no dvars (all-dev-features-ride-acc-dev-only). Dev builds get
// the assignment table printed on every scatter; ship builds get the banner only.
//
// Public API:
//   init() - build pads, arm the acc_round_start listener (MUST be called from
//            acc_main::init() before watch_round_transitions starts), then
//            capture the machines + apply the opening layout.
// Events:
//   "acc_perk_scatter_applied" (level notify) - after every applied layout,
//            including the opening one. Consumed by _acc_boss_avogadro (recache).
//   "acc_perk_pinned" (level notify, arg spec) - after a successful pin.
// =============================================================================

#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;   // has_mega_perk / try_consume_bottle / mega_hint_name (pin buy)
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_lights;    // set_glow / perk_color_index (post-move aura re-pulse; auras restored 2026-07-25)

#define ACC_SCATTER_INTERVAL      3     // reshuffle at the start of every round divisible by this (3, 6, 9, ...)
#define ACC_SCATTER_PIN_COST      2     // Empty Mega Bottles to pin a Mega'd perk to its current pad
#define ACC_SCATTER_TRIG_R        40    // stock vending trigger dims (_zm_perks.gsc:1513) - reused for the pin trigger
#define ACC_SCATTER_TRIG_H        80
#define ACC_SCATTER_TRIG_Z        60    // t_use sits at pad origin + z60 (stock), bump at +z20
#define ACC_SCATTER_BUMP_Z        20
#define ACC_SCATTER_UNSTICK_R     55    // 2D radius around a pad that counts as "inside the arriving machine"
#define ACC_SCATTER_UNSTICK_ZBAND 110
#define ACC_SCATTER_UNSTICK_PUSH  85    // how far in front of the machine an overlapped player is placed
#define ACC_SCATTER_DROP_Z        60    // swap presentation: the model materializes this far up and glides down
#define ACC_SCATTER_GLIDE_SEC     0.8   // ...over this long (cosmetic only - trigger/clip land instantly; 0.4 read as "nothing" in the first live test)
#define ACC_SCATTER_FX_Z          40    // de-rez burst height at the VACATED pad (machine already gone - open air)
#define ACC_SCATTER_ARRIVE_FX_Z   90    // arrival burst height - ABOVE the descending model so it is not buried in the mesh

#namespace acc_perk_scatter;

// ---------------------------------------------------------------------------
// Pads. Origins sit AT floor z against a wall. Every spot below was
// PLACEMENT-VERIFIED against the live .map (2026-07-24, 8-agent sweep): prop
// clips, corridor mouths, door aprons, riser structs, decals, box nodes,
// teep-clear r110s and >=45u lanes were checked clip-edge to clip-edge -
// details in docs/02 (perk-scatter pad ledger). Do not nudge a pad without
// re-checking its band there.
// yaw: 359.999 = the live-verified "back to a NORTH wall, faces south" facing
// (_acc_perks.gsc:143 - these vending models' visual front is model-local -Y,
// NOT engine-forward +X; the recorded failure: 270 faced them WEST,
// tools/oneshots/fix_perk_facing_flanks.js). Other walls rotate from that
// baseline: S wall = 180, W wall = 90, E wall = 270. This table is for the
// p7_zm_vending_* models ONLY - the AW box / teleporter / jukebox use the
// +X-front convention (do not copy this table for those).
// front: unit vector out of the machine face (drives the unstick push) -
// stored explicitly so nobody has to re-derive the model-forward convention.
// ---------------------------------------------------------------------------

function build_pads()
{
    pads = [];
    // STANDOFF CONVENTION (user 2026-07-24 "the vault machine is inside the wall"):
    // every wall pad's origin sits 33u off the wall INTERIOR FACE toward the room -
    // the Lab row's in-game-eyeballed geometry (origins y=4195 vs wall face 4228).
    // The initial flush-mount placements (origin ~17.5u off the face) sank the
    // vending model into the wall - the model extends further back from its origin
    // than the nominal half-depth. Do NOT place a pad closer than 33.

    // Plaza W wall (plane x=-470, 33u standoff), south of the planter bed:
    // clip-free span y[-144,-20.9].
    pads[ pads.size ] = make_pad( "the Plaza",              ( -437,  -110,    0 ),  90,      (  1,  0, 0 ), ACC_SCATTER_UNSTICK_PUSH, "specialty_quickrevive" );
    // THE SCIENTIST'S OFFICE (user 2026-07-26): the old Lab N-wall pad (75,4195)
    // MOVED inside the new office room behind that wall (gen_scientist_office.js;
    // office TRANSLATED -360y by the 2026-08-02 lab compression - interior now
    // x[-275,125] y[3888,4208], door at x[-123,-27] in the inner N wall) and PERMANENTLY
    // FIXED to Juggernog - "jugg and QR are always in same spot", REGARDLESS of
    // solo/co-op (no solo gating; QR's Plaza fix keeps its stock solo quirks,
    // Jugg's has none). E wall (face x=125, 33u standoff -> x=92), E-wall yaw
    // 270, front west. Clear of the chem tank (y[3905,3959]) and the control
    // console (y[4142,4202]); unstick push 85 lands (7,4060) = open room center.
    pads[ pads.size ] = make_pad( "the Scientist's Office", (    92,  4060,    0 ),  270,     ( -1,  0, 0 ), ACC_SCATTER_UNSTICK_PUSH, "specialty_armorvest" );
    // Lab S-wall decon TENT (the big curtain-open decontamination unit at
    // (-560,3075)): pad centered between its side-pillar clips (x[-622,-610] /
    // x[-510,-498], y[3075,3134] - 100u clear mouth), 33u+ off the S wall face
    // (y3068 -> 3103 = ~the tent's own center). Machine backs the S wall inside
    // the tent and faces N out the open curtain; the buy prompt reads from the
    // tent mouth (trigger r40 reaches y~3143, mouth at y3134). The lintel/
    // curtain-rail clip band sits z[96,118], so the ~128-tall machine top pokes
    // through the rail mesh - the accepted "inside a tent if possible" tradeoff
    // (user 2026-07-25). Unstick push 85 lands (-560,3188): straight out the
    // mouth, clear of the queue poles at x-520/-380 (unclipped) and the tent
    // footprint's original keep-clear-validated lanes.
    pads[ pads.size ] = make_pad( "the Lab",                ( -560,  3103,    0 ),  180,     (  0,  1, 0 ), ACC_SCATTER_UNSTICK_PUSH, undefined );
    // Alley N wall (plane 1476, 33u standoff), the clean 161u gap between the
    // bike clip (ends x1736) and the rubble-pile clip (starts x1897).
    pads[ pads.size ] = make_pad( "the Alley",              ( 1816,  1443,    0 ),  359.999, (  0, -1, 0 ), ACC_SCATTER_UNSTICK_PUSH, undefined );
    // Market S wall (interior face y=380, 33u standoff) - east of the fastfood
    // sign + kitchen-table clip (no x overlap with either).
    pads[ pads.size ] = make_pad( "the Market",             ( -1650, 413,     0 ),  180,     (  0,  1, 0 ), ACC_SCATTER_UNSTICK_PUSH, undefined );
    // Helipad S wall (face y=2280, 33u standoff), W edge on the traffic-barrier
    // clip line; keeps the bomber oval's S lane intact. SHORT unstick push (38):
    // the studio-tripod clip starts at y=2368 - 38 lands the player's capsule
    // just short of it while still clearing the machine face.
    pads[ pads.size ] = make_pad( "the Helipad",            ( -1500, 2313,    0 ),  180,     (  0,  1, 0 ), 38, undefined );
    // Vault W wall (plane x=1119, 33u standoff), the 62u free span y[2984,3046]
    // between the dragon-network clip and the monitor-support pole.
    pads[ pads.size ] = make_pad( "the Vault",              ( 1152,  3015,    0 ),  90,      (  1,  0, 0 ), ACC_SCATTER_UNSTICK_PUSH, undefined );
    // Jukebox/reactor under-room, E wall SOLID segment y[2189,2280] (face x=384,
    // 33u standoff; the live room is the expand_core arena out to x=384 - y>2280
    // on the E wall is the OPEN east-wing mouth).
    pads[ pads.size ] = make_pad( "the Bus Station depths", (  351,  2234, -240 ),  270,     ( -1,  0, 0 ), ACC_SCATTER_UNSTICK_PUSH, undefined );
    // ABYSS LAYER 2 (user 2026-07-25: "passed the first soul door, a level below the
    // trench") - W wall of the L2 shaft (slab x[-781,-112], face x=-781, 33u
    // standoff), straight west of the XS-well landing so it reads on arrival.
    // Clear of: SW server-tower row (S wall, ends x~-645), W-wall rack (-756,1900),
    // W-wall breaker cabinet (-756,2050), W bay breaker slab (-550,1948), the
    // Overclock terminal (-400,1948), the teleporter pad r110 (-250,1850), both
    // descent wells (x~-124). Navmesh: NO compile pre-cut needed (unlike the old
    // pit pad) - deep worldspawn clips CRASH the LED bake (add_prop_clips.js
    // header), and the L2 floor already carries runtime-DisconnectPaths'd
    // brushmodel clips mid-slab (both breaker pillars + the Overclock terminal)
    // with zombies routing around them fine, so the machine clip behaves exactly
    // like those. The pit's FIX BATCH 4 stair-link fragility does not apply here.
    pads[ pads.size ] = make_pad( "the Abyss (Layer 2)",    ( -748,  1790, -480 ),  90,      (  1,  0, 0 ), ACC_SCATTER_UNSTICK_PUSH, undefined );
    // Exchange N wall (interior face y=360, 33u standoff) - 47u trigger-edge gap
    // to the deposit-pad trigger column at x=80. Push shortened to 70 to keep a
    // nudged player clear of the transfer-station column at y~200.
    pads[ pads.size ] = make_pad( "the Exchange",           (   25,   327, -160 ),  359.999, (  0, -1, 0 ), 70, undefined );
    return pads;
}

function make_pad( disp, origin, yaw, front, push, fixed_spec )
{
    pad = SpawnStruct();
    pad.disp = disp;
    pad.origin = origin;
    pad.yaw = yaw;
    pad.front = front;
    pad.push = push;                  // per-pad unstick distance out the machine face
    pad.fixed_spec = fixed_spec;      // only the Plaza pad: permanently Quick Revive
    pad.locked_spec = undefined;      // set when fixed or pinned - out of the rotation
    return pad;
}

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "perk_scatter: init" );

    level.acc_scatter_pads = build_pads();
    level.acc_scatter_pinned = [];     // spec -> true (pinned by a Mega holder)
    level.acc_scatter_where = [];      // spec -> pad index (current home)
    level.acc_scatter_machines = [];   // spec -> the "zombie_vending" trigger (surface copy)

    // Round listener FIRST (acc_main threads watch_round_transitions after all
    // inits, but arm-before-dispatch is the module contract - _acc_main.gsc:196).
    level thread round_watcher();

    // Machine capture + the opening layout run async (machines spawn during the
    // stock perk init flow; we poll for them like _acc_perks/_acc_mega_bottles do).
    level thread capture_and_open();
}

function round_watcher()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
        // Body stays wait-free (a wait here would silently miss the next
        // acc_round_start - the documented _acc_leveling/_acc_lockdown trap).
        if ( round_number >= ACC_SCATTER_INTERVAL && ( round_number % ACC_SCATTER_INTERVAL ) == 0 )
            level thread apply_scatter( false );
    }
}

function capture_and_open()
{
    level endon( "end_game" );

    // Vending triggers spawn during stock load (perk __main__ + perk_machine_
    // spawn_init); poll until the surface row is fully up (the exact idiom of
    // _acc_perks.gsc:148 / _acc_mega_bottles.gsc:586). 10 = the full roster;
    // accept a late partial capture rather than never scattering at all.
    machines = [];
    for ( tries = 0; tries < 120; tries++ )
    {
        machines = surface_vending_triggers();
        if ( machines.size >= 10 ) break;
        wait 0.5;
    }

    if ( machines.size == 0 )
    {
        acc_utility::log( "^1perk_scatter: NO surface vending triggers found - scatter disabled" );
        return;
    }
    if ( machines.size < 10 )
        acc_utility::log( "^1perk_scatter: only " + machines.size + "/10 machines captured - scattering those" );

    level.acc_scatter_machines = machines;

    keys = GetArrayKeys( machines );
    for ( i = 0; i < keys.size; i++ )
    {
        t = machines[ keys[ i ] ];
        // Stock turn_perk_off Deletes + respawns the machine model unless this
        // stock-sanctioned field is set (_zm_perks.gsc:244) - which would strand
        // every handle we (and t_use.machine itself) hold on the machines we
        // MOVE. Two review-verified caveats (2026-07-24): (1) QUICK REVIVE is
        // EXCLUDED - the stock solo 3-buy epilogue (turn_revive_on ->
        // "revive_hide" -> turn_perk_off) is the one live turn_perk_off path on
        // this map, and QR never moves after its opening placement, so it keeps
        // pure-stock behaviour (the boss EMP perk_pause only touches player
        // state, _zm_perks.gsc:1234 - no off-path exists for the other 9).
        // (2) the flag flips stock perk_fx into its unlinked s_fxloc branch at
        // power-on (~9 invisible tag_origin FX hosts - server FX never renders
        // here anyway); move_machine drags s_fxloc along so nothing orphans.
        if ( keys[ i ] != "specialty_quickrevive" )
        {
            t.machine.b_keep_when_turned_off = true;
            spawn_pin_trigger( t, keys[ i ] );
        }
    }

    // Opening layout: random per run (user 2026-07-24), applied while the
    // blackscreen still hides the map - nobody ever sees the legacy Lab row.
    apply_scatter( true );
}

// The 10 SURFACE machines only: the Paradise duplicate row (z=-1200) shares
// targetname + script_noteworthy, so split by z-band exactly like
// _acc_perk_lights::pulse_deep_glows and the Avogadro twin cache (z > -600 =
// surface; trigger origins sit at floor+60, so the surface row reads ~60/-180).
function surface_vending_triggers()
{
    out = [];
    triggers = GetEntArray( "zombie_vending", "targetname" );
    for ( i = 0; i < triggers.size; i++ )
    {
        t = triggers[ i ];
        if ( !isdefined( t ) || !isdefined( t.script_noteworthy ) ) continue;
        if ( t.origin[ 2 ] < -600 ) continue;          // Paradise twin - never scattered
        if ( !isdefined( t.machine ) ) continue;       // assembly not finished spawning yet
        out[ t.script_noteworthy ] = t;
    }
    return out;
}

// ---------------------------------------------------------------------------
// The scatter
// ---------------------------------------------------------------------------

function apply_scatter( b_initial )
{
    level endon( "end_game" );

    pads = level.acc_scatter_pads;
    machines = level.acc_scatter_machines;
    if ( !isdefined( machines ) || machines.size == 0 ) return;

    // Build the FULL move list first, then apply it in TWO wait-free phases:
    // (1) ConnectPaths every mover's clip while ALL machines still sit at their
    // old pads, (2) move each assembly + DisconnectPaths at its new pad. The
    // original per-machine serialize (connect->move->disconnect one machine at
    // a time) was WRONG (adversarial review 2026-07-24, 3x confirmed): in any
    // permutation cycle a later machine's ConnectPaths at its old pad fires
    // AFTER an earlier machine's DisconnectPaths at that same pad - the calls
    // are not refcounted, so the pad's navmesh stayed OPEN under a solid clip
    // until the next scatter (zombies grind into the machine). With every
    // connect strictly before every disconnect, no departure can undo an
    // arrival. Both phases stay in one server frame (no waits).
    moves = [];

    // FIXED pads: each pad's declared fixed_spec machine is placed ONCE on its
    // pad, then never rolled again. GENERALIZED 2026-07-26 (was QR-hardwired -
    // it always moved the QR handle, so a 2nd fixed pad would have moved QR
    // twice): now each fixed pad moves ITS OWN spec's machine. Two fixed pads
    // ship: QR -> the Plaza (solo auto-power + stock 3-buy solo rules ride the
    // trigger/specialty, not the position, so they survive the move untouched),
    // Juggernog -> the Scientist's Office (user 2026-07-26, unconditional).
    if ( b_initial )
    {
        for ( i = 0; i < pads.size; i++ )
        {
            if ( !isdefined( pads[ i ].fixed_spec ) ) continue;
            m = machines[ pads[ i ].fixed_spec ];
            if ( !isdefined( m ) ) continue;
            moves[ moves.size ] = make_move( m, i, pads[ i ].fixed_spec );
            pads[ i ].locked_spec = pads[ i ].fixed_spec;
        }
    }

    // Rotating pool = every captured perk minus the fixed ones (QR/Plaza +
    // Jugg/Office) minus pinned; open pads = every pad without a locked
    // occupant. Pinning removes a (perk, pad) PAIR, so the two lists stay the
    // same size by construction.
    specs = [];
    keys = GetArrayKeys( machines );
    for ( i = 0; i < keys.size; i++ )
    {
        spec = keys[ i ];
        if ( spec_is_fixed( spec ) ) continue;
        if ( IS_TRUE( level.acc_scatter_pinned[ spec ] ) ) continue;
        specs[ specs.size ] = spec;
    }

    open_pads = [];
    for ( i = 0; i < pads.size; i++ )
    {
        if ( !isdefined( pads[ i ].locked_spec ) )
            open_pads[ open_pads.size ] = i;
    }

    if ( specs.size != open_pads.size )
        acc_utility::log( "^1perk_scatter: pool mismatch - " + specs.size + " perks vs " + open_pads.size + " open pads (pairing the overlap)" );

    specs = shuffle( specs );

    n = specs.size;
    if ( open_pads.size < n ) n = open_pads.size;

    for ( i = 0; i < n; i++ )
        moves[ moves.size ] = make_move( machines[ specs[ i ] ], open_pads[ i ], specs[ i ] );

    // Phase 1: reopen every mover's OLD footprint (nothing has been cut yet).
    for ( i = 0; i < moves.size; i++ )
    {
        t = moves[ i ].t;
        if ( isdefined( t ) && isdefined( t.clip ) )
            t.clip ConnectPaths();
    }

    // Phase 2: relocate + cut each NEW footprint. b_initial = silent (pre-blackscreen
    // opening layout); live scatters get the de-rez warp presentation per machine.
    for ( i = 0; i < moves.size; i++ )
    {
        mv = moves[ i ];
        move_machine( mv.t, pads[ mv.pad_idx ], mv.spec, b_initial );
        level.acc_scatter_where[ mv.spec ] = mv.pad_idx;
    }

    level notify( "acc_perk_scatter_applied" );

    if ( !b_initial )
        announce_scatter();
    debug_dump( b_initial );
}

// True when a pad declares this spec as its permanent occupant (QR -> the Plaza,
// Juggernog -> the Scientist's Office). Fixed perks never enter the rotation and
// cannot be Mega-pinned (they are already permanent - do_pin refuses).
function spec_is_fixed( spec )
{
    pads = level.acc_scatter_pads;
    for ( i = 0; i < pads.size; i++ )
    {
        if ( isdefined( pads[ i ].fixed_spec ) && pads[ i ].fixed_spec == spec )
            return true;
    }
    return false;
}

// Fisher-Yates via the project RNG wrapper (mirrors _acc_perk_doors/_acc_lockdown roll_order).
function shuffle( specs )
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

function make_move( t, pad_idx, spec )
{
    mv = SpawnStruct();
    mv.t = t;
    mv.pad_idx = pad_idx;
    mv.spec = spec;
    return mv;
}

// The move recipe (header). All pieces are the stock-spawned script entities -
// origin writes relocate them (shipped precedent: zm_nuked / ohm-nabar, docs/16).
// NOTE: the caller (apply_scatter) has ALREADY ConnectPaths'd this clip at the
// old pad in its phase 1 - this function only relocates and cuts the new pad.
// b_silent = true for the pre-blackscreen opening layout (no FX/SFX/glide).
function move_machine( t, pad, spec, b_silent )
{
    if ( !isdefined( t ) || !isdefined( t.machine ) ) return;

    old_org = t.machine.origin;
    yaw = pad.yaw;

    // SWAP PRESENTATION (user 2026-07-25 "at least a SFX at the perk location when
    // they swap... enhance this somehow"): the teleporter's proven discharge read -
    // cyan de-rez numbers + zap burst and the acc_teleport_warp boom at BOTH pads
    // (_acc_teleporter.gsc:368 recipe; bare server PlayFX does not render here, these
    // host-based primitives do) - and the model MATERIALIZES ACC_SCATTER_DROP_Z up,
    // gliding down onto the pad (nuketown-lite). Purely cosmetic: the trigger/clip
    // land instantly below, so the glide can never trap or block anyone.
    if ( IS_TRUE( b_silent ) )
        t.machine.origin = pad.origin;
    else
    {
        // First live test read as "nothing" (user 2026-07-25) - the 0.4s glide was a blink
        // and the arrival burst sat buried inside the descending mesh. Now: burst in open
        // air at the vacated pad, arrival burst ABOVE the model, a slower 0.8s descent,
        // and a LANDING PUNCH (stock perk power-on ka-chunk + machine shake + flash).
        t.machine.origin = pad.origin + ( 0, 0, ACC_SCATTER_DROP_Z );
        t.machine MoveTo( pad.origin, ACC_SCATTER_GLIDE_SEC );
        acc_utility::derez_burst( old_org + ( 0, 0, ACC_SCATTER_FX_Z ), "glitch" );
        acc_utility::play_sound_at_origin( old_org, "acc_teleport_warp", 2 );
        acc_utility::derez_burst( pad.origin + ( 0, 0, ACC_SCATTER_ARRIVE_FX_Z ), "glitch" );
        acc_utility::play_sound_at_origin( pad.origin, "acc_teleport_warp", 2 );
        level thread land_punch( t.machine, pad.origin );
    }
    t.machine.angles = ( 0, yaw, 0 );
    t.machine.acc_pad_yaw = yaw;    // read by _acc_perks::apply_perk_facing so the
                                    // post-load facing re-assert respects pad walls

    if ( isdefined( t.clip ) )
    {
        t.clip.origin = pad.origin;
        t.clip.angles = ( 0, yaw, 0 );
        t.clip DisconnectPaths();
    }

    t.origin = pad.origin + ( 0, 0, ACC_SCATTER_TRIG_Z );
    if ( isdefined( t.bump ) )
        t.bump.origin = pad.origin + ( 0, 0, ACC_SCATTER_BUMP_Z );

    // Paired _acc_ triggers ride along (they are spawned at t.origin and never
    // re-read it - the mega trigger is back-linked for us in _acc_mega_bottles).
    if ( isdefined( t.acc_mega_trigger ) )
        t.acc_mega_trigger.origin = pad.origin + ( 0, 0, ACC_SCATTER_TRIG_Z );
    if ( isdefined( t.acc_pin_trigger ) )
        t.acc_pin_trigger.origin = pad.origin + ( 0, 0, ACC_SCATTER_TRIG_Z );

    // Stock perk_fx's b_keep branch parks an unlinked tag_origin FX host
    // (machine.s_fxloc) at the power-on position - drag it along so the (today
    // invisible, server-side) perk-light locus never orphans at an old pad.
    if ( isdefined( t.machine.s_fxloc ) )
        t.machine.s_fxloc.origin = pad.origin;

    // 2) Anyone standing where the machine landed gets placed in front of it
    //    (solid model + clip would wedge them inside - the doors-era no-trap
    //    problem, solved by relocation instead of deferral so a camper can
    //    never stall the whole scatter).
    unstick_players( pad );

    // 3) Glow (auras restored 2026-07-25): the accPerkGlow clientfield LATCHES,
    //    and an FX set far from the viewer never renders on approach - re-pulse
    //    0 -> idx after every move (the glow-rekick rule). Only once power has
    //    actually glowed them, and NEVER while an Avogadro hack has this machine
    //    dark (the unhack path in _acc_boss_avogadro is the sole re-light).
    b_hacked = ( isdefined( level.acc_avo_hacked ) && IS_TRUE( level.acc_avo_hacked[ spec ] ) );
    if ( IS_TRUE( level.acc_perk_glow_done ) && !b_hacked )
        level thread reglow_after_move( t.machine, spec );
}

function reglow_after_move( machine, spec )
{
    level endon( "end_game" );

    acc_perk_lights::set_glow( machine, 0 );
    wait 0.25;   // > one snapshot, so the 0 transmits before the re-set (reglow precedent)
    if ( isdefined( machine ) )
        acc_perk_lights::set_glow( machine, acc_perk_lights::perk_color_index( spec ) );
}

// Landing punch (self-threaded per moved machine): when the materialize-glide touches
// down, the machine plays the stock perk power-on ka-chunk (the exact sound + vibrate
// perk_machine_think uses at power-on - instantly recognizable as "a machine just came
// alive here") plus one more de-rez flash at body height. Sound rides the emitter
// primitive (proven audible), the vibrate is the stock-blessed machine shake.
function land_punch( machine, org )
{
    level endon( "end_game" );

    wait ACC_SCATTER_GLIDE_SEC;
    if ( !isdefined( machine ) ) return;

    machine Vibrate( ( 0, -100, 0 ), 0.3, 0.4, 3 );   // stock perk_machine_think power-on shake
    acc_utility::play_sound_at_origin( org, "zmb_perks_power_on", 2 );
    acc_utility::derez_burst( org + ( 0, 0, ACC_SCATTER_FX_Z ), "glitch" );
}

function unstick_players( pad )
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) || !isdefined( p.origin ) ) continue;
        if ( Distance2D( p.origin, pad.origin ) > ACC_SCATTER_UNSTICK_R ) continue;
        if ( abs( p.origin[ 2 ] - pad.origin[ 2 ] ) > ACC_SCATTER_UNSTICK_ZBAND ) continue;

        // Pad fronts face open, audited floor (docs/02 keep-clear bands); the
        // push distance is per-pad so tight fronts (Helipad tripod clip,
        // Exchange station column) land the player short of the nearest clip.
        p SetOrigin( pad.origin + pad.front * pad.push );
    }
}

function announce_scatter()
{
    // ONCE PER MATCH (user 2026-08-01): scatters recur every 3rd round (~10x/match) and the
    // banner got annoying. First scatter explains the mechanic; after that the moved machines
    // + perk lights are the tell.
    acc_utility::announce_once( "perk_scatter", "^5PERK MACHINES SCATTERED^7 - find their new homes" );
}

// Dev-only visibility (debug rides acc_dev ONLY - no dvars). File log always.
function debug_dump( b_initial )
{
    tag = ( b_initial ? "opening layout" : "scatter" );
    keys = GetArrayKeys( level.acc_scatter_where );
    for ( i = 0; i < keys.size; i++ )
    {
        pad = level.acc_scatter_pads[ level.acc_scatter_where[ keys[ i ] ] ];
        line = "perk_scatter: " + tag + " " + keys[ i ] + " -> " + pad.disp;
        acc_utility::log( line );
        if ( IS_TRUE( level.acc_dev ) )
        {
            players = GetPlayers();
            for ( j = 0; j < players.size; j++ )
            {
                if ( isdefined( players[ j ] ) )
                    players[ j ] IPrintLn( "[scatter] " + keys[ i ] + " -> " + pad.disp );
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Pin: 2 Empty Mega Bottles lock a Mega'd perk onto its current pad forever.
// Successor of the retired perk-door permanent unlock (same cost/currency).
// One trigger per machine (except Quick Revive - it never moves), stacked on
// the vending trigger like the mega trigger is; the three prompts can never
// collide because their per-player visibility sets are disjoint by state:
// stock vending = doesn't own the perk, mega = owns base but not Mega,
// pin = CURRENTLY owns the base perk AND its Mega. The HasPerk requirement is
// load-bearing (review 2026-07-24): the Mega flag is sticky across a down, so
// without it a revived Mega holder would see the pin prompt AND the stock
// rebuy prompt stacked at the same origin - gating on HasPerk (the same gate
// the mega trigger uses) restores mutual exclusion with the stock trigger.
// ---------------------------------------------------------------------------

function spawn_pin_trigger( t, spec )
{
    tp = Spawn( "trigger_radius_use", t.origin, 0, ACC_SCATTER_TRIG_R, ACC_SCATTER_TRIG_H );
    if ( !isdefined( tp ) )
    {
        // Entity pool full (G_Spawn ~1024) - degrade to "no pin on this machine"
        // rather than a script abort (the _acc_teleporter spawn guard).
        acc_utility::log( "^1perk_scatter: pin trigger spawn FAILED for " + spec + " (entity pool?)" );
        return;
    }

    tp.targetname = "acc_perk_pin";
    tp.acc_spec = spec;
    tp TriggerIgnoreTeam();
    tp UseTriggerRequireLookAt();
    tp SetCursorHint( "HINT_NOICON" );
    // Static + bounded (9 strings, replacing the 10 retired door-unlock strings -
    // net negative on the engine hint-string cap). "permanently" + "Mega Bottles"
    // keeps the LUI cursor-hint router classifying it like the old unlock prompt.
    tp SetHintString( "Hold ^3[{+activate}]^7 Lock ^5" + acc_mega_bottles::mega_hint_name( spec ) +
                      "^7 here permanently for ^2" + ACC_SCATTER_PIN_COST + " Mega Bottles" );

    t.acc_pin_trigger = tp;
    tp thread pin_visibility( spec );
    tp thread pin_think( spec );
}

function pin_visibility( spec )
{
    level endon( "end_game" );
    self endon( "death" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) ) continue;
            b_show = !IS_TRUE( level.acc_scatter_pinned[ spec ] )
                     && ( p HasPerk( spec ) )
                     && acc_mega_bottles::has_mega_perk( p, spec );
            self SetInvisibleToPlayer( p, !b_show );
        }
        wait 0.25;
    }
}

function pin_think( spec )
{
    level endon( "end_game" );
    self endon( "death" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) ) continue;
        if ( IS_TRUE( level.acc_scatter_pinned[ spec ] ) ) continue;
        // FIXED perks (QR/Plaza, Jugg/Office) are already permanent - refuse BEFORE
        // the bottle charge so nobody wastes 2 Mega Bottles on a no-op (2026-07-26).
        if ( spec_is_fixed( spec ) )
        {
            player iprintln( "^3" + acc_mega_bottles::mega_hint_name( spec ) + "^7 never moves - no pin needed" );
            wait 0.5;
            continue;
        }
        if ( !( player HasPerk( spec ) ) ) continue;   // must currently own the base perk (mirrors the visibility gate)
        if ( !acc_mega_bottles::has_mega_perk( player, spec ) ) continue;

        if ( !acc_mega_bottles::try_consume_bottle( player, ACC_SCATTER_PIN_COST ) )
        {
            player iprintln( "Need " + ACC_SCATTER_PIN_COST + " Empty Mega Bottles" );
            wait 0.5;
            continue;
        }

        do_pin( player, spec );
        return;   // trigger is deleted by do_pin - nothing left to run
    }
}

// self = the pin trigger. Charged already; lock the (perk, pad) pair for good.
function do_pin( player, spec )
{
    level.acc_scatter_pinned[ spec ] = true;

    pad_idx = level.acc_scatter_where[ spec ];
    disp = "its current home";
    if ( isdefined( pad_idx ) && isdefined( level.acc_scatter_pads[ pad_idx ] ) )
    {
        level.acc_scatter_pads[ pad_idx ].locked_spec = spec;
        disp = level.acc_scatter_pads[ pad_idx ].disp;
    }

    player PlaySound( "evt_bottle_dispense" );
    // Lock-in flair (2026-07-25, with the swap presentation): one de-rez burst on the
    // machine as the pin lands - the "this one is yours now" punctuation.
    if ( isdefined( pad_idx ) && isdefined( level.acc_scatter_pads[ pad_idx ] ) )
        acc_utility::derez_burst( level.acc_scatter_pads[ pad_idx ].origin + ( 0, 0, ACC_SCATTER_FX_Z ), "glitch" );
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
            players[ i ] IPrintLnBold( "^5" + acc_mega_bottles::mega_hint_name( spec ) + "^7 locked at " + disp + " for the rest of the game" );
    }
    acc_utility::log( "perk_scatter: " + spec + " PINNED at " + disp + " (" + ACC_SCATTER_PIN_COST + " mega bottles)" );

    level notify( "acc_perk_pinned", spec );

    self Delete();   // frees the ent; pin_visibility ends via its endon("death")
}
