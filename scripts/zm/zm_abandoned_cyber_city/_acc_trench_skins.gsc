// =============================================================================
// _acc_trench_skins.gsc - UNDERGROUND zombie reskin (user 2026-07-03: "any
// zombie that spawns in from the trench needs its own skin ... all zombies
// that spawn below base level (trenches and paradise)").
//
// SKIN: Kingslayer Kyle's BOTD (Blood of the Dead) mob zombies - BO4 Alcatraz
// prisoner horde (self-contained materials). PICKED 2026-07-03 after the first
// choice (Zeroy's 54 Immortals) rendered HEADLESS ("looks half baked"); 54i
// stays installed as fallback, Ascension zip = 2nd fallback (CREDITS.md).
//
// THE SKIN IS A GAMEPLAY SIGNAL (user 2026-07-03): ONE fixed body per class so
// players can instantly read which zombies count towards the round:
//   charred             = surface round zombie
//   BARBED WIRE (body1) = trench/underground spawn   (this module; no_gib)
//   CHAIN ARMOR (body3) = Shielded "armored" elite    (_acc_elites; no_gib)
// Heads still vary (identity lives in the body). Both special skins are
// no_gib so the wire/armor never comes off.
// Idiom: SetModel(body) + Detach the charred head + Attach(mob head) - the
// original Glitch-Stalker der-skin recipe (head models self-align to the
// shared zombie skeleton). NO SetScale (the confirmed live-AI crasher).
//
// GATE: spawn-position z <= -36 (mirrors _acc_bus_trench's file-local
// ACC_UNDER_Z lip). A pure HEIGHT check on purpose - underground_layer()
// excludes the descent hallway/second-part/Exchange for its GAMEPLAY amping,
// but the skin rule is visual: everything below base level (trench floors,
// under-rooms, abyss, Paradise) reads as the underground faction. Zombies that
// spawn on the surface and walk down keep the charred skin (spawn-time skin,
// per the user's "any zombie that SPAWNS IN from the trench").
//
// HOOK: chains level.zombie_init_done (the same per-zombie post-init chain
// _acc_elites uses for its depth-Shielded roll; both links save+call the
// previous hook, so order is safe). Runs AFTER elites' roll (acc_main init
// order), so a depth-Shielded promo keeps its back-shield - Attach'd models
// survive SetModel; j_spine4 exists on all zombie-skeleton bodies.
//
// KNOWN COSMETIC LIMIT: gib pieces (shot-off limbs) still pop the CHARRED
// character's gib set - the gibDef lives on the spawned character, not the
// SetModel body. Same compromise the Glitch/Phantom toxic skins made.
// Toggle: acc_trench_skins 0 (live).
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#namespace acc_trench_skins;

#define ACC_TRENCH_SKIN_Z -36   // mirror of _acc_bus_trench ACC_UNDER_Z (file-local there)

function init()
{
	// Per-zombie post-init chain (elites' depth-Shielded hook pattern): save the previous
	// link, install ours, call the previous FIRST inside the hook.
	level.acc_skin_zid_prev = level.zombie_init_done;
	level.zombie_init_done = &trench_skin_init_hook;
	acc_utility::log( "trench skins init (54i underground bodies, z <= " + ACC_TRENCH_SKIN_Z + ")" );
}

// self = a fully-init'd zombie (coop HP + elites' depth roll already applied).
function trench_skin_init_hook()
{
	if ( isdefined( level.acc_skin_zid_prev ) ) self [[ level.acc_skin_zid_prev ]]();
	self thread trench_skin_roll();
}

// THREADED with a short delay (2026-07-03 fix, "zombies were still charred"): at
// zombie_init_done time EVERY zombie sits at the single factory actor spawner (z=208,
// surface) - stock spawn_zombie does `guy forceteleport( spawner.origin )` and only
// AFTERWARDS moves it to its riser struct. A same-frame z-check therefore reads 208 for
// every spawn and never passes. 0.3s later the zombie is at its real rise point - and
// risers spend 1-2s UNDER the floor playing the rise anim, so the delayed swap is
// invisible to players. (NOTE: _acc_elites' depth-Shielded roll reads origin in the same
// hook and likely has the same latent miss - flagged in CHANGELOG, not touched here.)
function trench_skin_roll()
{
	self endon( "death" );
	wait 0.3;

	if ( !isdefined( self ) || !isalive( self ) ) return;
	if ( getdvarint( "acc_trench_skins", 1 ) != 1 ) return;
	// Bosses keep their own skins (Glitch toxic / Phantom toxic / Rogue Protector gold).
	if ( IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) || IS_TRUE( self.is_boss ) ) return;
	// Shielded/elite zombies wear the ARMORED body (promote_to_shielded, user 2026-07-03) -
	// never restyle them here (and never re-skin anything already skinned).
	if ( IS_TRUE( self.acc_is_shielded ) || IS_TRUE( self.acc_is_elite ) || IS_TRUE( self.acc_trench_skinned ) ) return;
	if ( self.origin[ 2 ] > getdvarfloat( "acc_trench_skin_z", ACC_TRENCH_SKIN_Z ) ) return;

	// ONE FIXED BODY for every trench zombie (user 2026-07-03): the BARBED-WIRE body (body1 -
	// its bin carries the barbwire material), uniform on purpose - the skin is a GAMEPLAY
	// SIGNAL ("easy for players to identify trench zombies so they know which zombies count
	// towards the round or not"): charred = surface round zombie, barbed wire = trench spawn,
	// chain-armor body = Shielded elite (promote_to_shielded). Heads still vary (identity is
	// the body). no_gib like the elite - the wire never comes off. acc_trench_body live dial.
	a_heads  = array( "c_t8_zmb_mob_zombie_head1", "c_t8_zmb_mob_zombie_head2", "c_t8_zmb_mob_zombie_head3", "c_t8_zmb_mob_zombie_head4" );
	self SetModel( "c_t8_zmb_mob_zombie_body" + getdvarint( "acc_trench_body", 1 ) );
	self Detach( "c_zom_dlc4_zombie_charred_head" );   // drop the charred head...
	self Attach( a_heads[ acc_utility::acc_rand_int( a_heads.size ) ] );   // ...attach a mob head (self-aligns)
	self.no_gib = true;   // wire stays on (stock-honored flag; same as the armored elite)
	self.acc_trench_skinned = true;

	// Dev proof-of-life: announce the FIRST skinned zombie once per game (on-screen + log).
	if ( 0 )   // [BOTD] dev proof-of-life print REMOVED 2026-07-10 (clean screen); restore !IS_TRUE(acc_trench_skin_seen) && IS_TRUE(acc_dev) to re-enable
	{
		level.acc_trench_skin_seen = true;
		players = GetPlayers();
		if ( players.size > 0 && isdefined( players[ 0 ] ) )
			players[ 0 ] IPrintLnBold( "^6[BOTD] first underground skin applied (z=" + int( self.origin[ 2 ] ) + ")" );
	}
}
