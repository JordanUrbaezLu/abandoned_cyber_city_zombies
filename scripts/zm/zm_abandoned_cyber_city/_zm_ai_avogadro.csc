#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\util_shared;
#using scripts\shared\system_shared;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

// Client side powerups functionality

#precache( "client_fx", "zombie/fx_avogadro_linger" );

#namespace zm_ai_avogadro;

REGISTER_SYSTEM( "zm_ai_avogadro", &init, undefined )

function init()
{
	clientfield::register( "scriptmover", 		"avogadro_fx",		VERSION_SHIP, 1, "int", &avogadro_fx,	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	init_avogadro_fx();
}

function init_avogadro_fx()
{
	level._effect[ "avogadro_trail" ]			= "zombie/fx_avogadro_linger";
}

function avogadro_fx( n_local_client, n_old, n_new, b_new_ent, b_initial_snap, str_field, b_was_time_jump )
{
	if(n_new == 1)
	{
		self.lingering_avogadro = PlayFxOnTag( n_local_client, level._effect[ "avogadro_trail" ], self, "tag_origin" );
		playsound( n_local_client, "avogadro_warp_in", self.origin  );
	}
	else if(n_new == 0)
	{
		StopFX( n_local_client, self.lingering_avogadro );
		playsound( n_local_client, "avogadro_warp_out", self.origin  );
	}
}