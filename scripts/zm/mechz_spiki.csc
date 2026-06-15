#using scripts\shared\system_shared;
#using scripts\shared\visionset_mgr_shared;
//#using scripts\zm\_zm_elemental_zombies;
#using scripts\shared\ai_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\duplicaterender_mgr;
#using scripts\shared\postfx_shared;
#using scripts\shared\system_shared;


#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace mechz_spiki;


#precache( "client_fx", "dlc4/genesis/fx_mech_spawn");
#precache( "client_fx", "dlc4/genesis/fx_elec_trap_body_shock");

#precache( "client_fx", "dlc5/tomb/fx_tomb_mech_death");
#precache( "client_fx", "maps/zombie_tomb/fx_tomb_mech_dmg_sparks");
#precache( "client_fx", "maps/zombie_tomb/fx_tomb_mech_dmg_steam");
#precache( "client_fx", "maps/zombie_tomb/fx_tomb_mech_jump_landing");
#precache( "client_fx", "dlc5/tomb/fx_tomb_mech_wpn_claw");
#precache( "client_fx", "dlc5/tomb/fx_tomb_mech_wpn_source");



#precache( "client_fx", "electric/fx_ability_elec_surge_short_robot_optim");
#precache( "client_fx", "explosions/fx_ability_exp_ravage_core_optim");
#precache( "client_fx", "fire/fx_embers_burst_optim");
#precache( "client_fx", "explosions/fx_exp_dest_barrel_concussion_sm_optim");
#precache( "client_fx", "light/fx_light_spark_chest_zombie_optim");
#precache( "client_fx", "electric/fx_elec_sparks_burst_blue_optim");



REGISTER_SYSTEM( "zm_ai_mechz", &__init__, undefined )



function __init__()
{
	visionset_mgr::register_overlay_info_style_burn("mechz_player_burn", 5000, 15, 1.5);

	level._effect["mechz_ground_spawn"] = "dlc4/genesis/fx_mech_spawn";	
	level._effect["tesla_zombie_shock"] = "dlc4/genesis/fx_elec_trap_body_shock";
	

	clientfield::register("actor", "mechz_fx", VERSION_DLC5, 1, "int", &function_22b149ce, 0, 0);
	clientfield::register("scriptmover", "mechz_claw", VERSION_DLC5, 1, "int", &mechz_claw_cb, 0, 0);
	clientfield::register("actor", "mechz_wpn_source", VERSION_DLC5, 1, "int", &mechz_wpn_source_cb, 0, 0);
	clientfield::register("toplayer", "mechz_grab", VERSION_DLC5, 1, "int", &mechz_grab_cb, 0, 0);

	clientfield::register("actor", "death_ray_shock_fx", 15000, 1, "int", &mechz_zombie_shock_fx, 0, 0);
	clientfield::register("actor", "mechz_fx_spawn", 15000, 1, "counter", &mechz_spawn_fx_cb, 0, 0);


	level.mechz_detach_claw_override = &mechz_detach_claw_override;


	level._effect["mechz_death"] = "dlc5/tomb/fx_tomb_mech_death";
	level._effect["mechz_sparks"] = "maps/zombie_tomb/fx_tomb_mech_dmg_sparks";
	level._effect["mechz_steam"] = "maps/zombie_tomb/fx_tomb_mech_dmg_steam";
	level._effect["mech_booster_landing"] = "maps/zombie_tomb/fx_tomb_mech_jump_landing";
	level._effect["mechz_claw"] = "dlc5/tomb/fx_tomb_mech_wpn_claw";
	level._effect["mechz_wpn_source"] = "dlc5/tomb/fx_tomb_mech_wpn_source";

/*
	clientfield::register("actor", "sparky_zombie_spark_fx", 1, 1, "int", &sparky_zombie_spark_fx, 0, 0);
	clientfield::register("actor", "sparky_zombie_death_fx", 1, 1, "int", &sparky_zombie_death_fx, 0, 0);
	clientfield::register("actor", "napalm_zombie_death_fx", 1, 1, "int", &napalm_zombie_death_fx, 0, 0);
	clientfield::register("actor", "sparky_damaged_fx", 1, 1, "counter", &sparky_damaged_fx, 0, 0);
	clientfield::register("actor", "napalm_damaged_fx", 1, 1, "counter", &napalm_damaged_fx, 0, 0);
	clientfield::register("actor", "napalm_sfx", 11000, 1, "int", &napalm_sfx, 0, 0);
*/
	level._effect["elemental_zombie_sparky"] = "electric/fx_ability_elec_surge_short_robot_optim";
	level._effect["elemental_sparky_zombie_suicide"] = "explosions/fx_ability_exp_ravage_core_optim";
	level._effect["elemental_zombie_fire_damage"] = "fire/fx_embers_burst_optim";
	level._effect["elemental_napalm_zombie_suicide"] = "explosions/fx_exp_dest_barrel_concussion_sm_optim";
	level._effect["elemental_zombie_spark_light"] = "light/fx_light_spark_chest_zombie_optim";
	level._effect["elemental_electric_spark"] = "electric/fx_elec_sparks_burst_blue_optim";
}



function mechz_zombie_shock_fx(localclientnum, oldval, newval, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	self function_51adc559(localclientnum);
	if(newval)
	{
		if(!isdefined(self.var_8f44671e))
		{
			tag = "J_SpineUpper";
			if(!self isai())
			{
				tag = "tag_origin";
			}
			self.var_8f44671e = PlayFXOnTag(localclientnum, level._effect["tesla_zombie_shock"], self, tag);
			self playsound(0, "zmb_electrocute_zombie");
		}
		if(IsDemoPlaying())
		{
			self thread function_7772592b(localclientnum);
		}
	}
}


function function_7772592b(localclientnum)
{
	self notify("hash_51adc559");
	self endon("hash_51adc559");
	level waittill("demo_jump");
	self function_51adc559(localclientnum);
}


function function_51adc559(localclientnum)
{
	if(isdefined(self.var_8f44671e))
	{
		deletefx(localclientnum, self.var_8f44671e, 1);
		self.var_8f44671e = undefined;
	}
	self notify("hash_51adc559"); //???
}






function napalm_zombie_death_fx(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	self util::waittill_dobj(localClientNum);
	if(!isdefined(self))
	{
		return;
	}
	if(oldVal !== newVal && newVal === 1)
	{
		FX = PlayFXOnTag(localClientNum, level._effect["elemental_napalm_zombie_suicide"], self, "j_spineupper");
		self playsound(0, "zmb_elemental_zombie_explode_fire");
	}
}


function napalm_damaged_fx(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	self endon("entityshutdown");
	self util::waittill_dobj(localClientNum);
	if(!isdefined(self))
	{
		return;
	}
	if(newVal)
	{
		if(isdefined(level._effect["elemental_zombie_fire_damage"]))
		{
			playsound(localClientNum, "gdt_electro_bounce", self.origin);
			locs = Array("j_wrist_le", "j_wrist_ri");
			FX = PlayFXOnTag(localClientNum, level._effect["elemental_zombie_fire_damage"], self, Array::random(locs));
			SetFXIgnorePause(localClientNum, FX, 1);
		}
	}
}


function napalm_sfx(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if(newVal == 1)
	{
		if(!isdefined(self.var_1f5b576b))
		{
			self.var_1f5b576b = self PlayLoopSound("zmb_elemental_zombie_loop_fire", 0.2);
		}
	}
}


function sparky_zombie_spark_fx(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if(!isdefined(newVal))
	{
		return;
	}
	if(newVal == 1)
	{
		if(!isdefined(self.var_e863c331))
		{
			self.var_e863c331 = self PlayLoopSound("zmb_electrozomb_lp", 0.2);
		}
		str_tag = "J_SpineUpper";
		if(isdefined(self.var_46d9c2ee))
		{
			str_tag = self.var_46d9c2ee;
		}
		str_fx = level._effect["elemental_zombie_sparky"];
		if(isdefined(self.var_7abb4217))
		{
			str_fx = self.var_7abb4217;
		}
		FX = PlayFXOnTag(localClientNum, str_fx, self, str_tag);
		SetFXIgnorePause(localClientNum, FX, 1);
		var_4473cd0 = level._effect["elemental_zombie_spark_light"];
		if(isdefined(self.var_e22d3880))
		{
			var_4473cd0 = self.var_e22d3880;
		}
		FX = PlayFXOnTag(localClientNum, var_4473cd0, self, str_tag);
		SetFXIgnorePause(localClientNum, FX, 1);
	}
}


function sparky_zombie_death_fx(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	if(oldVal !== newVal && newVal === 1)
	{
		FX = PlayFXOnTag(localClientNum, level._effect["elemental_sparky_zombie_suicide"], self, "j_spineupper");
		self playsound(0, "zmb_elemental_zombie_explode_elec");
	}
}


function sparky_damaged_fx(localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump)
{
	self endon("entityshutdown");
	self util::waittill_dobj(localClientNum);
	if(!isdefined(newVal))
	{
		return;
	}
	self util::waittill_dobj(localClientNum);
	if(!isdefined(self))
	{
		return;
	}
	if(newVal >= 1)
	{
		if(!isdefined(self.var_e863c331))
		{
			self.var_e863c331 = self PlayLoopSound("zmb_electrozomb_lp", 0.2);
		}
		FX = PlayFXOnTag(localClientNum, level._effect["elemental_electric_spark"], self, "J_SpineUpper");
		SetFXIgnorePause(localClientNum, FX, 1);
	}
}





function mechz_spawn_fx_cb(localclientnum, oldValue, newvalue, bNewEnt, bInitialSnap, fieldName, wasDemoJump)
{
	if(newvalue)
	{
		self.spawnfx = PlayFXOnTag(localclientnum, level._effect["mechz_ground_spawn"], self, "tag_origin");
		playsound(0, "zmb_mechz_spawn_nofly", self.origin);
	}
}



function private mechz_detach_claw_override(localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump)
{
	pos = self GetTagOrigin("tag_claw");
	ang = self GetTagAngles("tag_claw");
	velocity = self GetVelocity();
	//dynEnt = CreateDynEntAndLaunch(localClientNum, "c_t7_zm_dlchd_origins_mech_claw_lod0", pos, ang, self.origin, velocity);
	PlayFXOnTag(localClientNum, level._effect["fx_mech_dmg_armor"], self, "tag_grappling_source_fx");
	self playsound(0, "zmb_ai_mechz_destruction");
	PlayFXOnTag(localClientNum, level._effect["fx_mech_dmg_sparks"], self, "tag_grappling_source_fx");
}



function private function_22b149ce(localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump)
{
//was empty function

	if(newValue)
		{

		}
	if(newValue == 1)
		{
		PlayFXOnTag(localClientNum, level._effect["mechz_death"], self, "tag_origin");
		}

}



function private mechz_claw_cb(localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump)
{
	if(newValue)
		{
		PlayFXOnTag(localClientNum, level._effect["mechz_claw"], self, "tag_origin");
		}

}



function private mechz_wpn_source_cb(localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump)
{
	if(newValue)
	{
		self.var_ba7e45cf = PlayFXOnTag(localClientNum, level._effect["mechz_wpn_source"], self, "j_elbow_le");
	}
	else if(isdefined(self.var_ba7e45cf))
	{
		stopfx(localClientNum, self.var_ba7e45cf);
		self.var_ba7e45cf = undefined;
	}
}



function private mechz_grab_cb(localClientNum, oldValue, newValue, bNewEnt, bInitialSnap, fieldName, wasDemoJump)
{
	if(newValue)
	{
		self HideViewLegs();
	}
	else
	{
		self ShowViewLegs();
	}
}
