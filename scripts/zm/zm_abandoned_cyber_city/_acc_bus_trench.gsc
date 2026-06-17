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
// Native engine fall damage can't do this: stock ZM sets bg_fallDamageMinHeight
// 256 / MaxHeight 512 (_globallogic.gsc:192), so a 112u trench deals ZERO. We
// instead apply a fixed tax (ACC_TRENCH_FALL_DMG = 25) ONLY on a FAST entry
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

    level thread watch_connections();
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
    }
}

// ---------------------------------------------------------------------------
// Per-player watcher: tax a fast drop into the trench, once per entry.
// ---------------------------------------------------------------------------

function trench_fall_watcher()
{
    self endon( "disconnect" );

    was_inside = false;

    for ( ;; )
    {
        wait ACC_TRENCH_POLL_SEC;

        inside = player_in_trench( self );

        // Fresh entry (outside/above -> inside) AND moving down fast = a
        // jump/fall, not a stair descent. Tax it once.
        if ( inside && !was_inside )
        {
            if ( zm_utility::is_player_valid( self ) &&
                 ( self GetVelocity()[ 2 ] ) < ACC_TRENCH_FALL_VZ )
            {
                apply_fall_tax( self );
            }
        }

        was_inside = inside;
    }
}

// XY inside the trench band AND feet below the trigger depth.
function player_in_trench( player )
{
    org = player.origin;
    if ( org[ 0 ] < ACC_TRENCH_X1 || org[ 0 ] > ACC_TRENCH_X2 )
    {
        return false;
    }
    if ( org[ 1 ] < ACC_TRENCH_Y1 || org[ 1 ] > ACC_TRENCH_Y2 )
    {
        return false;
    }
    return ( org[ 2 ] < ACC_TRENCH_TRIGGER_Z );
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
