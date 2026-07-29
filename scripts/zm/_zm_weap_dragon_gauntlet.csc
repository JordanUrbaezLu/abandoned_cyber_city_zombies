// [acc] VENDORED VERBATIM from HarryBo21 Hero Weapons v2.0.0 (2026-07-24). Client FX for the
// Dragon Gauntlet - all local viewmodel FX + notetracks, ZERO clientfields (pool-safe).
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicles\_dragon_whelp;
#using scripts\zm\_callbacks;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache("client_fx", "dlc3/stalingrad/fx_dragon_gauntlet_glove_orange_glow1");
#precache("client_fx", "dlc3/stalingrad/fx_dragon_gauntlet_glove_orange_glow2");
#precache("client_fx", "dlc3/stalingrad/fx_dragon_gauntlet_whelp_eye_glow_sm");
#precache("client_fx", "dlc3/stalingrad/fx_dragon_gauntlet_whelp_mouth_drips_sm");
#precache("client_fx", "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow1");
#precache("client_fx", "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow2");
#precache("client_fx", "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow_finger");
#precache("client_fx", "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow_finger2");
#precache("client_fx", "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow_finger3");
#precache("client_fx", "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_tube");
#precache("client_fx", "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_tube2");

#namespace zm_weap_dragon_gauntlet;

REGISTER_SYSTEM_EX("zm_weap_dragon_gauntlet", &__init__, undefined, undefined)

function __init__()
{
	callback::on_localplayer_spawned( &player_on_spawned );
}

function player_on_spawned( localclientnum )
{
	self thread watch_weapon_changes( localclientnum );
}

function watch_weapon_changes( localclientnum )
{
	self endon( "disconnect" );
	self endon( "entityshutdown" );
	self.dragon_gauntlet_flamethrower = getWeapon( "dragon_gauntlet_flamethrower" );
	self.dragon_gauntlet = getWeapon( "dragon_gauntlet" );
	while ( isDefined( self ) )
	{
		self waittill( "weapon_change", weapon );
		if ( weapon === self.dragon_gauntlet_flamethrower )
		{
			self thread dragon_gauntlet_stop_fx( localclientnum );
			self thread dragon_gauntlet_flamethrower_do_fx( localclientnum );
			self notify( "dragon_gauntlet_stop_fx" );
		}
		if ( weapon === self.dragon_gauntlet )
		{
			self thread dragon_gauntlet_flamethrower_stop_fx( localclientnum );
			self thread dragon_gauntlet_do_fx( localclientnum );
			self thread dragon_gauntlet_melee_fx( localclientnum );
		}
		if ( weapon !== self.dragon_gauntlet_flamethrower && weapon !== self.dragon_gauntlet )
		{
			self dragon_gauntlet_flamethrower_stop_fx( localclientnum );
			self dragon_gauntlet_stop_fx( localclientnum );
			self notify( "dragon_gauntlet_stop_fx" );
		}
	}
}

function dragon_gauntlet_flamethrower_do_fx( localclientnum )
{
	self endon( "disconnect" );
	self util::waittill_any_timeout( .5, "weapon_change_complete", "disconnect" );
	if ( getCurrentWeapon( localclientnum ) === getWeapon( "dragon_gauntlet_flamethrower" ) )
	{
		if ( !isDefined( self.a_dragon_gauntlet_flamethrower_fx ) )
			self.a_dragon_gauntlet_flamethrower_fx = [];
		
		self.a_dragon_gauntlet_flamethrower_fx[ self.a_dragon_gauntlet_flamethrower_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_orange_glow1", "tag_fx_7" );
		self.a_dragon_gauntlet_flamethrower_fx[ self.a_dragon_gauntlet_flamethrower_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_orange_glow2", "tag_fx_6" );
		self.a_dragon_gauntlet_flamethrower_fx[ self.a_dragon_gauntlet_flamethrower_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_whelp_eye_glow_sm", "tag_eye_left_fx" );
		self.a_dragon_gauntlet_flamethrower_fx[ self.a_dragon_gauntlet_flamethrower_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_whelp_mouth_drips_sm", "tag_throat_fx" );
	}
}

function dragon_gauntlet_do_fx( localclientnum )
{
	self endon( "disconnect" );
	self util::waittill_any_timeout( .5, "weapon_change_complete", "disconnect" );
	if ( getCurrentWeapon( localclientnum ) === getWeapon( "dragon_gauntlet_flamethrower" ) )
	{
		if ( !isDefined( self.a_dragon_gauntlet_fx ) )
			self.a_dragon_gauntlet_fx = [];
		
		self.a_dragon_gauntlet_fx[ self.a_dragon_gauntlet_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow1", "tag_fx_7" );
		self.a_dragon_gauntlet_fx[ self.a_dragon_gauntlet_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow2", "tag_fx_6" );
		self.a_dragon_gauntlet_fx[ self.a_dragon_gauntlet_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow_finger2", "tag_fx_1" );
		self.a_dragon_gauntlet_fx[ self.a_dragon_gauntlet_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow_finger", "tag_fx_2" );
		self.a_dragon_gauntlet_fx[ self.a_dragon_gauntlet_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow_finger", "tag_fx_3" );
		self.a_dragon_gauntlet_fx[ self.a_dragon_gauntlet_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow_finger", "tag_fx_4" );
		self.a_dragon_gauntlet_fx[ self.a_dragon_gauntlet_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_tube", "tag_gauntlet_tube_01" );
		self.a_dragon_gauntlet_fx[ self.a_dragon_gauntlet_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_tube", "tag_gauntlet_tube_02" );
		self.a_dragon_gauntlet_fx[ self.a_dragon_gauntlet_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_tube", "tag_gauntlet_tube_03" );
		self.a_dragon_gauntlet_fx[ self.a_dragon_gauntlet_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_tube", "tag_gauntlet_tube_04" );
	}
}

function dragon_gauntlet_flamethrower_stop_fx( localclientnum )
{
	if ( isDefined( self.a_dragon_gauntlet_flamethrower_fx ) && self.a_dragon_gauntlet_flamethrower_fx.size > 0 )
	{
		foreach ( key, fx in self.a_dragon_gauntlet_flamethrower_fx )
			stopFx( localclientnum, fx );
		
	}
}

function dragon_gauntlet_stop_fx( localclientnum )
{
	if ( isDefined( self.a_dragon_gauntlet_fx ) && self.a_dragon_gauntlet_fx.size > 0 )
	{
		foreach ( key, fx in self.a_dragon_gauntlet_fx )
			stopFx( localclientnum, fx );
		
	}
}

function dragon_gauntlet_melee_fx( localclientnum )
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "bled_out" );
	self endon( "dragon_gauntlet_stop_fx" );
	self notify( "dragon_gauntlet_melee_fx" );
	self endon( "dragon_gauntlet_melee_fx" );
	while ( isDefined( self ) )
	{
		self waittill( "notetrack", note );
		if ( note === "dragon_gauntlet_115_punch_fx_start" )
		{
			if ( !isDefined( self.a_dragon_gauntlet_melee_fx ) )
				self.a_dragon_gauntlet_melee_fx = [];
			
			self.a_dragon_gauntlet_melee_fx[ self.a_dragon_gauntlet_melee_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow_finger3", "tag_fx_1" );
			self.a_dragon_gauntlet_melee_fx[ self.a_dragon_gauntlet_melee_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow_finger3", "tag_fx_2" );
			self.a_dragon_gauntlet_melee_fx[ self.a_dragon_gauntlet_melee_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow_finger3", "tag_fx_3" );
			self.a_dragon_gauntlet_melee_fx[ self.a_dragon_gauntlet_melee_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_glow_finger3", "tag_fx_4" );
			self.a_dragon_gauntlet_melee_fx[ self.a_dragon_gauntlet_melee_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_tube2", "tag_gauntlet_tube_01" );
			self.a_dragon_gauntlet_melee_fx[ self.a_dragon_gauntlet_melee_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_tube2", "tag_gauntlet_tube_02" );
			self.a_dragon_gauntlet_melee_fx[ self.a_dragon_gauntlet_melee_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_tube2", "tag_gauntlet_tube_03" );
			self.a_dragon_gauntlet_melee_fx[ self.a_dragon_gauntlet_melee_fx.size ] = playViewModelFx( localclientnum, "dlc3/stalingrad/fx_dragon_gauntlet_glove_blue_tube2", "tag_gauntlet_tube_04" );
		}
		if ( note === "dragon_gauntlet_115_punch_fx_stop" )
		{
			if ( isDefined( self.a_dragon_gauntlet_melee_fx ) && self.a_dragon_gauntlet_melee_fx.size > 0 )
			{
				foreach ( var_7edb8e34, fx in self.a_dragon_gauntlet_melee_fx )
					stopFx( localclientnum, fx );
				
			}
		}
	}
}
