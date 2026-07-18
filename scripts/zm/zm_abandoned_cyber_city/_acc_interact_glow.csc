// =============================================================================
// _acc_interact_glow.csc - client half of the interactable-station holo shimmer.
//
// Mirrors the AW mystery box holo recipe (scripts/planet/_aw/_zm_aw_mysterybox.csc):
// a FRAMEBUFFER_DUPLICATE duplicate-render filter re-draws the tagged ent's mesh
// with a holo material layered on top. The PULSE lives on the SERVER (the .gsc
// blinks the clientfield - see its header for why); this side just maps CF -> DR.
//
// MATERIAL GROUND TRUTH (v4 deep-dig, share\raw\techsetdefs_stable\specialty\
// ghost.techsetdef): dr_fx_holo's materialType "ghost" = an ADDITIVE, DEPTH-TESTED,
// **LIT** transparent techset ("add + depth", renderFlags "lit transparent").
// Decoded constants: cg02 = "SceneTint" (the proven gold/green recolor knob),
// cg03_x = "Edge Amount" (the pack runs 800 vs default 0.5 - the fresnel-edge
// blast), cg03_y = "Edge Harshness", cg03_w = tools-only script simulator.
// flicker*/scaleRGB/colorMap swaps produced NO visible change live (v2/v3) -
// treat every non-cg/tint field as unverified-or-inert on this techset.
//
// Our material: mc/acc_dr_fx_holo_dim (source_data\_planet_aw\acc_aw_holo_dim.gdt)
// = the box holo with cg02 AND colorTint scaled x0.35 - the proven color path is
// the only trustworthy dimmer. Box filters 30-32 keep the full-bright originals.
//
// KNOWN LIMIT (the Exo pod's dark lower half): "lit transparent" means the holo
// is modulated by scene lighting (and possibly baked vertex AO) - a shadowed
// lower body adds ~nothing visibly. That is intrinsic to the ghost family; the
// alternative overlay techsets are dead ends for in-scene use (hud_outline_*/
// sonar_rim = replace-blend keyline-BUFFER shaders, hacked = also lit). Real pod
// fixes: a different station mesh, or a custom unlit emissive_passthrough_
// transparent(_scroll) overlay material - see docs/11.
//
// LOCKSTEP: scope/name/version/bits/type here MUST equal _acc_interact_glow.gsc.
// DR filter id 20 - keep unique across the map's filters (9 = freezegun dissolve,
// 10 = wolf-howl ghost, 30/31/32 = AW box holos). Next free: 21.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\duplicaterender.gsh;

#namespace acc_interact_glow;

#define ACC_INTERACT_GLOW_MTL "mc/acc_dr_fx_holo_dim"   // cg02/colorTint-dimmed box-holo clone (zone-listed)

REGISTER_SYSTEM( "acc_interact_glow", &__init__, undefined )

function __init__()
{
    clientfield::register( "scriptmover", "acc_interact_glow", VERSION_SHIP, 1, "int", &glow_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
    duplicate_render::set_dr_filter_framebuffer_duplicate( "acc_interact_glow", 20, "acc_interact_glow_on", undefined, DR_TYPE_FRAMEBUFFER_DUPLICATE, ACC_INTERACT_GLOW_MTL, DR_CULL_NEVER );
}

function glow_cb( n_local_client, n_old, n_new, b_new_ent, b_initial_snap, str_field, b_was_time_jump )
{
    // self = the station's client ent (box precedent). Server blinks the CF; both
    // edges land here. An initial snapshot delivering 0 is a clean no-op.
    self duplicate_render::set_dr_flag( "acc_interact_glow_on", n_new );
    self duplicate_render::update_dr_filters( n_local_client );
}
