// =============================================================================
// _acc_bus_trench.gsc - Bus Station (corp_zone) cross-room trench fall tax
//
// Design reference: docs/03_layout.md "Bus Station trench"; geometry SoT
// source_data/rooms.json "trenches".corp; brushes tools/gen_corp_trench.js.
//
// The Bus Station has a horizontal (E-W) trench cut dead-centre. To reach the
// far half you drop in and climb the other side. A thin 96u-wide stair walkway
// crosses it, so you CAN walk down and back up for free; or just jump in (the
// preferred, faster route). Jumping in costs a small fall tax.
//
// The trench floor is -288 (gen_corp_trench.js TRENCH_FLOOR), which is PAST the stock
// bg_fallDamageMinHeight of 256 (_globallogic.gsc:192) - so native engine fall damage
// WOULD apply and could KILL on a jump-in (user 2026-06-18: "died in the trench, not
// from a zombie"). We DISABLE native fall damage map-wide in init() (raise the threshold
// well above any map fall) so the trench's danger comes from the AMPED ZOMBIES, not from
// the drop. The ONLY fall cost is our fixed tax (ACC_TRENCH_FALL_DMG = 25), applied ONLY
// on a FAST entry
// (jumped/fell in with downward velocity past a threshold) - a player who walks
// the stair walkway down keeps near-zero vertical speed and pays nothing. The
// damage uses MOD_FALLING so PhD Flopper's existing damage override negates it
// for free (see _acc_perk_phd_flopper.gsc phd_damage_override - MOD_FALLING -> 0).
//
// ALWAYS ON - no flag/dvar. This is core to the trench; retune via the constant.
//
// Public API:
//   init() - start the per-player fall watcher (call once from acc_main::init())
// =============================================================================

#using scripts\shared\util_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\ai\zombie_utility;
#using scripts\codescripts\struct;

#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#insert scripts\shared\shared.gsh;

// ---------------------------------------------------------------------------
// Trench bounds - MUST match source_data/rooms.json "trenches".corp + the
// baked brushes (tools/gen_corp_trench.js). corp outer x[-781,819].
// ---------------------------------------------------------------------------

#define ACC_TRENCH_X1               -781
#define ACC_TRENCH_X2               819
#define ACC_TRENCH_Y1               1723
#define ACC_TRENCH_Y2               2173

// Underground footprint - the OOB-kill veto must cover the WHOLE sub-level (the trench
// PLUS the 2 trench rooms at z=-240 PLUS any future underground floor), not just the
// trench y-band: a player standing in a room below the corp_zone volume (z[-16,400]) is
// otherwise hard-killed by the stock out-of-playable-area monitor. Generous corp-footprint
// box; nothing else on the map is walkable below z=-36 in this XY region.
#define ACC_UNDER_X1                -900
#define ACC_UNDER_X2                900
#define ACC_UNDER_Y1                -400
#define ACC_UNDER_Y2                2900
#define ACC_UNDER_Z                 -36

// Abyss descent (docs/48): 5 floors straight down on a fixed 240u pitch - L1 floor -240, L2 -480,
// L3 -720, L4 -960, L5 -1200. underground_layer() turns a world z into the layer index (how many
// 240u steps below the lip); the per-layer zombie scaling in _acc_zombie_speed reads it. PITCH is
// a GEOMETRY constant (must match gen_abyss_layer.js), NOT a tuning dvar.
#define ACC_LAYER_PITCH             240
#define ACC_LAYER_MAX               5

// Count a player as "in the trench" once their feet drop this far below the lip
// (z=0). Past the first couple of stairs - so a stair-walker also flags "in",
// but only a FAST entry is taxed (see ACC_TRENCH_FALL_VZ).
#define ACC_TRENCH_TRIGGER_Z        -40

// Downward velocity (u/s) above which the entry counts as a jump/fall, not a
// walk down the stairs. Falling just 40u already gives ~ -253 u/s (sqrt(2*g*h),
// g~800); walking the 16u stairs never approaches this.
#define ACC_TRENCH_FALL_VZ          -200

// Fall-tax damage. A plain constant - this feature is ALWAYS on (no flag/dvar);
// edit this number to retune. ~25 is a light tax that never downs a healthy
// player; PhD Flopper negates it (MOD_FALLING, see apply_fall_tax).
#define ACC_TRENCH_FALL_DMG         25
#define ACC_TRENCH_POLL_SEC         0.05

#namespace acc_bus_trench;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
    // Always enabled (no flag). The fall tax is core to the Bus Station trench.
    acc_utility::log( "bus trench: init (fall tax " + ACC_TRENCH_FALL_DMG + ")" );

    // *** ROOT-CAUSE FIX of "I randomly die in the trench" (2026-06-18) ***
    // The corp_zone player_volume only spans z[-16,400], but the trench floor is z=-240,
    // so a player standing in the trench is BELOW the zone volume. Stock ZM's per-player
    // out-of-playable-area monitor then hard-kills them (_zm.gsc:2064-2100: self.lives=0;
    // dodamage(self.health+1000)) on its ~3s poll - a NO-laststand, HP-still-full, no-MOD,
    // delayed kill = every symptom we saw (and it "worked before" only because the old
    // shallow floor kept the player box inside the -16 volume). The monitor performs the
    // kill ONLY if this callback is undefined OR returns true (_zm.gsc:2066), so we register
    // it and return FALSE for anyone in the trench - vetoing the kill there while the rest of
    // the map stays guarded. Only ONE such callback may exist (verified none other sets it).
    level.player_out_of_playable_area_monitor_callback = &acc_trench_oob_allow;

    level thread disable_native_fall_damage();
    level thread watch_connections();
    level thread trench_ai_pressure();   // raise the zombie cap while ANY player is in the pit
}

// self = player. Stock OOB monitor kills only when this returns true (_zm.gsc:2066). Return
// false while the player is in the trench so being legitimately below the corp_zone volume
// is not treated as "left the map." Everyone/everywhere else keeps the normal OOB guard.
function acc_trench_oob_allow()
{
    // Veto the OOB kill anywhere in the underground footprint (trench + rooms + future
    // floor), not just the trench band - else a player standing in a trench room at
    // z=-240 (outside the band) takes the hard-kill. player_in_underground is a superset.
    if ( player_in_underground( self ) )
        return false;
    return true;
}

// The trench floor (-288) is below the stock 256u native fall-damage threshold, so the
// engine would deal (potentially lethal) fall damage on a jump-in ON TOP of our 25 tax.
// We don't want the trench to kill via the DROP - the danger is the amped zombies. Push
// the threshold above any realistic map fall so native fall damage never triggers; our
// scripted, PhD-negated 25 tax stays the only fall cost. Runs after _globallogic sets
// its 256/512 at match init (_globallogic.gsc:192-193), then overrides.
function disable_native_fall_damage()
{
    level endon( "end_game" );
    wait 1;
    SetDvar( "bg_fallDamageMinHeight", 1024 );
    SetDvar( "bg_fallDamageMaxHeight", 2048 );
    acc_utility::log( "bus trench: native fall damage disabled (min 1024) - trench drop is non-lethal, only the 25 tax applies" );
}

function watch_connections()
{
    level endon( "end_game" );

    for ( ;; )
    {
        // VERIFIED(acc): level notify( "connected", player ) fires per
        // connecting player (gametypes/_globallogic_player.gsc:63). Same hook
        // _acc_weapon_abilities uses.
        level waittill( "connected", player );
        player thread trench_fall_watcher();
        player thread trench_damage_logger();   // TEMP: name the exact cause of any trench death
    }
}

// TEMP DIAGNOSTIC (acc_trench_dbg, default 1) - log the EXACT damage that hits a player
// WHILE in the trench: amount, means-of-death (MOD_MELEE = zombies, MOD_FALLING = floor/
// void), and what dealt it. So a death names its own cause instead of us guessing. The
// player "damage" notify is the stock player-damage signal (5th arg = MOD).
function trench_damage_logger()   // self = player
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "damage", amount, attacker, dir, point, mod );

        if ( getdvarint( "acc_trench_dbg", 1 ) != 1 ) continue;
        if ( !player_in_trench( self ) ) continue;

        who = "world/self";
        if ( isdefined( attacker ) && attacker != self )
        {
            if ( isdefined( attacker.classname ) ) who = attacker.classname;
            else who = "ent";
        }
        m = ( isdefined( mod ) ? mod : "?" );
        self IPrintLnBold( "^1[trench-dbg] HIT " + amount + "  " + m + "  by " + who +
                           "   hp=" + int( self.health ) + "  z=" + int( self.origin[ 2 ] ) );
    }
}

// ---------------------------------------------------------------------------
// Per-player watcher: tax a fast drop into the trench, once per entry.
// ---------------------------------------------------------------------------

function trench_fall_watcher()
{
    self endon( "disconnect" );

    was_inside  = false;
    prev_layer  = 0;   // last trench layer (docs/47): recompute move speed on any depth change
    dbg_tick    = 0;
    dbg_last_hp = self.health;

    for ( ;; )
    {
        wait ACC_TRENCH_POLL_SEC;

        layer  = underground_layer( self.origin );   // 0 = surface, 1..N by depth (docs/47)
        inside = ( layer > 0 );

        // Layered trench slow (docs/47): the move-speed owner reads acc_trench_layer + the player's Exo
        // Suit tier (tier T cancels the slow down to layer T). Track the layer and recompute on ANY depth
        // change - entry, exit, or one layer deeper. (acc_trench_slow boolean kept for active_speed_flags.)
        self.acc_trench_slow = inside;
        if ( layer != prev_layer )
        {
            self.acc_trench_layer = layer;
            acc_utility::recompute_move_speed( self );
            prev_layer = layer;
        }

        // (No fall-through catch-net: the deaths were NEVER fall-throughs - they were the stock
        // out-of-playable-area kill, now vetoed in init() via player_out_of_playable_area_monitor_callback.
        // A z-based catch-net would also FALSE-trigger on a normal stander now the floor is z=-200.)

        // Fresh entry (outside/above -> inside).
        if ( inside && !was_inside )
        {
            // Fast downward entry = a jump/fall, not a stair descent: tax it once.
            if ( zm_utility::is_player_valid( self ) &&
                 ( self GetVelocity()[ 2 ] ) < ACC_TRENCH_FALL_VZ )
            {
                apply_fall_tax( self );
            }
            // (The trench slow is now handled per-poll by the layer tracking above - docs/47.)
            // Danger warning while EXPOSED in the pit (any entry, stairs included).
            if ( getdvarint( "acc_trench_warn", 1 ) == 1 )
            {
                self thread trench_warning_on();
            }
            // SPAWN SURGE (user 2026-06-18: "spawns should go crazy when you enter"). A burst
            // of extra zombies at the active (corp) spawners, on a per-player cooldown so
            // re-entry can't farm it. The AI-cap raise (trench_ai_pressure) gives the headroom;
            // _acc_zombie_speed trench-aggro then beelines/sprints them all at you.
            if ( getdvarint( "acc_trench_surge_on", 1 ) == 1 &&
                 ( !isdefined( self.acc_trench_surge_cd ) || GetTime() >= self.acc_trench_surge_cd ) )
            {
                self.acc_trench_surge_cd = GetTime() + ( getdvarint( "acc_trench_surge_cd_sec", 8 ) * 1000 );
                level thread spawn_corp_surge( getdvarint( "acc_trench_surge_count", 5 ) ); // 6->5: -25% pit aggression (user 2026-06-18)
            }
        }
        else if ( !inside && was_inside )
        {
            self notify( "acc_left_trench" );   // stop the pulse loop
            self trench_warning_off();          // fade the warning out
            // (the slow drop is handled by the per-poll layer tracking above - exiting = layer 0 - docs/47)
        }

        // TEMP DIAGNOSTIC (acc_trench_dbg, default 1) - find out WHAT kills a player in
        // the trench. Live HP+Z readout (updates in place ~5x/s); an IMMEDIATE alert if z
        // drops below the floor (trench floor is -288, so z < -300 = fell THROUGH into the
        // void = instant death the fall-damage dvar can't stop). Remove once confirmed.
        if ( getdvarint( "acc_trench_dbg", 1 ) == 1 )
        {
            hp = int( self.health );
            z  = int( self.origin[ 2 ] );
            if ( inside )
            {
                // Per-tick (0.05s) so a fast death can't slip between heartbeats. An HP drop
                // right before the readout stops = DAMAGE killed you (we'll see the amount);
                // the readout just STOPPING with hp still full = a NON-damage engine/scripted
                // kill for being in an invalid spot (the real signal we're hunting).
                if ( hp < dbg_last_hp )
                    self IPrintLnBold( "^1[trench-dbg] HP -" + ( dbg_last_hp - hp ) + "  now " + hp + "  z=" + z );
                if ( hp <= 0 || IS_TRUE( self.laststand ) )
                    self IPrintLnBold( "^1[trench-dbg] DOWN/DEAD  z=" + z + "  (last hp " + dbg_last_hp + ")" );
                dbg_tick++;
                if ( dbg_tick >= 20 )
                {
                    dbg_tick = 0;
                    self IPrintLnBold( "^3[trench-dbg] alive hp=" + hp + "  z=" + z );
                }
            }
            dbg_last_hp = hp;
        }

        was_inside = inside;
    }
}

// XY inside the trench band AND feet below the trigger depth.
// The WHOLE underground sub-level now counts as "the trench" (user 2026-06-18): the new
// rooms + Hall/Chamber floor ARE part of the trench, so every trench effect (fall-tax /
// -20% slow / spawn surge / danger warning / zombie aggro) applies anywhere down here, not
// just the open pit y-band. So this is just the broad underground footprint now. (The old
// narrow y-band box at ACC_TRENCH_X1..Y2 is kept in the #defines for the SoT comment + the
// fall-tax still only *fires* on a real fast fall, which only happens dropping into the pit.)
function player_in_trench( player )
{
    return player_in_underground( player );
}

// The whole underground sub-level (the trench pit + the rooms + the Hall/Chamber floor)
// below the lip. This IS the trench danger zone now - player_in_trench aliases it, so every
// trench effect AND the OOB-kill veto use it. The rooms are no longer a respite (user 2026-06-18).
function player_in_underground( player )
{
    return underground_layer( player.origin ) > 0;
}

// Which trench LAYER a world position is in: 0 = surface (not underground), 1 = the top trench
// (lip -36 .. floor -240), 2..5 = the deeper Abyss floors (docs/48). The trench goes DEEP in layers
// (user 2026-06-21), each one deadlier - the per-layer zombie scaling (+move / +melee) in
// _acc_zombie_speed reads this. Takes a raw origin so it works for ANY entity (player OR zombie),
// letting the zombie buff gate on the ZOMBIE'S OWN position rather than its target.
//
// The layer = how many ACC_LAYER_PITCH (240u) steps below the lip you are. depth 36..240 = L1,
// 240..480 = L2, ... 960..1200 = L5 (clamped). This is purely depth-based, so a deeper floor's
// zombies scale correctly the instant its geometry lands - no per-layer code edit needed.
function underground_layer( origin )
{
    if ( origin[ 2 ] > ACC_UNDER_Z ) return 0;                                  // above the lip = surface
    if ( origin[ 0 ] < ACC_UNDER_X1 || origin[ 0 ] > ACC_UNDER_X2 ) return 0;
    if ( origin[ 1 ] < ACC_UNDER_Y1 || origin[ 1 ] > ACC_UNDER_Y2 ) return 0;

    depth = 0 - origin[ 2 ];                          // units below z=0 (positive going down)
    layer = int( ( depth - 1 ) / ACC_LAYER_PITCH ) + 1; // -1 epsilon: a floor at exactly -240*N reads as layer N, not N+1
    if ( layer < 1 ) layer = 1;
    if ( layer > ACC_LAYER_MAX ) layer = ACC_LAYER_MAX;
    return layer;
}

// Add to an incoming MELEE hit by the PLAYER'S trench layer: +acc_trench_layer_dmg_add HP per layer
// (user 2026-06-21 - a FLAT add, NOT a %). Returns the (larger) damage; unchanged on the surface.
// THIS is how "zombies hit harder per layer" actually lands: open-field zombie melee deals the engine
// Melee() builtin's WEAPON damage and IGNORES self.meleeDamage, so a per-zombie meleeDamage write
// never shows. Adding to the player's INCOMING damage works regardless of the melee path. Called from
// the player-damage callback (_acc_elites::on_player_damaged). Player's layer == the attacking
// zombie's layer for any melee (they're adjacent). Gated by the same dvars as the speed buff.
function trench_melee_scaled( player, n_damage )
{
    if ( !isdefined( n_damage ) || n_damage <= 0 ) return n_damage;
    if ( getdvarint( "acc_trench_aggro", 1 ) != 1 ) return n_damage;
    if ( getdvarint( "acc_trench_aggro_melee", 1 ) != 1 ) return n_damage;
    layer = underground_layer( player.origin );
    if ( layer <= 0 ) return n_damage;
    return n_damage + ( layer * getdvarint( "acc_trench_layer_dmg_add", 10 ) ); // +10 HP/layer (flat)
}

function apply_fall_tax( player )
{
    // MOD_FALLING routes through the stock player-damage pipeline (so PhD
    // Flopper's level.perk_damage_override negates it - _acc_perk_phd_flopper),
    // and reads as a fall on the HUD. Self as attacker/inflictor mirrors the
    // self-inflicted idiom (PhD's own slide nova does z DoDamage(...,self,self)).
    // 25 never downs a healthy player; if it ever did, it routes to laststand
    // normally (same as decon's DoDamage path, _acc_decontamination).
    player DoDamage( ACC_TRENCH_FALL_DMG, player.origin, player, player, 0, "MOD_FALLING" );
    acc_utility::log_player( player, "bus trench fall tax (" + ACC_TRENCH_FALL_DMG + ")" );
}

// ---------------------------------------------------------------------------
// Spawn pressure - make the pit a kill-box (user 2026-06-18: "a lot more spawns
// in the pit + go crazy on entry"). Two parts:
//   trench_ai_pressure()  - while ANY player is in the trench, RAISE the global
//       zombie AI cap by acc_trench_ai_bonus so the zone can actually hold the
//       extra horde (the cap is the real bottleneck - more risers do nothing once
//       you hit it). Poll-based so it self-corrects on disconnect/down (no leaked
//       bonus). The bonus is added once and removed when the LAST player leaves.
//   spawn_corp_surge()    - an immediate burst of extra zombies on fresh entry
//       (plain spawn_zombie -> the downstream zone system places them in the
//       active = corp zone; precedent _acc_elites::spawn_elite). _acc_zombie_speed
//       trench-aggro then beelines/sprints them at you.
// ---------------------------------------------------------------------------

function trench_ai_pressure()
{
    level endon( "end_game" );

    raised = false;
    base = undefined;
    applied = 0;
    drip_t = 0;

    for ( ;; )
    {
        wait 0.5;

        occupied = false;
        if ( getdvarint( "acc_trench_surge_on", 1 ) == 1 )
        {
            foreach ( p in GetPlayers() )
            {
                if ( isdefined( p ) && isalive( p ) && player_in_trench( p ) )
                {
                    occupied = true;
                    break;
                }
            }
        }

        if ( occupied && !raised && isdefined( level.zombie_ai_limit ) )
        {
            base = level.zombie_ai_limit;
            applied = getdvarint( "acc_trench_ai_bonus", 14 ); // 18->14: -25% pit aggression (user 2026-06-18)
            level.zombie_ai_limit = base + applied;   // live-effective: stock spawn loop reads it each attempt
            raised = true;
        }
        else if ( !occupied && raised )
        {
            // Subtract exactly what we added (robust if coop-scaling moved the base meanwhile).
            level.zombie_ai_limit = level.zombie_ai_limit - applied;
            raised = false;
            applied = 0;
        }

        // CONTINUOUS PIT DRIP (user 2026-06-18: "as fearful as possible"). While you stay
        // in the pit, keep erupting a few more from the floor every acc_trench_drip_sec. The
        // single-in-flight flag (acc_trench_dripping) + the raised AI cap bound it: spawn_zombie
        // blocks when the cap is full, so the pit refills only as fast as you clear it (a
        // treadmill, not a runaway). Leaving the pit (occupied=false) stops it. Dvar-gated.
        if ( occupied && getdvarint( "acc_trench_drip_on", 1 ) == 1 )
        {
            drip_t += 0.5;
            if ( drip_t >= getdvarfloat( "acc_trench_drip_sec", 5.0 ) && !IS_TRUE( level.acc_trench_dripping ) ) // 4->5s: -25% pit aggression (user 2026-06-18)
            {
                drip_t = 0;
                level thread do_trench_drip( getdvarint( "acc_trench_drip_count", 2 ) );
            }
        }
        else
        {
            drip_t = 0;
        }
    }
}

// One pit-drip surge at a time (the flag blocks the pressure loop from stacking drips while
// a previous one is still waiting on AI-cap headroom).
function do_trench_drip( n )
{
    level endon( "end_game" );
    level.acc_trench_dripping = true;
    spawn_corp_surge( n );
    level.acc_trench_dripping = false;
}

function spawn_corp_surge( n )
{
    level endon( "end_game" );

    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
        return;

    // *** ROOT-CAUSE FIX (user 2026-06-21): zombies spawned IN the trench couldn't melee, but ones
    // that spawned above ground and WALKED down could. *** The pit eruption relocates the zombie onto
    // a z=-240 riser via spawn_zombie(spawner, _, riser) -> move_zombie_spawn_location -> do_zombie_rise,
    // with NO navmesh validation. That worked when the pit floor was one clean slab, but the 2026-06-21
    // Abyss well carve fragmented the pit-floor navmesh, so the risers now sit on no-navmesh floor and
    // the risen zombie is OFF-MESH = drifts at you but never enters the melee attack state. Walk-down
    // zombies reach you over the still-meshed stairs/edges, so THEY melee fine.
    //
    // DEFAULT now spawns the surge at the normal, navmesh-VALID corp spawners and lets them path in -
    // the exact proven-working path the walk-down zombies use, so the surge zombies CAN melee. The pit
    // eruption (erupt from the floor) is OPT-IN via acc_trench_surge_from_pit 1 - flip it back on once
    // the pit-floor navmesh is rebuilt/confirmed (single-slab + full bake). The other levers (AI-cap
    // bump, drip cadence, aggro, per-layer scaling) are unchanged; this only changes WHERE they spawn.
    pit = get_trench_risers();
    pit_n = 0;
    if ( isdefined( pit ) )
        pit_n = pit.size;
    use_pit = ( pit_n > 0 && getdvarint( "acc_trench_surge_from_pit", 0 ) == 1 );

    spawned = 0;
    for ( i = 0; i < n; i++ )
    {
        spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];
        z = undefined;
        if ( use_pit )
        {
            loc = pit[ acc_utility::acc_rand_int( pit_n ) ];
            z = zombie_utility::spawn_zombie( spawner, undefined, loc );
        }
        else
        {
            z = zombie_utility::spawn_zombie( spawner );
        }
        if ( isdefined( z ) )
        {
            z.acc_trench_zombie = true;     // flat low payout on kill (_acc_points::on_zombie_death)
            z thread tag_trench_zombie();   // + exclude from the round count, after init
            spawned++;
        }
        wait 0.15;   // small stagger so the burst doesn't pop the same frame
    }
    acc_utility::log( "trench surge: spawned " + spawned + "/" + n + " (pit risers " + pit_n + ")" );
}

// Mark a surge-spawned zombie so it does NOT count toward the round and pays out tiny on
// kill (user 2026-06-18: the pit horde is a THREAT, not a farm). ignore_enemy_count is the
// stock "skip me in the round enemy count" field (margwa.gsc:866 / mechz.gsc:953 precedent,
// read at _zm_utility.gsc:105). Set it AFTER zombie_init_done so the generic spawn-init can't
// clear it. The .acc_trench_zombie flag drives the 10-pt payout in _acc_points::on_zombie_death.
function tag_trench_zombie()   // self = the surge-spawned zombie
{
    self endon( "death" );
    while ( !isdefined( self.zombie_init_done ) )
        util::wait_network_frame();
    self.acc_trench_zombie  = true;
    self.ignore_enemy_count = true;
}

// Cached array of the in-pit riser structs (targetname acc_trench_risers, z=-240, each
// tagged zone_name corp_zone). Surge-only - NOT corp_zone_spawners, so normal corp rounds
// don't fill the empty pit; the pit erupts only when YOU drop in.
//
// NAV-SNAP each riser DOWN onto the pit-floor navmesh (user 2026-06-21 - root cause of "zombies spawned
// IN the trench never hit me, but ones that WALK down do"). Our risers carry script_noteworthy
// "riser_location", so move_zombie_spawn_location routes the spawn through zm_spawner::do_zombie_rise,
// which emerges the zombie AT spot.origin with NO navmesh registration. If that raw point isn't exactly
// on the navmesh, the risen zombie is OFF-MESH - it can drift at you but never enters the melee attack
// state (a walked-down zombie is continuously on-mesh, hence it CAN melee). Fix: snap the riser onto the
// nearest navmesh poly so the risen zombie lands on-mesh.
//
// CRITICAL - this is NOT the earlier clamp that regressed: that one used radius 256 (> the ~240u gap to
// the z=0 surface), so it snapped the risers UP to the surface and the horde erupted topside. THIS snap
// uses a SMALL radius (cannot reach the surface) AND a DOWN-GUARD that rejects any up-snap toward the lip
// (mirrors the stock guard _zm_weap_gravityspikes.gsc:1325). So it can only resolve DOWN onto the pit
// floor, never up. A down-snapped on-mesh point is also correct for the Brutus warden (shares this cache):
// a valid in-pit navmesh point is a better teleport/goal than a raw maybe-off-mesh one. Toggle off with
// acc_trench_riser_navsnap 0 to A/B against raw origins.
function get_trench_risers()
{
    if ( isdefined( level.acc_trench_risers ) )
        return level.acc_trench_risers;

    risers = struct::get_array( "acc_trench_risers", "targetname" );

    if ( getdvarint( "acc_trench_riser_navsnap", 1 ) == 1 )
    {
        r   = getdvarint( "acc_trench_riser_navsnap_radius", 128 ); // < the ~240u gap to the surface
        for ( i = 0; i < risers.size; i++ )
        {
            o = risers[ i ].origin;
            snapped = GetClosestPointOnNavMesh( o, r, 16 );
            // accept ONLY a snap at/below the riser plane (never up to the z=0 surface lip)
            if ( isdefined( snapped ) && snapped[ 2 ] <= o[ 2 ] + 16 )
                risers[ i ].origin = snapped;
        }
    }

    level.acc_trench_risers = risers;
    return level.acc_trench_risers;
}

// ---------------------------------------------------------------------------
// Danger warning - a pulsing red banner + subtle red screen tint while a player
// is EXPOSED in the trench (zombies are amped here, see _acc_zombie_speed trench
// aggro). Gated by dvar acc_trench_warn (default 1). HUD elems are created lazily
// per player, hidden (alpha 0) on exit, reused on re-entry.
// ---------------------------------------------------------------------------

function ensure_trench_warning()   // self = player
{
    if ( isdefined( self.acc_trench_warn_txt ) )
        return;

    // TRUE FULL-SCREEN red tint (behind the text). horzAlign/vertAlign "fullscreen" + a
    // 640x480 "white" shader spans the ENTIRE screen incl. the edges on ANY aspect ratio
    // (stock fullscreen-overlay recipe, _remotemissile.gsc:464-467). A CENTER-anchored
    // fixed-size icon did NOT reach the widescreen edges (user 2026-06-18). Moderate alpha
    // = dread, not a blackout; do NOT setPoint (the fullscreen align is the positioning).
    self.acc_trench_warn_bg = self hud::createIcon( "white", 640, 480 );
    self.acc_trench_warn_bg.horzAlign = "fullscreen";
    self.acc_trench_warn_bg.vertAlign = "fullscreen";
    self.acc_trench_warn_bg.alignX = "left";
    self.acc_trench_warn_bg.alignY = "top";
    self.acc_trench_warn_bg.x = 0;
    self.acc_trench_warn_bg.y = 0;
    self.acc_trench_warn_bg.color  = ( 0.7, 0.0, 0.0 );
    self.acc_trench_warn_bg.alpha  = 0;
    self.acc_trench_warn_bg.sort   = 0;
    self.acc_trench_warn_bg.hidewheninmenu = true;

    // Banner, upper-center (clears the boss bar + dev sign). fontscale 1.4 (>= 1.0:
    // a sub-1.0 fontscale renders oversized on this build - see _acc_boss_items NITRO).
    self.acc_trench_warn_txt = self hud::createFontString( "default", 1.4 );
    self.acc_trench_warn_txt hud::setPoint( "TOP", "TOP", 0, 110 );
    self.acc_trench_warn_txt.alignX = "center";
    self.acc_trench_warn_txt.alignY = "top";
    self.acc_trench_warn_txt.color  = ( 1.0, 0.2, 0.15 );
    self.acc_trench_warn_txt.alpha  = 0;
    self.acc_trench_warn_txt.sort   = 1;
    self.acc_trench_warn_txt.hidewheninmenu = true;
    self.acc_trench_warn_txt SetText( "DANGER  -  EXPOSED IN THE TRENCH" );
}

function trench_warning_on()   // self = player
{
    self endon( "disconnect" );
    self endon( "acc_left_trench" );

    self ensure_trench_warning();

    // SHOW FOR ~4s THEN AUTO-OFF (user 2026-06-18: shorter + less frequent pulse - the old
    // continuous fast pulse was annoying). A slow ~2s pulse cycle (hp up + hp down) over a 4s
    // window = ~2 gentle breaths, then fade out and STOP even if you stay down here. It only
    // comes back on a FRESH entry (exit fires acc_left_trench + off; stepping back in re-threads).
    dur = getdvarfloat( "acc_trench_warn_sec", 4.0 );    // window seconds
    hp  = getdvarfloat( "acc_trench_warn_pulse", 1.0 );  // half-pulse seconds (larger = slower / less frequent)
    elapsed = 0;
    while ( elapsed < dur )
    {
        self.acc_trench_warn_txt fadeovertime( hp );  self.acc_trench_warn_txt.alpha = 0.9;
        self.acc_trench_warn_bg  fadeovertime( hp );  self.acc_trench_warn_bg.alpha  = 0.25;
        wait( hp );  elapsed += hp;
        if ( elapsed >= dur ) break;
        self.acc_trench_warn_txt fadeovertime( hp );  self.acc_trench_warn_txt.alpha = 0.45;
        self.acc_trench_warn_bg  fadeovertime( hp );  self.acc_trench_warn_bg.alpha  = 0.1;
        wait( hp );  elapsed += hp;
    }
    self trench_warning_off();   // fade out after the window; stays off until you re-enter
}

function trench_warning_off()   // self = player
{
    if ( isdefined( self.acc_trench_warn_txt ) )
    {
        self.acc_trench_warn_txt fadeovertime( 0.25 );  self.acc_trench_warn_txt.alpha = 0;
    }
    if ( isdefined( self.acc_trench_warn_bg ) )
    {
        self.acc_trench_warn_bg fadeovertime( 0.25 );  self.acc_trench_warn_bg.alpha = 0;
    }
}
