// ============================================================================
// [acc] VENDORED + ADAPTED from HarryBo21 Hero Weapons v2.0.0 (2026-07-24; CLIENT).
// LOCKSTEP with the .gsc twin: beam/torch CFs moved toplayer -> allplayers (pool
// full), thrasher_skull_fire registration deleted. The two converted 1P callbacks
// got a getLocalPlayer guard - as allplayers fields they now fire for EVERY player
// ent on every client, but playViewModelFx must stay local-shooter-only (mirrors
// the existing "player != self" guards in the 3p callbacks).
// ============================================================================
#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_weapons;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace keeper_skull;

#precache( "client_fx", "zombie/fx_tesla_shock_eyes_zmb" );
#precache( "client_fx", "zombie/fx_glow_eye_white" );
#precache( "client_fx", "dlc2/island/fx_zombie_torso_explo" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_beam_start_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_beam_loop_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_beam_end_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_beam_start_3p_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_beam_loop_3p_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_beam_end_3p_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_beam_side_start_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_beam_side_loop_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_beam_side_end_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_beam_side_start_3p_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_beam_side_loop_3p_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_beam_side_end_3p_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_torch_start_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_torch_loop_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_torch_end_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_torch_side_start_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_torch_side_loop_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_torch_side_end_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_torch_start_3p_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_torch_loop_3p_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_torch_end_3p_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_torch_side_start_3p_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_torch_side_loop_3p_island" );
#precache( "client_fx", "dlc2/zmb_weapon/fx_wpn_skull_torch_side_end_3p_island" );
#precache( "client_fx", "dlc2/island/fx_fire_thrash_arm_left_loop" );
#precache( "client_fx", "dlc2/island/fx_fire_thrash_arm_rgt_loop" );
#precache( "client_fx", "dlc2/island/fx_fire_thrash_leg_left_loop" );
#precache( "client_fx", "dlc2/island/fx_fire_thrash_leg_rgt_loop" );
#precache( "client_fx", "dlc2/island/fx_fire_thrash_hip_left_loop" );
#precache( "client_fx", "dlc2/island/fx_fire_thrash_hip_rgt_loop" );
#precache( "client_fx", "dlc2/island/fx_fire_thrash_torso_loop" );
#precache( "client_fx", "dlc2/island/fx_fire_thrash_waist_loop" );

REGISTER_SYSTEM_EX( "keeper_skull", &__init__, undefined, undefined )

function __init__()
{
	clientfield::register( "actor", "zombie_explode", VERSION_SHIP, 1, "int", &zombie_explode_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "death_ray_shock_eye_fx", VERSION_SHIP, 1, "int", &death_ray_shock_eye_fx, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "entranced", VERSION_SHIP, 1, "int", &entranced_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	// [acc] thrasher_skull_fire actor CF deleted (lockstep with gsc; thrasher_skull_fire_cb below is now dead code)
	clientfield::register( "allplayers", "skull_beam_fx", VERSION_SHIP, 2, "int", &skull_beam_fx_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );   // [acc] lockstep with gsc
	clientfield::register( "allplayers", "skull_torch_fx", VERSION_SHIP, 2, "int", &skull_torch_fx_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );  // [acc] lockstep with gsc
	clientfield::register( "allplayers", "skull_beam_3p_fx", VERSION_SHIP, 2, "int", &skull_beam_3p_fx_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "allplayers", "skull_torch_3p_fx", VERSION_SHIP, 2, "int", &skull_torch_3p_fx_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "allplayers", "skull_emissive", VERSION_SHIP, 1, "int", &skull_emissive_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	level._effect[ "death_ray_shock_eyes" ] = "zombie/fx_tesla_shock_eyes_zmb";
	level._effect[ "glow_eye_white" ] = "zombie/fx_glow_eye_white";
	level._effect[ "zombie_explode" ] = "dlc2/island/fx_zombie_torso_explo";
	level._effect[ "beam_start" ] = "dlc2/zmb_weapon/fx_wpn_skull_beam_start_island";
	level._effect[ "beam_loop" ] = "dlc2/zmb_weapon/fx_wpn_skull_beam_loop_island";
	level._effect[ "beam_end" ] = "dlc2/zmb_weapon/fx_wpn_skull_beam_end_island";
	level._effect[ "beam_start_3p" ] = "dlc2/zmb_weapon/fx_wpn_skull_beam_start_3p_island";
	level._effect[ "beam_loop_3p" ] = "dlc2/zmb_weapon/fx_wpn_skull_beam_loop_3p_island";
	level._effect[ "beam_end_3p" ] = "dlc2/zmb_weapon/fx_wpn_skull_beam_end_3p_island";
	level._effect[ "beam_side_start" ] = "dlc2/zmb_weapon/fx_wpn_skull_beam_side_start_island";
	level._effect[ "beam_side_loop" ] = "dlc2/zmb_weapon/fx_wpn_skull_beam_side_loop_island";
	level._effect[ "beam_side_end" ] = "dlc2/zmb_weapon/fx_wpn_skull_beam_side_end_island";
	level._effect[ "beam_side_start_3p" ] = "dlc2/zmb_weapon/fx_wpn_skull_beam_side_start_3p_island";
	level._effect[ "beam_side_loop_3p" ] = "dlc2/zmb_weapon/fx_wpn_skull_beam_side_loop_3p_island";
	level._effect[ "beam_side_end_3p" ] = "dlc2/zmb_weapon/fx_wpn_skull_beam_side_end_3p_island";
	level._effect[ "torch_start" ] = "dlc2/zmb_weapon/fx_wpn_skull_torch_start_island";
	level._effect[ "torch_loop" ] = "dlc2/zmb_weapon/fx_wpn_skull_torch_loop_island";
	level._effect[ "torch_end" ] = "dlc2/zmb_weapon/fx_wpn_skull_torch_end_island";
	level._effect[ "torch_side_start" ] = "dlc2/zmb_weapon/fx_wpn_skull_torch_side_start_island";
	level._effect[ "torch_side_loop" ] = "dlc2/zmb_weapon/fx_wpn_skull_torch_side_loop_island";
	level._effect[ "torch_side_end" ] = "dlc2/zmb_weapon/fx_wpn_skull_torch_side_end_island";
	level._effect[ "torch_start_3p" ] = "dlc2/zmb_weapon/fx_wpn_skull_torch_start_3p_island";
	level._effect[ "torch_loop_3p" ] = "dlc2/zmb_weapon/fx_wpn_skull_torch_loop_3p_island";
	level._effect[ "torch_end_3p" ] = "dlc2/zmb_weapon/fx_wpn_skull_torch_end_3p_island";
	level._effect[ "torch_side_start_3p" ] = "dlc2/zmb_weapon/fx_wpn_skull_torch_side_start_3p_island";
	level._effect[ "torch_side_loop_3p" ] = "dlc2/zmb_weapon/fx_wpn_skull_torch_side_loop_3p_island";
	level._effect[ "torch_side_end_3p" ] = "dlc2/zmb_weapon/fx_wpn_skull_torch_side_end_3p_island";
	level._effect[ "fx_fire_thrash_arm_left_loop" ] = "dlc2/island/fx_fire_thrash_arm_left_loop";
	level._effect[ "fx_fire_thrash_arm_rgt_loop" ] = "dlc2/island/fx_fire_thrash_arm_rgt_loop";
	level._effect[ "fx_fire_thrash_leg_left_loop" ] = "dlc2/island/fx_fire_thrash_leg_left_loop";
	level._effect[ "fx_fire_thrash_leg_rgt_loop" ] = "dlc2/island/fx_fire_thrash_leg_rgt_loop";
	level._effect[ "fx_fire_thrash_hip_left_loop" ] = "dlc2/island/fx_fire_thrash_hip_left_loop";
	level._effect[ "fx_fire_thrash_hip_rgt_loop" ] = "dlc2/island/fx_fire_thrash_hip_rgt_loop";
	level._effect[ "fx_fire_thrash_torso_loop" ] = "dlc2/island/fx_fire_thrash_torso_loop";
	level._effect[ "fx_fire_thrash_waist_loop" ] = "dlc2/island/fx_fire_thrash_waist_loop";
}

function skull_torch_fx_cb( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump )
{
	if ( isSpectating( localclientnum ) )
		return;

	if ( self != getLocalPlayer( localclientnum ) )
		return;   // [acc] allplayers conversion: 1P viewmodel FX = local shooter only
	if ( newval == 1 )
	{
		if ( isDefined( self getTagOrigin( "tag_fx_mouth" ) ) )
			playViewModelFx( localclientnum, level._effect[ "torch_start" ], "tag_fx_mouth" );
		
		if ( isDefined( self getTagOrigin( "tag_fx_left" ) ) )
			playViewModelFx( localclientnum, level._effect[ "torch_side_start" ], "tag_fx_left" );
		
		if ( isDefined( self getTagOrigin( "tag_fx_right" ) ) )
			playViewModelFx( localclientnum, level._effect[ "torch_side_start" ], "tag_fx_right" );
		
	}
	else if ( newval == 2 )
	{
		if ( isDefined( self getTagOrigin( "tag_fx_mouth" ) ) )
			self.fx_skull_tag_fx_mouth = playViewModelFx( localclientnum, level._effect[ "torch_loop" ], "tag_fx_mouth" );
		
		if ( isDefined( self getTagOrigin( "tag_fx_left" ) ) )
			self.fx_skull_tag_fx_left = playViewModelFx( localclientnum, level._effect[ "torch_side_loop" ], "tag_fx_left" );
		
		if ( isDefined( self getTagOrigin( "tag_fx_right" ) ) )
			self.fx_skull_tag_fx_right = playViewModelFx( localclientnum, level._effect[ "torch_side_loop" ], "tag_fx_right" );
		
	}
	else if ( isDefined( self.fx_skull_tag_fx_mouth ) )
	{
		stopFx( localclientnum, self.fx_skull_tag_fx_mouth );
		self.fx_skull_tag_fx_mouth = undefined;
	}
	if ( isDefined( self.fx_skull_tag_fx_left ) )
	{
		stopFx( localclientnum, self.fx_skull_tag_fx_left );
		self.fx_skull_tag_fx_left = undefined;
	}
	if ( isDefined( self.fx_skull_tag_fx_right ) )
	{
		stopFx( localclientnum, self.fx_skull_tag_fx_right );
		self.fx_skull_tag_fx_right = undefined;
	}
}

function skull_beam_fx_cb( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump )
{
	if ( isSpectating( localclientnum ) )
		return;
	

	if ( self != getLocalPlayer( localclientnum ) )
		return;   // [acc] allplayers conversion: 1P viewmodel FX = local shooter only
	if ( newval == 1 )
	{
		playViewModelFx( localclientnum, level._effect[ "beam_start" ], "tag_flash" );
		if ( isDefined( self getTagOrigin( "tag_fx_right" ) ) )
			playViewModelFx( localclientnum, level._effect[ "beam_side_start" ], "tag_fx_right" );
		
		if ( isDefined( self getTagOrigin( "tag_fx_left" ) ) )
			playViewModelFx( localclientnum, level._effect[ "beam_side_start" ], "tag_fx_left" );
		
	}
	else if ( newval == 2 )
	{
		self.fx_skull_tag_flash = playViewModelFx( localclientnum, level._effect[ "beam_loop" ], "tag_flash" );
		if ( isDefined( self getTagOrigin( "tag_fx_left" ) ) )
			self.fx_skull_tag_fx_left_2 = playViewModelFx( localclientnum, level._effect[ "beam_side_loop" ], "tag_fx_left" );
		
		if ( isDefined( self getTagOrigin( "tag_fx_right" ) ) )
			self.fx_skull_tag_fx_right_2 = playViewModelFx( localclientnum, level._effect[ "beam_side_loop" ], "tag_fx_right" );
		
	}
	else if ( isDefined( self.fx_skull_tag_flash ) )
	{
		stopFx( localclientnum, self.fx_skull_tag_flash );
		self.fx_skull_tag_flash = undefined;
	}
	if ( isDefined( self.fx_skull_tag_fx_left_2 ) )
	{
		stopFx( localclientnum, self.fx_skull_tag_fx_left_2 );
		self.fx_skull_tag_fx_left_2 = undefined;
	}
	if ( isDefined( self.fx_skull_tag_fx_right_2 ) )
	{
		stopFx( localclientnum, self.fx_skull_tag_fx_right_2 );
		self.fx_skull_tag_fx_right_2 = undefined;
	}
}

function zombie_explode_fx( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump )
{
	if ( isDefined( self.gibdef ) )
	{
		gibbundle = struct::get_script_bundle( "gibcharacterdef", self.gibdef );
		str_scriptbundle = self.gibdef + "_nofx";
		if ( !isDefined( struct::get_script_bundle( "gibcharacterdef", str_scriptbundle ) ) )
		{
			s_struct = spawnStruct();
			s_struct.gibs = [];
			s_struct.name = gibbundle.name;
			foreach ( gibflag, gib in gibbundle.gibs )
			{
				s_struct.gibs[ gibflag ] = spawnStruct();
				s_struct.gibs[ gibflag ].gibmodel = gibbundle.gibs[ gibflag ].gibmodel;
				s_struct.gibs[ gibflag ].gibtag = gibbundle.gibs[ gibflag ].gibtag;
				s_struct.gibs[ gibflag ].gibdynentfx = gibbundle.gibs[ gibflag ].gibdynentfx;
				s_struct.gibs[ gibflag ].gibsound = gibbundle.gibs[ gibflag ].gibsound;
			}
			level.scriptbundles[ "gibcharacterdef" ][ str_scriptbundle ] = s_struct;
		}
		self.gib_data = spawnStruct();
		self.gib_data.gibdef = str_scriptbundle;
	}
	playFxOnTag( localclientnum, level._effect[ "zombie_explode" ], self, "j_spine4" );
}

function death_ray_shock_eye_fx( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump )
{
	if ( newval == 1 )
	{
		if ( !isDefined( self.fx_skull_death_ray_shock_eyes ) )
			self.fx_skull_death_ray_shock_eyes = playFxOnTag( localclientnum, level._effect[ "death_ray_shock_eyes" ], self, "j_eyeball_le" );
		
	}
	else
	{
		deleteFx( localclientnum, self.fx_skull_death_ray_shock_eyes, 1 );
		self.fx_skull_death_ray_shock_eyes = undefined;
	}
}

function entranced_cb( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump )
{
	if ( newval == 1 )
	{
		if ( !isDefined( self.fx_skull_glow_eye_white ) )
			self.fx_skull_glow_eye_white = playFxOnTag( localclientnum, level._effect[ "glow_eye_white" ], self, "j_eyeball_le" );
		
	}
	else
	{
		deleteFx( localclientnum, self.fx_skull_glow_eye_white, 1 );
		self.fx_skull_glow_eye_white = undefined;
	}
}

function thrasher_skull_fire_cb( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump )
{
	if ( newval == 0 )
		self thread thrasher_skull_fire_do_fx( 0, localclientnum );
	else if ( newval == 1 )
		self thread thrasher_skull_fire_do_fx( 1, localclientnum );
		
}

function thrasher_skull_fire_do_fx( b_on, localclientnum )
{
	if ( b_on )
	{
		if ( !isDefined( self.a_skull_fx ) )
		{
			self.a_skull_fx = [];
			if ( !isDefined( self.a_skull_fx ) )
				self.a_skull_fx = [];
			else if ( !isArray( self.a_skull_fx ) )
				self.a_skull_fx = array( self.a_skull_fx );
			
			self.a_skull_fx[ self.a_skull_fx.size ] = playFxOnTag( localclientnum, level._effect[ "fx_fire_thrash_arm_left_loop" ], self, "j_shoulder_le" );
			if ( !isDefined( self.a_skull_fx ) )
				self.a_skull_fx = [];
			else if ( !isArray( self.a_skull_fx ) )
				self.a_skull_fx = array( self.a_skull_fx );
			
			self.a_skull_fx[ self.a_skull_fx.size ] = playFxOnTag( localclientnum, level._effect[ "fx_fire_thrash_arm_rgt_loop" ], self, "j_shoulder_ri" );
			if ( !isDefined( self.a_skull_fx ) )
				self.a_skull_fx = [];
			else if ( !isArray( self.a_skull_fx ) )
				self.a_skull_fx = array( self.a_skull_fx );
			
			self.a_skull_fx[ self.a_skull_fx.size ] = playFxOnTag( localclientnum, level._effect[ "fx_fire_thrash_leg_left_loop" ], self, "j_knee_le" );
			if ( !isDefined( self.a_skull_fx ) )
				self.a_skull_fx = [];
			else if ( !isArray( self.a_skull_fx ) )
				self.a_skull_fx = array( self.a_skull_fx );
			
			self.a_skull_fx[ self.a_skull_fx.size ] = playFxOnTag( localclientnum, level._effect[ "fx_fire_thrash_leg_rgt_loop" ], self, "j_knee_ri" );
			if ( !isDefined( self.a_skull_fx ) )
				self.a_skull_fx = [];
			else if ( !isArray( self.a_skull_fx ) )
				self.a_skull_fx = array( self.a_skull_fx );
			
			self.a_skull_fx[ self.a_skull_fx.size ] = playFxOnTag( localclientnum, level._effect[ "fx_fire_thrash_hip_left_loop" ], self, "j_hip_le" );
			if ( !isDefined( self.a_skull_fx ) )
				self.a_skull_fx = [];
			else if ( !isArray( self.a_skull_fx ) )
				self.a_skull_fx = array( self.a_skull_fx );
			
			self.a_skull_fx[ self.a_skull_fx.size ] = playFxOnTag( localclientnum, level._effect[ "fx_fire_thrash_hip_rgt_loop" ], self, "j_hip_ri" );
			if ( !isDefined( self.a_skull_fx ) )
				self.a_skull_fx = [];
			else if ( !isArray( self.a_skull_fx ) )
				self.a_skull_fx = array( self.a_skull_fx );
			
			self.a_skull_fx[ self.a_skull_fx.size ] = playFxOnTag( localclientnum, level._effect[ "fx_fire_thrash_torso_loop" ], self, "j_spineupper" );
			if ( !isDefined( self.a_skull_fx ) )
				self.a_skull_fx = [];
			else if ( !isArray( self.a_skull_fx ) )
				self.a_skull_fx = array( self.a_skull_fx );
			
			self.a_skull_fx[ self.a_skull_fx.size ] = playFxOnTag( localclientnum, level._effect[ "fx_fire_thrash_waist_loop" ], self, "j_spinelower" );
		}
	}
	else
	{
		foreach ( key, fx in self.a_skull_fx )
			stopFx( localclientnum, fx );
		
		self.a_skull_fx = undefined;
	}
}

function skull_emissive_cb( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump )
{
	if ( newval )
		self mapShaderConstant( localclientnum, 0, "scriptVector2", 1, 1, 1, 0 );
	
	else
		self mapShaderConstant( localclientnum, 0, "scriptVector2", 0, 0, 0, 0 );
	
}

function skull_torch_3p_fx_cb( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump )
{
	if ( isSpectating( localclientnum ) )
		return;
	
	player = getLocalPlayer( localclientnum );
	if ( newval == 1 )
	{
		if ( player != self )
			playFxOnTag( localclientnum, level._effect[ "torch_start_3p" ], self, "tag_flash" );
		
	}
	else if ( newval == 2 )
	{
		if ( player != self )
			self.fx_skull_torch_loop_3p = playFxOnTag( localclientnum, level._effect[ "torch_loop_3p" ], self, "tag_flash" );
		
	}
	else if ( player != self )
	{
		if ( isDefined( self.fx_skull_torch_loop_3p ) )
		{
			stopFx( localclientnum, self.fx_skull_torch_loop_3p );
			self.fx_skull_torch_loop_3p = undefined;
		}
	}
}

function skull_beam_3p_fx_cb( localclientnum, oldval, newval, bnewent, binitialsnap, fieldname, bwastimejump )
{
	if ( isSpectating( localclientnum ) )
		return;
	
	player = getLocalPlayer( localclientnum );
	if ( newval == 1 )
	{
		if ( player != self )
			playFxOnTag( localclientnum, level._effect[ "beam_start_3p" ], self, "tag_flash" );
		
	}
	else if ( newval == 2 )
	{
		if ( player != self )
			self.fx_skull_beam_loop_3p = playFxOnTag( localclientnum, level._effect[ "beam_loop_3p" ], self, "tag_flash" );
		
	}
	else if ( player != self )
	{
		if ( isDefined( self.fx_skull_beam_loop_3p ) )
		{
			stopFx( localclientnum, self.fx_skull_beam_loop_3p );
			self.fx_skull_beam_loop_3p = undefined;
		}
	}
}
