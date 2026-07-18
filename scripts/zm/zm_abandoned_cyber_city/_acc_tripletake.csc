// =============================================================================
// _acc_tripletake.csc - Triple Take bolt VISUAL (client half).
//
// THE 2026-07-16 ROOT CAUSE (live-proven, kill-timing test): the projectileweapon.gdf
// GRAFT DOES NOT CHANGE THE RUNTIME FIRING MODEL - the gun still fires HITSCAN
// (zombies die instantly while any "projectile" visual is mid-flight), so every
// def-side projectile field (projTrailEffect/projectileSpeed/projectileModel) is
// INERT and no trail ever rendered. The visible bolt is therefore SCRIPT-OWNED:
// the server (_acc_tripletake.gsc) flies a script_model mover per bolt path and
// sets this scriptmover clientfield; this callback attaches the plasma geotrail
// (the 1.5x acc clones of the Blast-O-Matic's DOA orb) client-side. Same
// self-cleaning pattern as the Avogadro bolt (acc_avo_bolt_fx) and the perk
// glow (accPerkGlow): field 1/2 = PlayFxOnTag (blue base / RED PaP), field 0 =
// StopFX; the server Delete()s the mover right after.
//
// LOCKSTEP: scope/name/version/bits/type here MUST equal _acc_tripletake.gsc.
// client_fx precache is REQUIRED (the perk-lights lesson: server #precache("fx")
// alone leaves clients with no asset to draw).
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "client_fx", "acc/acc_ttk_geotrail_blue" );
#precache( "client_fx", "acc/acc_ttk_geotrail_red" );
#precache( "client_fx", "acc/acc_cj_bolt_violet" );   // THE CYBERJACK shot bolt (CF value 3; _acc_cyberjack rides this field)
#precache( "client_fx", "_custom/acc/acc_cj_bolt_violet_pap" );   // THE CYBERJACK PaP trail (CF value 4; richer violet, shown when tier >= 1 - user 2026-07-17 "more purple when papped, just a bit more")

#namespace acc_tripletake;

REGISTER_SYSTEM( "acc_tripletake", &__init__, undefined )

function __init__()
{
    // 2 bits: 0 = off (StopFX), 1 = TT blue geotrail (base), 2 = TT red geotrail (PaP), 3 = CYBERJACK violet.
    // REVERTED from the 3-bit widening 2026-07-17: the extra bit overflowed the scriptmover CF budget and
    // crashed the map on load (registration asserts at script-init, after XZONE_LOADED = no console fatal).
    // LOCKSTEP: the bit width here MUST equal _acc_tripletake.gsc's register (both are 2).
    clientfield::register( "scriptmover", "acc_ttk_bolt_fx", VERSION_SHIP, 2, "int", &bolt_fx_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

function bolt_fx_cb( n_local_client, n_old, n_new, b_new_ent, b_initial_snap, str_field, b_was_time_jump )
{
    if ( n_new == 1 || n_new == 2 || n_new == 3 )
    {
        // replace-safe: a re-set on a live mover stops the old handle first (perk-lights recipe)
        if ( isdefined( self.acc_ttk_bolt_fx ) )
            StopFX( n_local_client, self.acc_ttk_bolt_fx );
        fx = "acc/acc_ttk_geotrail_blue";
        if ( n_new == 2 ) fx = "acc/acc_ttk_geotrail_red";
        if ( n_new == 3 ) fx = "acc/acc_cj_bolt_violet";   // THE CYBERJACK shot bolt (violet - _acc_cyberjack)
        self.acc_ttk_bolt_fx = PlayFxOnTag( n_local_client, fx, self, "tag_origin" );
    }
    else if ( n_new == 0 )
    {
        // join-in-progress guard (Avogadro precedent): an initial snapshot can deliver 0
        // without the 1/2-branch ever running on this client - StopFX on undefined is an error.
        if ( isdefined( self.acc_ttk_bolt_fx ) )
            StopFX( n_local_client, self.acc_ttk_bolt_fx );
    }
}
