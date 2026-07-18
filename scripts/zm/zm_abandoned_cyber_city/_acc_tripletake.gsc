// =============================================================================
// _acc_tripletake.gsc - TRIPLE TAKE volley rework (user 2026-07-16: "It needs a
// 3 shot projectile like the actual triple take from Apex Legends").
//
// The weapon def is a plain *bulletweapon* with shotCount 1 (v3,
// tools/oneshots/prep_apex_tripletake_gdt.js; the v2 projectileweapon graft was retired -
// the 2026-07-16 kill-timing test PROVED a gdf-class graft does not change the runtime
// firing model: the gun fired HITSCAN with every proj* field inert, and the class cost
// us penetrateType + the falloff fields). Final design: HITSCAN damage (instant, flat
// 500 at any range, pen large, headshot locs), and the VISIBLE "projectile" volley is
// script-owned mover FX (bolt_visual below + _acc_tripletake.csc). A native trigger
// pull deals the CENTER hit and consumes 1 round. This module adds, on every shot:
//
//   - +2 SIDE HITS: MagicBullet() of the HELD weapon object (twin / _up / PaP
//     form included), one left and one right of the aim line - on a hitscan def
//     these are instant bullets along the offset lines. Same weapon object = the
//     native damage pipeline (_acc_damage bal mult, ENERGY class, PaP ladder,
//     Precision Mode crit charges - 3 damage events/trigger, like the old
//     shotCount-3). Spread is a live-tune dvar `acc_ttk_spread_deg` (default
//     4.0 deg/side), applied in the VIEW plane via the right vector so steep
//     up/down shots keep true separation. Player-owned MagicBullet precedent:
//     stock _zm_aat_fire_works.gsc (kills credit the player).
//   - 3 PLASMA-ORB VISUALS per shot (bolt_visual + the acc_ttk_bolt_fx scriptmover
//     clientfield, _acc_tripletake.csc): geotrail movers flying the three lines at
//     a fast tracer speed - the visible "volley". Blue base / RED PaP.
//
//   - 3-ROUND VOLLEY COST: the native shot took 1, this takes 2 more from the
//     clip. Clips are 9 base / 15 PaP (multiples of 3 = 3 / 5 volleys per mag).
//
//   - THE <3 GATE (user: "If you dont have 3 you cant shoot"): GSC has no
//     per-weapon disable-fire API - the ONE fire-blocking lever is an empty clip
//     (the _acc_havoc_charge 0/0 discovery). Any 1-2 round clip is folded to 0:
//     the remainder moves to STOCK when a reload can still rebuild a volley
//     (the engine then forces the reload - nothing is lost), or the gun goes
//     fully dry (0/0) when clip+stock < 3 (a 1-2 round stock would otherwise
//     reload->re-fold->reload forever; Max Ammo / the ammo crate revive it).
//     Partials only ever come from short reloads on the reserve tail.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_TTK_VOLLEY_COST   3       // rounds per trigger pull (1 native + 2 script)
#define ACC_TTK_AIM_RANGE     10000   // side-bolt aim distance (units) - past any map sightline

#namespace acc_tripletake;

// Clientfield registration MUST ride the REGISTER_SYSTEM autoexec (the pre-load phase) -
// registering from acc_main::init() is PAST finalization and hard-fatals the map load
// ("Attempt to register ClientField ... post finalization", hit live 2026-07-16; the
// perk-lights module documents this exact rule).
REGISTER_SYSTEM( "acc_tripletake", &__init__, undefined )

function __init__()
{
    // Bolt-visual scriptmover clientfield (LOCKSTEP with _acc_tripletake.csc: 0=off,
    // 1=blue geotrail, 2=red PaP geotrail). See volley_watcher for WHY visuals are
    // script-owned (the def fires HITSCAN - the gdf graft never changed the firing model).
    clientfield::register( "scriptmover", "acc_ttk_bolt_fx", VERSION_SHIP, 2, "int" );   // 2 bits (0=off,1=TT blue,2=TT red,3=CYBERJACK violet). REVERTED from 3 bits 2026-07-17: the +1 bit overflowed the scriptmover CF budget -> crash-on-load (LB breadcrumb proved the failure began with the widened build). LOCKSTEP with .csc.
}

function init()
{
    callback::on_connect( &on_player_connect );
    acc_utility::log( "tripletake: volley rework live (2 side bolts, 3-round cost, <3 gate; hitscan dmg + mover bolt visuals)" );
}

function on_player_connect()
{
    self thread volley_watcher();
    self thread ammo_gate_watcher();
}

function is_tripletake( w )
{
    return ( isdefined( w ) && w != level.weaponNone && isdefined( w.name ) && IsSubStr( w.name, "apex_tripletake" ) );
}

// ---- the 2 side bolts + the 2 extra rounds, on every native shot ----
function volley_watcher()   // self = player
{
    self endon( "disconnect" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        self waittill( "weapon_fired", w_fired );
        if ( !is_tripletake( w_fired ) ) continue;

        // The native center bolt consumed 1 round; the volley costs 3 -> take up to 2
        // more. The gate keeps sub-3 clips unfireable, so extra < 2 is a should-never
        // edge (a shot squeezed inside the 0.1s gate window) - if it happens anyway,
        // fire only the side bolts that were paid for.
        clip = self GetWeaponAmmoClip( w_fired );
        extra = 2;
        if ( clip < extra ) extra = clip;
        self SetWeaponAmmoClip( w_fired, clip - extra );

        v_muzzle = self GetWeaponMuzzlePoint();
        v_fwd    = self GetWeaponForwardDir();
        v_right  = AnglesToRight( VectorToAngles( v_fwd ) );
        // view-plane offset at the aim distance; small-angle linearization
        // (deg * pi/180) is exact to <0.1% out to ~5 deg - no trig needed.
        off = ACC_TTK_AIM_RANGE * getdvarfloat( "acc_ttk_spread_deg", 4.0 ) * 0.0174533;
        v_center = v_muzzle + v_fwd * ACC_TTK_AIM_RANGE;

        // side HITS - only the ones that were paid for (extra < 2 = the should-never edge)
        if ( extra > 0 )
            MagicBullet( w_fired, v_muzzle, v_center - v_right * off, self );       // left
        if ( extra > 1 )
            MagicBullet( w_fired, v_muzzle, v_center + v_right * off, self );       // right

        // SCRIPT-OWNED plasma-orb visuals - THE bolt representation (the def is hitscan;
        // see the header). Pipeline = the Avogadro bolt recipe: one script_model mover per
        // bolt path + the "acc_ttk_bolt_fx" scriptmover clientfield (geotrail client-side,
        // blue base / RED PaP; _acc_tripletake.csc). One orb per REAL hit: the center
        // native hit always happened, side orbs mirror the side MagicBullets exactly.
        n_color = ( IsSubStr( w_fired.name, "_up" ) ? 2 : 1 );   // PaP forms fly RED
        // VISUAL birth point (user round 8 "the bullet comes out of my face"): the true
        // muzzle point IS ~the camera in first person, so an orb born there fills the
        // screen center. Push the visual forward and toward the on-screen barrel
        // (right + slightly down). COSMETIC ONLY - the damage lines above fire from the
        // true muzzle.
        v_up  = AnglesToUp( VectorToAngles( v_fwd ) );
        v_vis = v_muzzle + v_fwd * 34 + v_right * 8 - v_up * 7;
        level thread bolt_visual( v_vis, v_center, n_color );
        if ( extra > 0 )
            level thread bolt_visual( v_vis, v_center - v_right * off, n_color );
        if ( extra > 1 )
            level thread bolt_visual( v_vis, v_center + v_right * off, n_color );

        self gate_clip( w_fired );   // fold a sub-3 remainder immediately (before the next press)
    }
}

// One plasma-orb bolt mover, muzzle -> first wall along the path (damage is hitscan and
// already resolved; the orb is the visual). Threaded on LEVEL so a disconnect mid-flight
// still cleans up. Avogadro gotchas honored: min flight 0.25s (below that the clientfield
// snapshot eats the visual and the bolt reads as an invisible hit) and NEVER a handle-less
// world PlayFX (looping fx - the clientfield-on-entity pattern is the self-cleaning way).
function bolt_visual( v_from, v_to, n_color )
{
    level endon( "end_game" );

    trace = BulletTrace( v_from, v_to, false, undefined );
    v_end = trace[ "position" ];

    // Final tune (round 7): 4500 u/s - a fast tracer that reads as a bolt but keeps the
    // instant-kill mismatch subtle (0.1-0.2s at typical ranges). Live-tunable.
    speed = getdvarfloat( "acc_ttk_bolt_vis_speed", 4500 );
    if ( speed < 100 ) speed = 100;
    t_fly = Distance( v_from, v_end ) / speed;
    if ( t_fly < 0.25 ) t_fly = 0.25;
    if ( t_fly > 4.0 )  t_fly = 4.0;    // entity-budget cap: 3 movers/volley x 3 volleys/mag stays ~a dozen live

    mover = Spawn( "script_model", v_from );
    if ( !isdefined( mover ) )
        return;
    mover SetModel( "tag_origin" );
    mover clientfield::set( "acc_ttk_bolt_fx", n_color );   // 1 = blue geotrail, 2 = red (PaP), client-side
    mover MoveTo( v_end, t_fly );
    wait t_fly;

    if ( !isdefined( mover ) )
        return;
    mover clientfield::set( "acc_ttk_bolt_fx", 0 );   // StopFX client-side
    wait 0.1;                                          // let the field-0 snapshot land before the ent dies
    if ( isdefined( mover ) )
        mover Delete();
}

// ---- the <3 fire gate: fold 1-2 round clips to 0 so the ENGINE blocks the trigger ----
function ammo_gate_watcher()   // self = player
{
    self endon( "disconnect" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        wait 0.1;   // fast enough that a short-reload partial can't be squeezed off
        w = self GetCurrentWeapon();
        if ( !is_tripletake( w ) ) continue;
        self gate_clip( w );
    }
}

function gate_clip( w )   // self = player
{
    clip = self GetWeaponAmmoClip( w );
    if ( clip <= 0 || clip >= ACC_TTK_VOLLEY_COST ) return;

    stock = self GetWeaponAmmoStock( w );
    if ( clip + stock < ACC_TTK_VOLLEY_COST )
    {
        // Not a full volley left ANYWHERE -> the gun is dry. Zero BOTH sides (a 1-2
        // round stock would otherwise loop reload->refill->re-fold forever).
        self SetWeaponAmmoClip( w, 0 );
        self SetWeaponAmmoStock( w, 0 );
        return;
    }
    // Short reload left a partial clip but stock can rebuild a volley: park the
    // remainder in stock and let the engine's empty-clip handling force the reload.
    // Nothing is lost - the next reload pulls it all back.
    self SetWeaponAmmoStock( w, stock + clip );
    self SetWeaponAmmoClip( w, 0 );
}
