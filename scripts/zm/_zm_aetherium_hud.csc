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
	setuimodelvalue( createuimodel( getuimodelforcontroller( localClientNum ), fieldName ), newVal );
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

	// ACC currencies (LOCKSTEP with the .gsc - same order/width/type): toplayer fields piped
	// straight into same-named UI models for AetheriumPlayerInfo's panel row.
	clientfield::register( "toplayer", "acc_shards", VERSION_SHIP, 10, "int", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "acc_mb", VERSION_SHIP, 5, "int", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "toplayer", "acc_exo", VERSION_SHIP, 4, "int", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	// ACC max HP (LOCKSTEP with the .gsc - appended last in toplayer scope) -> "acc_maxhp" UI model.
	clientfield::register( "toplayer", "acc_maxhp", VERSION_SHIP, 9, "int", &set_ui_model_value, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
    
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