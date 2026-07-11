#using scripts\codescripts\struct;

#using scripts\shared\clientfield_shared;
#using scripts\shared\util_shared;
#using scripts\shared\system_shared;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

// Client side powerups functionality

#precache( "client_fx", "zombie/fx_avogadro_linger" );
#precache( "client_fx", "zombie/fxt/fx_tesla_bolt_secondary_zmb" );   // [acc] bolt-projectile arc (zone-listed)

#namespace zm_ai_avogadro;

REGISTER_SYSTEM( "zm_ai_avogadro", &init, undefined )

function init()
{
	clientfield::register( "scriptmover", 		"avogadro_fx",		VERSION_SHIP, 1, "int", &avogadro_fx,	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	// [acc] BOLT PROJECTILE (2026-07-06, user: "hard to see his projectile / align the sfx"): the thrown
	// bolt's own field. 1 = launch (stack BOTH the linger crackle AND the bright tesla arc on the mover +
	// the throw bark, positional); 0 = impact (StopFX both + the warp-out fizzle). All CLIENT-side - the
	// server half is mute on purpose (server PlaySound on actors is dead in this build).
	clientfield::register( "scriptmover", 		"acc_avo_bolt_fx",	VERSION_SHIP, 1, "int", &acc_avo_bolt_fx,	!CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );

	init_avogadro_fx();
}

function init_avogadro_fx()
{
	level._effect[ "avogadro_trail" ]			= "zombie/fx_avogadro_linger";
	level._effect[ "acc_avo_bolt_arc" ]			= "zombie/fxt/fx_tesla_bolt_secondary_zmb";
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
		// [acc] guard (2026-07-06 coop sweep): a join-in-progress initial snapshot delivers field=0
		// without the 1-branch ever running on this client, so the handle is undefined - StopFX on it
		// is a client script error. Same pattern as the bolt handler below.
		if ( isdefined( self.lingering_avogadro ) )
			StopFX( n_local_client, self.lingering_avogadro );
		playsound( n_local_client, "avogadro_warp_out", self.origin  );
	}
}

// [acc] The thrown BOLT projectile (2026-07-06). Two stacked FX so it reads at a glance (the linger
// crackle alone was "a bit hard to see" - user): the body-crackle cloud + the bright tesla arc, both
// LOOPING but self-cleaning (StopFX on 0, and the mover itself is Delete()d right after). Sounds are
// played HERE, positionally at the bolt, so audio is frame-locked to what you see: "avogadro_attack"
// exactly when the bolt leaves his hand, "avogadro_warp_out" exactly when it detonates. (The victim's
// own zap sting - acc_phantom_zap - is server-side ON the player in _acc_elites::acc_avogadro_zap,
// which works; it's AI-actor PlaySound that's dead in this build.)
function acc_avo_bolt_fx( n_local_client, n_old, n_new, b_new_ent, b_initial_snap, str_field, b_was_time_jump )
{
	if ( n_new == 1 )
	{
		self.acc_bolt_fx_crackle = PlayFxOnTag( n_local_client, level._effect[ "avogadro_trail" ], self, "tag_origin" );
		self.acc_bolt_fx_arc     = PlayFxOnTag( n_local_client, level._effect[ "acc_avo_bolt_arc" ], self, "tag_origin" );
		playsound( n_local_client, "avogadro_attack", self.origin );
	}
	else if ( n_new == 0 )
	{
		if ( isdefined( self.acc_bolt_fx_crackle ) )
			StopFX( n_local_client, self.acc_bolt_fx_crackle );
		if ( isdefined( self.acc_bolt_fx_arc ) )
			StopFX( n_local_client, self.acc_bolt_fx_arc );
		playsound( n_local_client, "avogadro_warp_out", self.origin );
	}
}