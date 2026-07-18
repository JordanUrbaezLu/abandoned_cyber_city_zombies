#using scripts\codescripts\struct;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\duplicaterender.gsh;

#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\shared\system_shared;
#using scripts\shared\clientfield_shared;

#namespace aw_mbox;

REGISTER_SYSTEM_EX("aw_mbox", &__init__, &__main__, undefined)

#define HOLO_DUPRENDER_MTL                        "mc/dr_fx_holo"
// [acc] GOLD wonder-pull holo (user 2026-07-12): dr_fx_holo_gold = the pack material cloned
// with the cg02 tint constant swapped cyan (0.0/0.1/1.0) -> gold (1.0/0.65/0.05), authored
// install-side in source_data\_planet_aw\acc_aw_holo_gold.gdt. Filter id 31 (30 = the cyan
// holo; 9 = freezegun dissolve; 10 = wolf-howl ghost - keep unique).
#define HOLO_GOLD_DUPRENDER_MTL                   "mc/dr_fx_holo_gold"
// [acc] GREEN knife-to-share holo (user 2026-07-13): dr_fx_holo cloned with the cg02 tint swapped
// cyan (0.0/0.1/1.0) -> green (0.0/1.0/0.15), install-side source_data\_planet_aw\acc_aw_holo_green.gdt.
// Filter id 32 (30 cyan / 31 gold / 9 freezegun / 10 wolf-howl - keep unique). Clientfield value 3.
#define HOLO_GREEN_DUPRENDER_MTL                  "mc/dr_fx_holo_green"

//*****************************************************************************
// MAIN
//*****************************************************************************

function __init__(){
	// [acc] widened 1 -> 2 bits for the gold wonder holo (0 = off, 1 = cyan, 2 = GOLD).
	// MUST stay in lockstep with the server registration in _zm_aw_mysterybox.gsc __init__
	// (register unconditionally in BOTH VMs - Clientfield Mismatch otherwise).
	clientfield::register( "scriptmover", "exo_magicbox_dr_holo", VERSION_SHIP, 2, "int", &handle_holo_dr, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	duplicate_render::set_dr_filter_framebuffer_duplicate("aw_holo_box_overlay", 30, "aw_holo_box_overlay_enable", undefined, DR_TYPE_FRAMEBUFFER_DUPLICATE, HOLO_DUPRENDER_MTL, DR_CULL_NEVER);
	duplicate_render::set_dr_filter_framebuffer_duplicate("aw_holo_box_overlay_gold", 31, "aw_holo_box_gold_enable", undefined, DR_TYPE_FRAMEBUFFER_DUPLICATE, HOLO_GOLD_DUPRENDER_MTL, DR_CULL_NEVER);
	duplicate_render::set_dr_filter_framebuffer_duplicate("aw_holo_box_overlay_green", 32, "aw_holo_box_green_enable", undefined, DR_TYPE_FRAMEBUFFER_DUPLICATE, HOLO_GREEN_DUPRENDER_MTL, DR_CULL_NEVER);
}

function handle_holo_dr(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump){
	// [acc] route the 2-bit value to the matching overlay (exactly one on, or both off).
	cyan = 0;
	gold = 0;
	green = 0;
	if(newVal == 1) cyan = 1;
	if(newVal == 2) gold = 1;
	if(newVal == 3) green = 1;   // [acc] knife-to-share (user 2026-07-13)
	self duplicate_render::set_dr_flag("aw_holo_box_overlay_enable", cyan);
	self duplicate_render::set_dr_flag("aw_holo_box_gold_enable", gold);
	self duplicate_render::set_dr_flag("aw_holo_box_green_enable", green);
	self duplicate_render::update_dr_filters(localClientNum);
}

function __main__(){}