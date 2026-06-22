// =============================================================================
// _acc_boss_phantom.csc - Phantom holographic GLOW aura (client half / render half).
//
// v2 of the Phantom look (user 2026-06-18: "go"): a cyan energy glow wrapped around the
// boss so it reads as a destabilizing HOLOGRAM, not just a cloaked zombie. Same proven
// pipeline as the perk-machine glow (_acc_perk_lights.csc): server-side PlayFX does NOT
// render in this build, so the SERVER (_acc_boss_phantom.gsc) only sets an "accPhantomAura"
// clientfield on the actor, and THIS client file PlayFXOnTag's the looped glow (leak-safe:
// store the handle, StopFX before replacing).
//
// CLOAK-AWARE: the server toggles the clientfield WITH the cloak - aura ON only while the
// Phantom is materialized, OFF while cloaked - so the glow never betrays the invisible boss
// (a floating aura over an invisible body would give its position away). Materializing thus
// reads as "phases in WITH a cyan energy burst," vanishing as "the glow winks out."
//
// FX = acc/light/fx_perk_glow_teal: the cyan/teal recoloured power-up aura, ALREADY packed
// (the PaP machine uses it) and confirmed to render here - zero new asset. Swap level._effect
// below to try a different look (e.g. an electric .efx) without touching the server.
//
// LOCKSTEP: scope/name/version/bits/type here MUST equal _acc_boss_phantom.gsc (actor scope,
// like accEyeTint). Wired by the entry .csc #using (so this REGISTER_SYSTEM autoexec runs).
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

// Already packed via the `fx,acc/light/fx_perk_glow_teal` zone line (the PaP glow uses it).
#precache( "client_fx", "acc/light/fx_perk_glow_teal" );

#namespace acc_boss_phantom;

REGISTER_SYSTEM( "acc_phantom_aura", &__init__, undefined )

function __init__()
{
    level._effect[ "acc_phantom_aura" ] = "acc/light/fx_perk_glow_teal";

    // actor scope (mirror accEyeTint). 1 bit = 0 (off) / 1 (on). !CF_CALLBACK_ZERO_ON_NEW_ENT
    // so a late joiner whose snapshot already has the Phantom materialized still draws the aura.
    clientfield::register( "actor", "accPhantomAura", VERSION_SHIP, 1, "int", &aura_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

// self = the Phantom actor. newVal 1 = aura on (materialized), 0 = off (cloaked / dead).
// Mirrors _acc_perk_lights::glow_cb for leak + re-entry safety.
function aura_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
    if ( !isdefined( newVal ) || newVal == 0 )
    {
        if ( isdefined( self.acc_phantom_aura_fx ) )
        {
            StopFX( localClientNum, self.acc_phantom_aura_fx );
            self.acc_phantom_aura_fx = undefined;
        }
        return;
    }

    fx = level._effect[ "acc_phantom_aura" ];
    if ( !isdefined( fx ) ) return;

    // The model dobj must exist before PlayFXOnTag can resolve "tag_origin".
    self util::waittill_dobj( localClientNum );
    if ( !isdefined( self ) ) return;

    if ( isdefined( self.acc_phantom_aura_fx ) )
        StopFX( localClientNum, self.acc_phantom_aura_fx );

    self.acc_phantom_aura_fx = PlayFXOnTag( localClientNum, fx, self, "tag_origin" );
}
