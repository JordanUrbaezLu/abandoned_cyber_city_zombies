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
#using scripts\zm\_zm_spawner;

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

// "Second part" footprint (gen_descent_hub.js): the long hallway + open-air plaza BELOW the abyss,
// reached through the L5 south doorway. It is NOT a trench layer (no per-layer amping), but it IS below
// every player_volume, so it needs the SAME stock OOB-kill veto. Box: deep (feet below ACC_SP_Z), within
// x[ACC_SP_X1,ACC_SP_X2] and y[ACC_SP_Y1, ACC_SP_Y2) - the y upper bound is EXCLUSIVE and sits just below
// the L5 slab (y>=1723) so the abyss bottom stays a normal trench layer. Covers the plaza (x[-1020,1020]
// y[-2220,-580]) + the hallway (x[-116,116] y[-580,1703]) + margin.
#define ACC_SP_X1                   -1100
#define ACC_SP_X2                   1100
#define ACC_SP_Y1                   -2300
#define ACC_SP_Y2                   1723
#define ACC_SP_Z                    -1000

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

// ---------------------------------------------------------------------------
// Anti-camp BRIDGE drain (user 2026-06-25; RETARGETED to the real bridge 2026-06-26). The "2x-jump-only" corp
// trench BRIDGE (the .map "corp trench BRIDGE" slab / bridge_v2.js) is an ELEVATED deck at the TOP of the map -
// x[-109,147], y[1723,2173], deck top z=+58 (ABOVE ground z=0) - reachable ONLY with the double-jump item.
// Zombies can't get up there, so it's a free safe-camp (it also carries the two power levers). Punish CAMPING.
//
// >>> THE BUG (user 2026-06-26): the box was pointed at the ABYSS connector (gen_abyss_layer.js chunk C, z=-240)
// - DOWN IN THE PIT, coplanar with the trench floor - so it bled players in the TRENCH and never touched the
// real bridge. Wrong structure entirely (~300u too low). FIX: the bridge deck is z=+58 (above ground) and the
// whole trench/abyss is NEGATIVE z (below ground), so a Z window ABOVE GROUND (z_min 50 > 0) catches ONLY the
// elevated deck and excludes the entire trench by height - exactly "only above ground, the trench is under".
// origin[2] IS feet z. The dwell gate (below) still spares brief lever-flip / crossing visits.
// ---------------------------------------------------------------------------
#define ACC_BRIDGE_X1               -109   // the .map "corp trench BRIDGE" slab footprint (bridge_v2.js):
#define ACC_BRIDGE_X2               147    // x[-109,147], y[1723,2173], deck top z=58 (the 2x-jump gate).
#define ACC_BRIDGE_Y1               1723
#define ACC_BRIDGE_Y2               2173
#define ACC_BRIDGE_Z_MIN            50     // ~8u below the z=58 deck top (feet jitter, user 2026-06-26). >0 = ABOVE
                                            // GROUND: the trench/abyss is all NEGATIVE z, so this one bound excludes
                                            // ALL of it (the old -241 box sat IN the pit = the whole bug).
#define ACC_BRIDGE_Z_MAX            178    // deck 58 + ~120 headroom: catches a camper bunny-hopping on the deck;
                                            // the bus-station ground (z=0) is below z_min so normal play is clear.
#define ACC_BRIDGE_DRAIN_PCT        15     // % of MAX health per tick (user 2026-06-25)
#define ACC_BRIDGE_DRAIN_SEC        1.0    // tick interval = "every second"
// GRACE DWELL (user 2026-06-26): the bridge carries the two power levers AND is the 2x-jump crossing, so players
// legitimately visit it briefly. Only punish CAMPING - the bleed starts after you've stayed on the deck past
// this many seconds, and resets the instant you step off. Live dvar acc_bridge_dwell_sec.
#define ACC_BRIDGE_DWELL_SEC        2.0

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
    level thread trench_zombie_census(); // TEMP diag: census of zombies near a player in the pit
    level thread trench_melee_window_logger(); // TEMP diag: dense per-zombie melee-window trace
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
    // Same veto for the "second part" hallway/plaza below the abyss (it is below every player_volume too).
    if ( player_in_second_part( self ) )
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
        player thread bridge_drain_watcher();   // anti-camp: bleed health on the zombie-unreachable bridge
        player thread trench_damage_logger();   // TEMP: name the exact cause of any trench death
        player thread trench_player_navlog();   // TEMP diag: log player nav state while underground
    }
}

// TEMP DIAGNOSTIC (acc_trench_dbg, default 0 - set 1 to re-enable) - log the EXACT damage that hits a player
// WHILE in the trench: amount, means-of-death (MOD_MELEE = zombies, MOD_FALLING = floor/
// void), and what dealt it. So a death names its own cause instead of us guessing. The
// player "damage" notify is the stock player-damage signal (5th arg = MOD).
function trench_damage_logger()   // self = player
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "damage", amount, attacker, dir, point, mod );

        if ( getdvarint( "acc_trench_dbg", 0 ) != 1 ) continue;
        if ( !player_in_trench( self ) ) continue;

        who = "world/self";
        if ( isdefined( attacker ) && attacker != self )
        {
            if ( isdefined( attacker.classname ) ) who = attacker.classname;
            else who = "ent";
        }
        m = ( isdefined( mod ) ? mod : "?" );
        // Where did the HITTER come from? acc_trench_zombie => it erupted in the pit (surge); else it
        // spawned ABOVE and walked down (user 2026-06-22 wants to know which). acc_spawn_origin = its spot.
        kind = ( isdefined( attacker ) && IS_TRUE( attacker.acc_trench_zombie ) ? "SURGE/pit" : "walk/above" );
        sp   = ( isdefined( attacker ) && isdefined( attacker.acc_spawn_origin ) ? ( "" + attacker.acc_spawn_origin ) : "?" );
        ao   = ( isdefined( attacker ) ? ( "" + attacker.origin ) : "?" );
        self IPrintLnBold( "^1[acctr] HIT " + amount + "  " + m + "  by " + who + "  spawnKind=" + kind +
                           "  spawnOrg=" + sp + "  atkOrg=" + ao + "  hp=" + int( self.health ) + "  z=" + int( self.origin[ 2 ] ) );
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

            // ERUPTION on descending to a new DEEPER Abyss layer (user 2026-06-22: "add spawns at the lower
            // layers"). spawn_corp_surge spawns at whatever layer each player is on, so this bursts the layer
            // you just dropped into. Surface->pit (layer 0->1) is handled by the fresh-entry block below; this
            // covers pit->L2->L3->... Cooldown-shared with the entry surge so quick descents don't spam.
            if ( layer > prev_layer && layer >= 2 && !trench_vanilla() &&
                 getdvarint( "acc_trench_surge_on", 1 ) == 1 &&
                 ( !isdefined( self.acc_trench_surge_cd ) || GetTime() >= self.acc_trench_surge_cd ) )
            {
                self.acc_trench_surge_cd = GetTime() + ( getdvarint( "acc_trench_surge_cd_sec", 8 ) * 1000 );
                level thread spawn_corp_surge( getdvarint( "acc_trench_surge_count", 5 ) );
            }

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
            if ( !trench_vanilla() && getdvarint( "acc_trench_surge_on", 1 ) == 1 &&
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

        // TEMP DIAGNOSTIC (acc_trench_dbg, default 0 - set 1 to re-enable) - find out WHAT kills a player in
        // the trench. Live HP+Z readout (updates in place ~5x/s); an IMMEDIATE alert if z
        // drops below the floor (trench floor is -288, so z < -300 = fell THROUGH into the
        // void = instant death the fall-damage dvar can't stop). Remove once confirmed.
        if ( getdvarint( "acc_trench_dbg", 0 ) == 1 )
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
    // Paradise (the second part) is excluded from underground_layer (so it gets NO per-layer amping/slow),
    // but it STILL needs the spawn pressure or the horde dies out down there (user 2026-06-25). So count it
    // as "in the trench" for the surge / AI-pressure path. The amping reads underground_layer directly, which
    // stays 0 in Paradise - so this adds spawns there WITHOUT adding the per-layer amping.
    return player_in_underground( player ) || player_in_second_part( player );
}

// The whole underground sub-level (the trench pit + the rooms + the Hall/Chamber floor)
// below the lip. This IS the trench danger zone now - player_in_trench aliases it, so every
// trench effect AND the OOB-kill veto use it. The rooms are no longer a respite (user 2026-06-18).
function player_in_underground( player )
{
    return underground_layer( player.origin ) > 0;
}

// The "second part" hallway/plaza below the abyss (gen_descent_hub.js). Used by the OOB-kill veto (so
// standing there is safe) and excluded from underground_layer (so it is NOT an amped trench layer). Takes a
// raw origin so it works for any entity. y upper bound is EXCLUSIVE (sits just below the L5 slab y>=1723).
function origin_in_second_part( origin )
{
    if ( origin[ 2 ] >= ACC_SP_Z ) return false;
    if ( origin[ 0 ] < ACC_SP_X1 || origin[ 0 ] > ACC_SP_X2 ) return false;
    if ( origin[ 1 ] < ACC_SP_Y1 || origin[ 1 ] >= ACC_SP_Y2 ) return false;
    return true;
}

function player_in_second_part( player )
{
    return origin_in_second_part( player.origin );
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
    // The "second part" (hallway + open-air plaza, gen_descent_hub.js) is NOT a trench layer - exclude it
    // so no per-layer amping/slow applies there (it has its own rules; structure-first, user 2026-06-24).
    if ( origin_in_second_part( origin ) ) return 0;
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
    if ( trench_vanilla() ) return n_damage;   // VANILLA TEST: no per-layer melee scaling
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
// Anti-camp BRIDGE drain (user 2026-06-25). See the ACC_BRIDGE_* defines above for the
// verified-safe detection volume + rationale.
// ---------------------------------------------------------------------------

// True when the player is standing on (or bunny-hopping just above) the zombie-unreachable
// elevated 2x-jump bridge deck (z=58). XY box + a Z window (origin[2] = feet z) that sits
// ABOVE GROUND (z 50..178): the trench/abyss is all negative z, so it is excluded by height -
// the whole point of the 2026-06-26 retarget (the box used to sit at z=-240, down in the pit).
function player_on_bridge( player )
{
    o = player.origin;
    if ( o[ 0 ] < ACC_BRIDGE_X1 || o[ 0 ] > ACC_BRIDGE_X2 ) return false;
    if ( o[ 1 ] < ACC_BRIDGE_Y1 || o[ 1 ] > ACC_BRIDGE_Y2 ) return false;
    if ( o[ 2 ] < ACC_BRIDGE_Z_MIN || o[ 2 ] > ACC_BRIDGE_Z_MAX ) return false;
    return true;
}

// Per-player: while standing on the zombie-unreachable bridge, bleed a % of MAX health every
// second so camping there is never worth it. MOD_UNKNOWN so NO perk negates it - we deliberately
// do NOT want PhD Flopper (which zeroes MOD_FALLING, see _acc_perk_phd_flopper) to make the camp
// free. Stops cleanly when downed/invalid (is_player_valid skips this tick, resumes on revive);
// DoDamage routes through the stock laststand pipeline if the bleed ever downs you. Gated by
// acc_bridge_drain_on (default 1); pct + interval are live dvars.
function bridge_drain_watcher()   // self = player
{
    self endon( "disconnect" );
    level endon( "end_game" );

    dwell = 0;   // seconds CONTINUOUSLY on the bridge strip; reset the instant you step off (so crossing is free)
    for ( ;; )
    {
        tick = getdvarfloat( "acc_bridge_drain_sec", ACC_BRIDGE_DRAIN_SEC );
        wait( tick );

        if ( getdvarint( "acc_bridge_drain_on", 1 ) != 1 ) { dwell = 0; continue; }
        if ( !zm_utility::is_player_valid( self ) ) { dwell = 0; continue; }
        if ( !player_on_bridge( self ) ) { dwell = 0; continue; }   // off the strip -> reset; passing through never bleeds

        dwell += tick;

        // The bridge IS the trench's only west<->east connector (coplanar z=-240, see the ACC_BRIDGE_DWELL_SEC
        // note) - so a player CROSSING the trench is standing on it too, and z can't tell them apart. Only punish
        // CAMPING: bleed once you've dwelled past acc_bridge_dwell_sec, with a one-tick heads-up first. The reset
        // above clears the counter the moment you move off, so traversal (and a brief stand) never bleeds.
        dwell_max = getdvarfloat( "acc_bridge_dwell_sec", ACC_BRIDGE_DWELL_SEC );
        if ( dwell < dwell_max )
        {
            if ( dwell >= dwell_max - tick )   // one-tick warning before the first bleed
                self IPrintLnBold( "^1GET OFF THE BRIDGE - the zombies can't reach you here" );
            continue;
        }

        if ( !isdefined( self.maxhealth ) || self.maxhealth <= 0 ) continue;
        pct = getdvarint( "acc_bridge_drain_pct", ACC_BRIDGE_DRAIN_PCT );
        dmg = int( self.maxhealth * pct / 100 );
        if ( dmg < 1 ) dmg = 1;
        self DoDamage( dmg, self.origin, self, self, 0, "MOD_UNKNOWN" );

        // Qualitative warning only (no magnitudes - memory vague-ui-no-magnitudes). IPrintLnBold REPLACES the
        // previous bold line, so a 1/s refresh doesn't stack - it just tells the player WHY they're bleeding.
        self IPrintLnBold( "^1GET OFF THE BRIDGE - the zombies can't reach you here" );
    }
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
        if ( !trench_vanilla() && getdvarint( "acc_trench_surge_on", 1 ) == 1 )   // VANILLA TEST: no AI-cap bump / drip
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

// *** VANILLA TEST MODE (user 2026-06-22). ***  acc_trench_vanilla 1 makes trench zombies LITERALLY
// identical to above-ground zombies: NO force-spawn (surge/drip), NO AI-cap bump, NO per-layer
// speed/health, NO per-layer melee scaling, NO trench tags. The ONLY thing kept is the out-of-bounds
// kill veto (player_in_underground) - mandatory, or stock ZM hard-kills the player standing in the pit.
// Purpose: isolate whether OUR trench pipeline is what breaks pit-zombie melee. If, with this ON, zombies
// in the pit DO melee (they'll all be ordinary walk-down zombies), the culprit is our pipeline and we
// bisect; if they STILL don't, it's something deeper than our customizations. Set 0 to restore the full
// trench. Default 1 while we diagnose.
function trench_vanilla()
{
    return getdvarint( "acc_trench_vanilla", 0 ) == 1;   // default 0: full trench WITH the melee-lockout fix; set 1 to strip all trench customization (bisect)
}

function spawn_corp_surge( n )
{
    level endon( "end_game" );

    if ( trench_vanilla() ) return;   // VANILLA TEST: no force-spawn at all

    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
        return;

    // *** PIT ERUPTION RESTORED (user 2026-06-22). *** Background: zombies spawned IN the pit couldn't
    // melee while walk-down ones could, because the 2026-06-21 Abyss well carve had fragmented the
    // pit-floor navmesh - the risers sat on no-navmesh floor and the risen zombie was OFF-MESH (drifts,
    // never enters the melee state). do_zombie_rise places the zombie at the raw riser with NO navmesh
    // registration, so the spot MUST be on a real navmesh poly. FIX: reverted the Abyss carve
    // (gen_abyss_layer.js --revert) so the pit floor is ONE single full-width slab again (the geometry
    // that meshed + meleed when the surge shipped), then a FULL cod2map64 bake regenerated the navmesh
    // over it. So pit eruption is the DEFAULT again (acc_trench_surge_from_pit 1): the surge erupts from
    // the pit-floor risers and the risen zombies are on-mesh -> they melee. Set 0 to fall back to spawning
    // at the corp spawners (path-in) if the floor ever loses its mesh again. (The Abyss L2-L5 descent was
    // removed by the revert - it must be re-added OFF the open pit floor, not as a hole in it.)
    // Spawn at the LAYER(S) players are actually standing on, so descending POPULATES each layer
    // (user 2026-06-22: "add spawns at the lower layers"). Collect the layer of every player currently in
    // the trench (dups OK - they round-robin into proportionally more spawns where more players are).
    // get_layer_risers() returns the L1 map pit risers for layer 1 and computed floor risers for Abyss
    // layers 2-5. Each spawned zombie gets the same low-payout flag + emergence fix as the pit surge, so it
    // melees on whatever layer it erupts on.
    layers = [];
    foreach ( p in GetPlayers() )
    {
        if ( isdefined( p ) && isalive( p ) && player_in_trench( p ) )
        {
            if ( player_in_second_part( p ) )
                L = 0;   // 0 = PARADISE sentinel (Paradise zombies erupt at get_paradise_risers, user 2026-06-25)
            else
            {
                L = underground_layer( p.origin );
                if ( L < 1 ) L = 1;
            }
            layers[ layers.size ] = L;
        }
    }
    if ( layers.size == 0 ) layers[ 0 ] = 1;   // fallback: the pit

    spawned = 0;
    for ( i = 0; i < n; i++ )
    {
        loc = undefined;
        layer = layers[ i % layers.size ];
        risers = ( layer == 0 ? get_paradise_risers() : get_layer_risers( layer ) );   // 0 = Paradise
        spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];
        // L1 can fall back to the corp spawners (path-in) if acc_trench_surge_from_pit 0; deeper layers AND
        // Paradise (layer 0) ALWAYS use their computed risers (corp spawners are topside - no path down).
        use_risers = ( isdefined( risers ) && risers.size > 0 &&
                       ( layer != 1 || getdvarint( "acc_trench_surge_from_pit", 1 ) == 1 ) );
        z = undefined;
        if ( use_risers )
        {
            loc = risers[ acc_utility::acc_rand_int( risers.size ) ];
            z = zombie_utility::spawn_zombie( spawner, undefined, loc );
        }
        else
        {
            z = zombie_utility::spawn_zombie( spawner );
        }
        if ( isdefined( z ) )
        {
            z.acc_trench_zombie = true;     // flat low payout on kill (_acc_points::on_zombie_death)
            z.acc_spawn_origin = ( isdefined( loc ) ? loc.origin : z.origin ); // TEMP diag: where it erupted
            z thread tag_trench_zombie();   // low-payout flag + emergence fix (melee on any layer)
            z thread debug_surge_navmesh(); // TEMP diag: print on-mesh/enemy state (acc_trench_dbg)
            spawned++;
        }
        wait 0.15;   // small stagger so the burst doesn't pop the same frame
    }
    acc_utility::log( "trench surge: spawned " + spawned + "/" + n + " across " + layers.size + " layer-slot(s)" );
}

// Mark a surge-spawned zombie so it does NOT count toward the round and pays out tiny on
// kill (user 2026-06-18: the pit horde is a THREAT, not a farm). ignore_enemy_count is the
// stock "skip me in the round enemy count" field (margwa.gsc:866 / mechz.gsc:953 precedent,
// read at _zm_utility.gsc:105). Set it AFTER zombie_init_done so the generic spawn-init can't
// clear it. The .acc_trench_zombie flag drives the 10-pt payout in _acc_points::on_zombie_death.
// =============================================================================
// TRENCH-MELEE DIAGNOSTIC SUITE (user 2026-06-22). The bug ("zombies that spawn IN the pit never hit me,
// walk-down ones do") survived a single-slab pit floor + a full navmesh bake, ruling OUT the carve theory.
// So we LOG the runtime truth and read console_mp.log after a play session instead of guessing. All lines
// are tagged "[acctr]" (grep the log). Gated by acc_trench_dbg (default 0 - set 1 to re-enable). IPrintLnBold routes to
// console_mp.log as "[ SCRIPTER] [acctr]..." (run_game.ps1 launches with +set logfile 1). Remove this whole
// suite once the cause is found. The four streams: RISER (spawn-point mesh), SURGE# (per-zombie lifecycle),
// PLAYER (your mesh state in the pit), CENSUS (zombies near you: on-mesh? in melee range? surge vs walk-down).
// =============================================================================

// Host-only console logger (avoid coop screen-spam xN). Read after play: grep console_mp.log for "[acctr]".
function tlog( msg )
{
    if ( getdvarint( "acc_trench_dbg", 0 ) != 1 ) return;
    if ( !isdefined( level.players ) || level.players.size == 0 ) return;
    p = level.players[ 0 ];
    if ( isdefined( p ) ) p IPrintLnBold( "[acctr] " + msg );
}

// Per pit-spawned zombie: sample its nav/enemy/range state every 1s for 8s, so we see whether it is ever
// on-mesh, ever targets the player, and whether dist closes to melee range (<=72). self = the surge zombie.
function debug_surge_navmesh()
{
    self endon( "death" );
    if ( getdvarint( "acc_trench_dbg", 0 ) != 1 ) return;
    id = acc_utility::acc_rand_int( 1000 );
    tlog( "SURGE#" + id + " SPAWNED at " + self.origin );
    for ( s = 0; s < 8; s++ )
    {
        wait 1.0;
        if ( !isdefined( self ) || !isalive( self ) ) { tlog( "SURGE#" + id + " gone@t" + s ); return; }
        z_on  = IsPointOnNavMesh( self.origin, self );
        e     = self.favoriteenemy;
        has_e = ( isdefined( e ) && isplayer( e ) );
        p     = acc_utility::get_closest_player_to( self.origin );
        p_on  = ( isdefined( p ) ? IsPointOnNavMesh( p.origin, self ) : false );
        dist  = ( isdefined( p ) ? int( Distance( self.origin, p.origin ) ) : -1 );
        gait  = ( isdefined( self.zombie_move_speed ) ? self.zombie_move_speed : "?" );
        tlog( "SURGE#" + id + " t" + s + " zOnMesh=" + ( z_on ? "Y" : "N" ) + " playerOnMesh=" + ( p_on ? "Y" : "N" ) +
              " enemy=" + ( has_e ? "Y" : "N" ) + " dist=" + dist + " gait=" + gait + " z=" + int( self.origin[ 2 ] ) );
    }
}

// Per player: while underground, log YOUR nav state every 2s. If playerOnMesh=N, NO zombie can get a melee
// node next to you (explains "nothing hits me" regardless of how zombies spawn). self = player.
function trench_player_navlog()
{
    self endon( "disconnect" );
    for ( ;; )
    {
        wait 2.0;
        if ( getdvarint( "acc_trench_dbg", 0 ) != 1 ) continue;
        if ( !player_in_underground( self ) ) continue;
        on = IsPointOnNavMesh( self.origin, 16 );
        tlog( "PLAYER onMesh=" + ( on ? "Y" : "N" ) + " z=" + int( self.origin[ 2 ] ) + " org=" + self.origin +
              " layer=" + underground_layer( self.origin ) );
    }
}

// Census of zombies near a player in the pit every 2s: how many are within 250u, how many ON-mesh, how many
// in melee range (<=72), and the surge (rise-spawned) vs walk-down split. The key comparison: if walk-down
// zombies are onMesh+inMelee but surge ones aren't, the cause is the rise-spawn placement; if NEITHER is
// on-mesh near you, the pit floor itself has no navmesh; if both are on-mesh+in-range yet you said no hits,
// it's a melee-state/AI issue.
function trench_zombie_census()
{
    level endon( "end_game" );
    for ( ;; )
    {
        wait 2.0;
        if ( getdvarint( "acc_trench_dbg", 0 ) != 1 ) continue;
        p = undefined;
        foreach ( pl in GetPlayers() )
            if ( isalive( pl ) && player_in_underground( pl ) ) { p = pl; break; }
        if ( !isdefined( p ) ) continue;
        team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
        zs = GetAITeamArray( team );
        near = 0; nearon = 0; inmelee = 0; surge_near = 0; surge_on = 0; walk_near = 0; walk_on = 0;
        for ( i = 0; i < zs.size; i++ )
        {
            z = zs[ i ];
            if ( !isdefined( z ) || !isalive( z ) ) continue;
            d = Distance( z.origin, p.origin );
            if ( d > 250 ) continue;
            near++;
            zon = IsPointOnNavMesh( z.origin, z );
            if ( zon ) nearon++;
            if ( d <= 72 ) inmelee++;
            if ( IS_TRUE( z.acc_trench_zombie ) ) { surge_near++; if ( zon ) surge_on++; }
            else { walk_near++; if ( zon ) walk_on++; }
        }
        tlog( "CENSUS near=" + near + " onMesh=" + nearon + " inMeleeRange=" + inmelee +
              " | surgeNear=" + surge_near + " surgeOnMesh=" + surge_on +
              " | walkNear=" + walk_near + " walkOnMesh=" + walk_on + " playerZ=" + int( p.origin[ 2 ] ) );
    }
}

// DENSE melee-window trace (every 0.4s): for EVERY zombie within 96u of an underground player, log how far
// it moved since last tick (zMoved ~0 = stopped = attacking-or-stuck; >12 = circling/not committing), its
// dist, surge-vs-walk, enemy, on-mesh, AND the player's own movement (pMoved = were you kiting?). The whole
// point: a zombie that is onMesh=Y enemy=Y dist<=72 zMoved~0 for several ticks but produces NO "[acctr] HIT"
// line = its melee attack is firing-but-not-landing (a melee-state/notetrack issue), the smoking gun for
// "in my face but never hurts me." If instead in-range zombies keep zMoved>12 (orbiting), they never commit.
function trench_melee_window_logger()
{
    level endon( "end_game" );
    prev_p = undefined;
    for ( ;; )
    {
        wait 0.4;
        if ( getdvarint( "acc_trench_dbg", 0 ) != 1 ) { prev_p = undefined; continue; }
        p = undefined;
        foreach ( pl in GetPlayers() )
            if ( isalive( pl ) && player_in_underground( pl ) ) { p = pl; break; }
        if ( !isdefined( p ) ) { prev_p = undefined; continue; }
        pmoved = ( isdefined( prev_p ) ? int( Distance( p.origin, prev_p ) ) : -1 );
        prev_p = p.origin;
        team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
        zs = GetAITeamArray( team );
        for ( i = 0; i < zs.size; i++ )
        {
            z = zs[ i ];
            if ( !isdefined( z ) || !isalive( z ) ) continue;
            d = Distance( z.origin, p.origin );
            if ( d > 96 ) { z.acc_last_org = z.origin; continue; }
            zmoved = ( isdefined( z.acc_last_org ) ? int( Distance( z.origin, z.acc_last_org ) ) : -1 );
            z.acc_last_org = z.origin;
            e = z.favoriteenemy;
            tlog( "MWIN " + ( IS_TRUE( z.acc_trench_zombie ) ? "surge" : "walk " ) + " dist=" + int( d ) +
                  " zMoved=" + zmoved + " pMoved=" + pmoved + " enemy=" + ( ( isdefined( e ) && isplayer( e ) ) ? "Y" : "N" ) +
                  " onMesh=" + ( IsPointOnNavMesh( z.origin, z ) ? "Y" : "N" ) );
        }
    }
}

function tag_trench_zombie()   // self = the surge-spawned zombie
{
    self endon( "death" );
    while ( !isdefined( self.zombie_init_done ) )
        util::wait_network_frame();
    self.acc_trench_zombie  = true;   // low-payout flag (_acc_points::on_zombie_death); AI-inert.

    // *** ROUND-COUNT EXCLUSION - RE-ADDED self.ignore_enemy_count (user 2026-06-22: "trench zombies keep
    // spawning + the round NEVER ENDS; they shouldn't count toward the round"). *** I earlier removed this
    // thinking it broke pit-zombie melee - that was WRONG. The real melee blocker is the emergence gate
    // (fixed right below); ignore_enemy_count is read in ONLY two pure COUNT loops (zombie_utility.gsc:2031
    // get_round_enemy_array + _zm_utility.gsc:105) and does NOT touch .enemy / pathing / the melee gate. With
    // it set, surge zombies are excluded from get_current_zombie_count(), so the round-over check
    // (_zm.gsc:4733) AND the spawn loop (_zm.gsc:3735) ignore them entirely: normal round zombies keep
    // spawning and the round ENDS on the normal horde, while the pit horde is a separate relentless threat
    // that never gates the round - exactly the intended design. Safe + precedented: margwa/mechz set this
    // SAME flag while attacking fine, and our surge zombies (when tagged) already pathed + stood in melee
    // range in the early logs (they only failed to SWING, which the emergence fix now cures). Dvar A/B:
    // acc_trench_no_count 0 makes them count again (restores the bug) for comparison.
    if ( getdvarint( "acc_trench_no_count", 1 ) == 1 )
        self.ignore_enemy_count = true;

    // *** THE ACTUAL MELEE-LOCKOUT FIX (user 2026-06-22, 7-agent workflow-confirmed, stock precedent
    // raz.gsc:516-528). *** The pit risers emerge the zombie at z=-240, which is BELOW the corp_zone
    // player_volume (z[-16,400]). The stock zombie behavior tree only enters its MELEE branch when the
    // engine condition inPlayableArea() is true (_zm_behavior.gsc:1118-1126), and that returns true ONLY
    // when self.completed_emerging_into_playable_area is set. That flag is normally set when the zombie
    // IsTouching a "player_volume" (zombieEnteredPlayable / zombie_entered_playable). A walk-down zombie
    // emerges INSIDE the volume so it gets the flag for free and melees; our pit zombie at z=-240 never
    // touches any player_volume, so the flag stays unset, inPlayableArea() stays false, and the zombie is
    // permanently locked in the NON-playable branch (find-flesh chase/taunt only - NO melee action, and
    // the engine .enemy the melee gate reads is never assigned). That is EXACTLY why it chased + stood in
    // our face (favoriteenemy=Y in the logs) yet logged 0 MOD_MELEE. (This is the SAME geometry mismatch
    // that caused the trench OOB-kill - the pit sits below the zone volume.) Fix: force-complete emergence
    // like the round path, after the rise finishes (bounded wait so a missed "risen" can't deadlock).
    // No-op when a surge zombie ever spawns at a corp spawner instead of the pit (already emerged).
    if ( !IS_TRUE( self.completed_emerging_into_playable_area ) )
    {
        if ( IS_TRUE( self.in_the_ground ) )
            self util::waittill_notify_or_timeout( "risen", 5 );
        if ( !IS_TRUE( self.completed_emerging_into_playable_area ) )
            self zm_spawner::zombie_complete_emerging_into_playable_area();
    }
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

    snap_on = ( getdvarint( "acc_trench_riser_navsnap", 1 ) == 1 );
    r = getdvarint( "acc_trench_riser_navsnap_radius", 128 ); // < the ~240u gap to the surface
    for ( i = 0; i < risers.size; i++ )
    {
        o = risers[ i ].origin;
        raw_on  = IsPointOnNavMesh( o, 16 );                 // is the RAW z=-240 riser on the (baked) navmesh?
        snapped = GetClosestPointOnNavMesh( o, r, 16 );
        used    = false;
        if ( snap_on && isdefined( snapped ) && snapped[ 2 ] <= o[ 2 ] + 16 ) // accept only a DOWN snap
        {
            risers[ i ].origin = snapped;
            used = true;
        }
        // DIAG (acc_trench_dbg): tells us if the pit-floor risers are actually on the navmesh after the bake.
        tlog( "RISER " + i + " raw=" + o + " rawOnMesh=" + ( raw_on ? "Y" : "N" ) +
              " snap=" + ( isdefined( snapped ) ? ( "" + snapped + " dz=" + int( snapped[ 2 ] - o[ 2 ] ) ) : "NONE" ) +
              " usedSnap=" + ( used ? "Y" : "N" ) );
    }

    level.acc_trench_risers = risers;
    return level.acc_trench_risers;
}

// Riser spots for an ARBITRARY trench layer (user 2026-06-22: "add spawns at the lower layers"). Layer 1 =
// the deliberate map pit risers (get_trench_risers, nav-verified). The Abyss layers 2-5 have NO map risers,
// so we COMPUTE 4 synthetic riser structs on that layer's floor (floor top z = -240 - (N-1)*240, matching
// gen_abyss_layer.js floorZ), at x=+-400 / y=1850,2046 - well clear of the center down-well (x[-112,112]) and
// the perimeter, so they land on solid floor. Same recipe as the pit risers (script_noteworthy
// "riser_location" + script_string "find_flesh" => erupt-from-floor via do_zombie_rise), then nav-snapped
// DOWN (small radius + down-guard) so the risen zombie is on-mesh; tag_trench_zombie's emergence fix then
// lets it melee on any layer. Cached per layer.
function get_layer_risers( layer )
{
    if ( !isdefined( layer ) || layer <= 1 )
        return get_trench_risers();   // L1 = the map pit risers

    if ( !isdefined( level.acc_layer_risers ) )
        level.acc_layer_risers = [];
    if ( isdefined( level.acc_layer_risers[ layer ] ) )
        return level.acc_layer_risers[ layer ];

    fz = -240 - ( layer - 1 ) * 240;   // this layer's floor top
    spots = [];
    spots[ 0 ] = ( -400, 1850, fz );
    spots[ 1 ] = (  400, 1850, fz );
    spots[ 2 ] = ( -400, 2046, fz );
    spots[ 3 ] = (  400, 2046, fz );

    snap_on = ( getdvarint( "acc_trench_riser_navsnap", 1 ) == 1 );
    r = getdvarint( "acc_trench_riser_navsnap_radius", 128 );
    risers = [];
    for ( i = 0; i < spots.size; i++ )
    {
        o = spots[ i ];
        s = spawnstruct();
        s.origin = o;
        s.angles = ( 0, 0, 0 );
        s.script_noteworthy = "riser_location";   // erupt from the floor (do_zombie_rise)
        s.script_string = "find_flesh";
        if ( snap_on )
        {
            snapped = GetClosestPointOnNavMesh( o, r, 16 );
            if ( isdefined( snapped ) && snapped[ 2 ] <= o[ 2 ] + 16 )   // accept only a DOWN snap
                s.origin = snapped;
        }
        tlog( "LAYER" + layer + " riser " + i + " o=" + o + " onMesh=" + ( IsPointOnNavMesh( s.origin, 16 ) ? "Y" : "N" ) );
        risers[ risers.size ] = s;
    }
    level.acc_layer_risers[ layer ] = risers;
    return risers;
}

// Riser spots for PARADISE (the second part, gen_descent_hub.js). Paradise is excluded from the abyss
// layers (no per-layer amping), so it has no layer risers - it needs its OWN set or the horde dies out there
// (user 2026-06-25). 6 synthetic risers spread across the plaza floor (z=-1200, interior x[-1000,1000]
// y[-2200,-600]), same recipe as the abyss-layer risers (riser_location + find_flesh, nav-snapped DOWN);
// tag_trench_zombie's emergence fix then lets them melee (Paradise sits below every player_volume, like the
// abyss). Spread clear of the kiosks/perks. Cached.
function get_paradise_risers()
{
    if ( isdefined( level.acc_paradise_risers ) )
        return level.acc_paradise_risers;

    pz = -1200;   // Paradise floor top
    // 12 risers spread across the whole plaza floor (was 6, user 2026-06-25: "add a few more spawns in
    // paradise") so the death-zone horde erupts from EVERYWHERE, not just two rows. 4 rows x 3 columns within
    // the interior x[-1000,1000] y[-2200,-600]; each nav-snapped DOWN below so off-floor picks land on solid floor.
    spots = [];
    spots[ spots.size ] = ( -700,  -700, pz );
    spots[ spots.size ] = (    0,  -700, pz );
    spots[ spots.size ] = (  700,  -700, pz );
    spots[ spots.size ] = ( -700, -1100, pz );
    spots[ spots.size ] = (    0, -1100, pz );
    spots[ spots.size ] = (  700, -1100, pz );
    spots[ spots.size ] = ( -700, -1500, pz );
    spots[ spots.size ] = (    0, -1500, pz );
    spots[ spots.size ] = (  700, -1500, pz );
    spots[ spots.size ] = ( -700, -1900, pz );
    spots[ spots.size ] = (    0, -1900, pz );
    spots[ spots.size ] = (  700, -1900, pz );

    snap_on = ( getdvarint( "acc_trench_riser_navsnap", 1 ) == 1 );
    r = getdvarint( "acc_trench_riser_navsnap_radius", 128 );
    risers = [];
    for ( i = 0; i < spots.size; i++ )
    {
        o = spots[ i ];
        s = spawnstruct();
        s.origin = o;
        s.angles = ( 0, 0, 0 );
        s.script_noteworthy = "riser_location";   // erupt from the floor (do_zombie_rise)
        s.script_string = "find_flesh";
        if ( snap_on )
        {
            snapped = GetClosestPointOnNavMesh( o, r, 16 );
            if ( isdefined( snapped ) && snapped[ 2 ] <= o[ 2 ] + 16 )   // accept only a DOWN snap
                s.origin = snapped;
        }
        tlog( "PARADISE riser " + i + " o=" + o + " onMesh=" + ( IsPointOnNavMesh( s.origin, 16 ) ? "Y" : "N" ) );
        risers[ risers.size ] = s;
    }
    level.acc_paradise_risers = risers;
    return risers;
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
