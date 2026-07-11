#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

// ACC: client-side half of the Aetherium master switch. The GSC flag (level.acc_aetherium_hud,
// _acc_lui.gsc __init__) lives in the OTHER VM, so this hardcoded twin gates the LuiLoad that
// replaces the stock HUD menu. FLIP BOTH TOGETHER (0 here + false there = stock HUD back;
// clientfield REGISTRATION below stays unconditional either way - bit-layout lockstep).
#define ACC_AETHERIUM_HUD_ON 1

#namespace zm_aetherium_hud;

REGISTER_SYSTEM_EX( "zm_aetherium_hud", &__init__, &__main__, undefined )

function set_ui_model_value( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	//  - create model using exact fieldName
	// [acc] GUARD: getuimodelforcontroller can return undefined for a client whose UI model root isn't
	// ready yet (join/first-snapshot); createuimodel on undefined faults the client UI. REVIEW FIX
	// 2026-07-08: don't silently DROP the value on that window - every GSC feeder is change-guarded
	// (last_* != value) and never re-sends, so a dropped first value left that widget 0/stale for the
	// whole match. Stash it latest-wins per (client, field) and retry until the root exists.
	model_root = getuimodelforcontroller( localClientNum );
	if ( !isdefined( model_root ) )
	{
		level thread deferred_set_ui_model_value( localClientNum, fieldName, newVal );
		return;
	}
	// Keep any in-flight retry for this field coherent: it re-applies the NEWEST value (idempotent),
	// so a stale deferred value can never overwrite a fresher direct set.
	if ( isdefined( level.acc_uim_pending ) )
		level.acc_uim_pending[ "" + localClientNum + "_" + fieldName ] = newVal;
	setuimodelvalue( createuimodel( model_root, fieldName ), newVal );
}

// [acc] Deferred re-apply for set_ui_model_value when the client's UI model root isn't ready yet
// (initial snapshot). Latest value per (client, field) wins; ONE bounded retry thread per key (~10s
// at 0.1s - the root appears within the first frames once the snapshot settles, this just outlives
// any realistic init order). Applies whatever is newest in the pending slot at fire time.
function deferred_set_ui_model_value( localClientNum, fieldName, newVal )
{
	if ( !isdefined( level.acc_uim_pending ) )      level.acc_uim_pending = [];
	if ( !isdefined( level.acc_uim_retry_active ) ) level.acc_uim_retry_active = [];

	key = "" + localClientNum + "_" + fieldName;
	level.acc_uim_pending[ key ] = newVal;                 // latest-wins
	if ( IS_TRUE( level.acc_uim_retry_active[ key ] ) )
		return;                                            // a retry for this field is already waiting
	level.acc_uim_retry_active[ key ] = true;

	for ( i = 0; i < 100; i++ )
	{
		wait 0.1;
		model_root = getuimodelforcontroller( localClientNum );
		if ( isdefined( model_root ) )
		{
			setuimodelvalue( createuimodel( model_root, fieldName ), level.acc_uim_pending[ key ] );
			break;
		}
	}
	level.acc_uim_retry_active[ key ] = false;
}

function __init__()
{
	// Register health clientfield callbacks for each player using world
	// ACC: pinned to 4 in LOCKSTEP with _zm_aetherium_hud.gsc (see the .gsc comment; a gsc/csc
	// registration-count mismatch desyncs the world-scope clientfield bit layout).
	for( i = 0; i < 4; i++ )
	{
		clientfield::register( "world", "player_health_" + i, VERSION_SHIP, 7, "float", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	}
	
	// Register packed player states clientfield
	clientfield::register( "world", "player_states_packed", VERSION_SHIP, 8, "int", &player_states_callback, 0, 0 );

	// ACC per-player shards broadcast (LOCKSTEP with the .gsc - appended after player_states_packed
	// in world scope, same order/width). set_ui_model_value pipes each into the "player_shards_<i>"
	// UI model the AetheriumPartyPlayers widget reads per teammate clientNum.
	for( i = 0; i < 4; i++ )
	{
		clientfield::register( "world", "player_shards_" + i, VERSION_SHIP, 10, "int", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	}

	// ACC per-player MB + EXO broadcast (LOCKSTEP with the .gsc - mb 0..3 THEN exo 0..3, right after
	// player_shards). set_ui_model_value pipes each into the "player_mb_<i>" / "player_exo_<i>" UI
	// models the AetheriumPartyPlayers widget reads per teammate clientNum.
	for( i = 0; i < 4; i++ )
	{
		clientfield::register( "world", "player_mb_" + i, VERSION_SHIP, 5, "int", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	}
	for( i = 0; i < 4; i++ )
	{
		clientfield::register( "world", "player_exo_" + i, VERSION_SHIP, 4, "int", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	}

	// ACC currencies (LOCKSTEP with the .gsc - same order/width/type): toplayer fields piped
	// straight into same-named UI models for AetheriumPlayerInfo's panel row.
	clientfield::register( "toplayer", "acc_shards", VERSION_SHIP, 10, "int", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "acc_mb", VERSION_SHIP, 5, "int", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "acc_exo", VERSION_SHIP, 4, "int", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	// ACC max HP (LOCKSTEP with the .gsc - appended last in toplayer scope) -> "acc_maxhp" UI model.
	clientfield::register( "toplayer", "acc_maxhp", VERSION_SHIP, 9, "int", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	// ACC gun-badge FLAG bitmask (LOCKSTEP with the .gsc - appended last; REPLACED the 1-bit
	// acc_mule field 2026-07-08) -> "acc_badges" UI model read by acc_hud.lua CoD.AccGunBadgeRow
	// (bit 0 MULE, bit 1 TURBO, bit 2 NUKE; bit table + compute live in _acc_gun_badges.gsc. TIER
	// badges PaP/OC ride the existing accPapTier/accOcTier clientuimodels).
	clientfield::register( "toplayer", "acc_badges", VERSION_SHIP, 6, "int", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
    
	// Load the Aetherium HUD - ACC: gate + LOWERCASE "hud" (matches the on-disk dir shared
	// with acc_hud.lua and the zone rawfile line; the kit's "HUD" casing only worked via
	// Windows case-insensitivity). ACC_AETHERIUM_HUD_ON must be flipped IN LOCKSTEP with
	// level.acc_aetherium_hud in _acc_lui.gsc (separate VMs - the .csc can't read the GSC
	// bool): false here stops the T7Hud_zm_factory takeover so the STOCK HUD returns.
	if ( ACC_AETHERIUM_HUD_ON )
		LuiLoad( "ui.uieditor.menus.hud.AetheriumHud" );
}

function __main__()
{
	// Client-side HUD logic
	// Pre-create player state models
	for( i = 0; i < 4; i++ )
	{
		model = getuimodelforcontroller( 0 );
		if( IsDefined( model ) )
		{
			stateModel = createuimodel( model, "player_state_" + i );
			setuimodelvalue( stateModel, 0 );
		}
	}
}

function player_states_callback( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump )
{
	// Unpack all 4 player states from the single packed value
	player0_state = ( newval >> 0 ) & 3;  // Extract bits 0-1
	player1_state = ( newval >> 2 ) & 3;  // Extract bits 2-3
	player2_state = ( newval >> 4 ) & 3;  // Extract bits 4-5
	player3_state = ( newval >> 6 ) & 3;  // Extract bits 6-7
	
	// Update UI models for each player
	model = getuimodelforcontroller( localclientnum );
	if( IsDefined( model ) )
	{
		// Player 0
		setuimodelvalue( createuimodel( model, "player_state_0" ), player0_state );
		
		// Player 1
		setuimodelvalue( createuimodel( model, "player_state_1" ), player1_state );
		
		// Player 2
		setuimodelvalue( createuimodel( model, "player_state_2" ), player2_state );
		
		// Player 3
		setuimodelvalue( createuimodel( model, "player_state_3" ), player3_state );
	}
}