#using scripts\codescripts\struct;

#using scripts\shared\aat_shared;
#using scripts\shared\array_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\demo_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\animation_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_bgb;
#using scripts\zm\_zm_daily_challenges;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_pack_a_punch_util;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

// [acc] Abandoned Cyber City integration (2026-07-12): firesale/Armory pricing helpers
// live in _acc_perk_info (the per-run box-pool weighting hook is reached through the
// level.CustomRandomWeaponWeights pointer, no #using needed); _acc_map_randomizer supplies
// wonder_cap_key() = the canonical "is this one of the 5 wonder weapons" test (gold holo).
// Directive-order rule: every #using must precede #namespace.
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_info;
#using scripts\zm\zm_abandoned_cyber_city\_acc_map_randomizer;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_usage;   // acc_gun_id() for the box gun card (2026-07-13)

#namespace aw_mbox;

REGISTER_SYSTEM_EX("aw_mbox", &__init__, &__main__, undefined)

//*****************************************************************************
// MAIN
//*****************************************************************************

#define DEFAULT_CHEST_COST 950
#define HINT_AWAY_PRINTER "^33D PRINTER MALFUNCTION^7"

#using_animtree( "generic" );
#precache("fx", "_custom/atlas/aw_magicbox_open");
#precache("fx", "_custom/atlas/aw_idle_box_fx");
#precache("fx", "_custom/atlas/aw_idle_box_off_fx");

function __init__(){
	// [acc] widened 1 -> 2 bits for the gold wonder holo (0 = off, 1 = cyan, 2 = GOLD).
	// MUST stay in lockstep with the client registration in _zm_aw_mysterybox.csc __init__.
	clientfield::register( "scriptmover", "exo_magicbox_dr_holo", VERSION_SHIP, 2, "int" );
}

function __main__(){

	exo_mysterybox_loc = struct::get_array("aw_exo_mysterybox_location");
	exo_mysterybox_loc = array::randomize(exo_mysterybox_loc);

	level._effect["idle_box_fx"] = "_custom/atlas/aw_idle_box_fx";
	level._effect["idle_box_off_fx"] = "_custom/atlas/aw_idle_box_off_fx";

	level.chest_accessed = 0; //Keeps track of how many times the box is opened
    level.chest_moves = 1; //Keeps track of how many times the box moved
    level.available_chests = []; //Used anywhere
	exo_mbox_starting_locs = []; //Used here

	wait(0.05);

	foreach( box in exo_mysterybox_loc ){ //Inits all boxes, if script_noteworthy is equal to "starting_loc" it will be kept for random box spawing
		// [acc] VENDOR BUG FIX: was self.script_noteworthy (self = level here), so tagged
		// start locations were NEVER detected and the start box landed randomly.
		if(isdefined(box.script_noteworthy) && box.script_noteworthy == "starting_loc")
			exo_mbox_starting_locs[exo_mbox_starting_locs.size] = box;
		box init_weaponbox(); // Setsup each box.
	}

	// [acc] VENDOR BUG FIX: was `size > 1`, so exactly ONE tagged start location fell into
	// the random branch. Our plaza struct carries script_noteworthy "starting_loc" in the
	// .map - the start box is ALWAYS the plaza, every run (user rule since 2026-06-18).
	if(exo_mbox_starting_locs.size > 0){
		exo_mbox_starting_locs = array::randomize(exo_mbox_starting_locs);
		starting_chest = exo_mbox_starting_locs[0];
	}
	else{
		starting_chest = exo_mysterybox_loc[0];
	}

    if(!(exo_mysterybox_loc.size > 1)) starting_chest.is_static = 1; //if there's one box then theres no need to do
        // do all the moving logic

    level.available_chests = exo_mysterybox_loc; //Save all locations for later

	// [acc] point chest_index at the ACTUAL start chest (vendor hardcoded 0; with the plaza
	// pinned via starting_loc, get_next_chest_index could otherwise "move" the box onto the
	// location it already occupies).
	level.chest_index = 0;
	for( i = 0; i < level.available_chests.size; i++ )
	{
		if( level.available_chests[ i ] == starting_chest )
			level.chest_index = i;
	}
	level.starting_chest = starting_chest;
	level.starting_chest thread spawn_chest(); //Spawn the box at the starting loc
	level.starting_chest thread box_encounter_vo(); //Setup encounter gvox

	// [acc] FIRESALE integration (user 2026-07-12 "firesale doesn't work with the new box"), two parts:
	// 1) DROPS: stock func_should_drop_fire_sale (_zm_powerup_fire_sale.gsc:244) refuses while
	//    level.chest_moves < 1 - and stock _zm_magicbox::treasure_chest_init STILL RUNS (it just finds
	//    ZERO treasure_chest_use structs now that the stock chests are deleted from the .map) and
	//    resets chest_moves to 0 after our init; with no stock chests nothing ever increments it again,
	//    so fire sale NEVER dropped. Re-point the registered should-drop hook at OUR driver's state
	//    (the printer is always visible, so the stock "box must have moved first" rule is meaningless).
	if ( isdefined( level.zombie_powerups ) && isdefined( level.zombie_powerups[ "fire_sale" ] ) )
		level.zombie_powerups[ "fire_sale" ].func_should_drop_with_regular_powerups = &acc_firesale_should_drop;
	// 2) THE SALE ITSELF: stock lights up every chest location for the sale window (toggle_fire_sale_on
	//    loops level.chests - empty for us). Mirror it for the printer pads. "powerup fire sale" /
	//    "fire_sale_off" fire from stock start_fire_sale with NO chest dependency (verified
	//    _zm_powerup_fire_sale.gsc:69/94), and the effective price is already $10 everywhere via
	//    acc_box_effective_cost. Grab-side stays stock (announcer vox, timer, extend-on-double-grab).
	level thread acc_firesale_watcher();
}

// [acc] fire_sale should-drop, AW-printer edition (2026-07-12): droppable whenever a sale isn't
// already running and the printer network exists. level.disable_firesale_drop is stock's
// "previous sale still winding down" latch (start_fire_sale sets it; with zero stock chests
// check_to_clear_fire_sale clears it immediately after the sale ends).
function acc_firesale_should_drop()
{
	if ( IS_TRUE( level.zombie_vars[ "zombie_powerup_fire_sale_on" ] ) || IS_TRUE( level.disable_firesale_drop ) )
		return false;
	return ( isdefined( level.available_chests ) && level.available_chests.size > 0 );
}

// [acc] For the sale window every dormant printer pad becomes a live box (stock temp-chest
// behavior), each with the stock fire-sale music loop; when the sale ends the temps retire back
// to the away-hologram state. The CURRENT pad is left alone (already live, price handled).
function acc_firesale_watcher()
{
	for ( ;; )
	{
		level waittill( "powerup fire sale" );
		temps = [];
		snd_ents = [];
		foreach ( c in level.available_chests )
		{
			if ( c == level.available_chests[ level.chest_index ] )
				continue;
			temps[ temps.size ] = c;
			c thread spawn_chest();
		}
		// stock sndFiresaleMusic_Start loops over level.chests (empty now) - play the loop at every pad ourselves
		foreach ( c in level.available_chests )
		{
			snd = spawn( "script_origin", c.origin + ( 0, 0, 100 ) );
			snd playloopsound( "mus_fire_sale", 1 );
			snd_ents[ snd_ents.size ] = snd;
		}
		level waittill( "fire_sale_off" );
		foreach ( snd in snd_ents )
			snd delete();
		foreach ( c in temps )
			c thread acc_firesale_retire();
	}
}

// [acc] Wind a temp sale pad back down to dormant. waiting_to_spawn is the vendor's own (never
// previously set) respawn-block hook checked by box_get_weapon / wpn_box_timeout / box_move_away -
// setting it lets an in-flight print/take finish, then stops the auto-respawn so we can retire.
// self = the pad struct.
function acc_firesale_retire()
{
	self.waiting_to_spawn = true;
	while ( self.state != "close" )   // let an in-flight print/take finish first (stock temp-box rule)
		wait 0.25;
	if ( IS_TRUE( level.zombie_vars[ "zombie_powerup_fire_sale_on" ] ) )
	{
		// a NEW sale started while winding down -> stay live for it
		self.waiting_to_spawn = undefined;
		self thread spawn_chest();
		return;
	}
	if ( level.available_chests[ level.chest_index ] == self )
	{
		// the roaming box landed on this pad post-sale -> it IS the live box now, leave it
		self.waiting_to_spawn = undefined;
		return;
	}
	self thread reset_chest();
	self thread set_up_unitrigger( 64, 64, 64, false, HINT_AWAY_PRINTER, undefined, &trigger_update_prompt_default );
	self.state = "close";
	self.waiting_to_spawn = undefined;
}

function reset_chest(){ //This function resets any location (self = struct) to it's default proprieties
	self notify("stop_cycle");

	self zm_unitrigger::unregister_unitrigger(self.unitrigger_stub);

	self.actual_weapon = level.weaponNone; //set the weapon to none to avoid issues
	self.grabber = undefined;
	self.model SetModel("tag_origin"); //The cycling model set to inbisible
	self.model clientfield::set("exo_magicbox_dr_holo", 1); //Make the clone glow
	self.model Show(); //Set to show to reset the blinking in cause it was left on self Ghost();
	if(isdefined(self.fxmodel))
		self.fxmodel Delete();
	self.fxmodel = util::spawn_model( "tag_origin", self.animmodel.origin, self.animmodel.angles );
	PlayFXOnTag(level._effect["idle_box_off_fx"], self.fxmodel, "tag_origin");
}

function init_weaponbox(){ //Init any location to be usable in the script
	if( !isdefined(self) || !level.enable_magic) //If the struct was deleted or magic was disabled then do nothing
		return;

	if(!isdefined(self.chest_cost))
		self.chest_cost = DEFAULT_CHEST_COST;

	self.model = util::spawn_model( "tag_origin", self.origin, self.angles ); //Spawn a model used for weapon cycle
	self.actual_weapon = level.weaponNone; //Var used to keep track of which weapon to give
	self.animmodel = GetEnt(self.target, "targetname"); //Get the animated model for animations
	self.animmodel UseAnimTree( #animtree ); //Enable animations
	if(isdefined(self.fxmodel)) self.fxmodel Delete();
	self.fxmodel = util::spawn_model( "tag_origin", self.animmodel.origin, self.animmodel.angles );
	self.state = "close";
	self.grabber = undefined;
    //Spawn an unitrigger helping the player know if the box is active or not
	self thread set_up_unitrigger(64, 64, 64, false, HINT_AWAY_PRINTER, undefined, &trigger_update_prompt_default);
	PlayFXOnTag(level._effect["idle_box_off_fx"], self.fxmodel, "tag_origin");
}

function spawn_chest(){ //make a box location usable, self is struct
	// [acc] per-pad re-entrancy latch (review 2026-07-15): a fire sale grabbed WHILE the box is mid
	// teddy-move makes acc_firesale_watcher (spawns every pad != old chest_index) and box_move_away
	// (spawns the NEW chest_index) both thread spawn_chest on the SAME destination pad. Two concurrent
	// runs double-register the use-unitrigger - the 2nd set_up_unitrigger overwrites self.unitrigger_stub,
	// orphaning the 1st's registered trigger (a phantom "print from" trigger) - and start two cycle_weapons
	// threads. The check-and-set below is atomic under GSC's cooperative scheduler (no yield between them),
	// so the 2nd invocation cleanly yields to the 1st; the pad still ends up live exactly once. Sequential
	// respawns (box taken -> respawn) are unaffected: the latch clears at the end of each run.
	if ( IS_TRUE( self.acc_spawning ) )
		return;
	self.acc_spawning = true;

	while(self.state != "close"){
		wait 0.05;
	}
	self reset_chest(); //Reset the basic proprieties
	wait 0.05;
	self thread cycle_weapons(); //Start cycling through weapons
	wait 0.05;
	if(isdefined(self.fxmodel)) self.fxmodel Delete();
	self.fxmodel = util::spawn_model( "tag_origin", self.animmodel.origin, self.animmodel.angles );
	PlayFXOnTag(level._effect["idle_box_fx"], self.fxmodel, "tag_origin");
	//self.state = "open";
	self.animmodel PlaySound("interact_mystery_box_ready"); //Notify the player that the box is ready
    //Setup the trigger for use
	WAIT_SERVER_FRAME;
	// [acc] hint says "Mystery Box" so the LUI cursor-hint router (ZMCursorHintNew.lua)
	// classifies it as the box card at ANY price (the vendor's router cue was the literal
	// price, which breaks under the firesale $10 / Armory 10%-off). "print from" avoids the
	// " for " wallbuy matcher. The price is re-rendered per frame by
	// trigger_update_prompt_default via acc_box_effective_cost().
	c = self acc_box_effective_cost();
	self set_up_unitrigger(64, 64, 64, false, "Hold ^3[{+activate}]^7 to print from the Mystery Box [ Cost: " + c + " ]", &box_bought, &trigger_update_prompt_default);
	self.acc_spawning = undefined;   // [acc] release the re-entrancy latch (review 2026-07-15) - setup complete, pad is live
}

// [acc] The ONE place the box's effective price is computed - the affordability gate, the
// charge, the teddy refund, and the live hint all use it, so the player is always charged
// exactly what the prompt shows. Firesale ($10) is checked FIRST so the Armory 10%-off never
// stacks onto a sale (same ordering as the old stock-box hook, _acc_perk_info::acc_box_prompt).
// The Armory discount stays GROUP-based (every player within 100u must hold Armory - mirrors
// the shared wall-hint rule in all_in_range_have_armory; 10000 = 100u squared, the same value
// as _acc_perk_info's file-local ACC_BOX_RANGE_SQ). self = the box struct. self.chest_cost is
// the stable BASE and is never mutated, so no old_cost capture/restore dance is needed.
function acc_box_effective_cost()
{
	if ( treasure_chest_firesale_active() )
		return 10;
	if ( acc_perk_info::all_in_range_have_armory( self.origin, 10000 ) )
		return acc_perk_info::armory_discounted( self.chest_cost );
	return self.chest_cost;
}

// [acc] Display-size compensation (2026-07-12 "RPD looked tiny", REWORKED 2026-07-16). The CW/VG
// guns now display their pre-composed wm_*_full meshes (acc_map_randomizer::box_display_model -
// the old "tiny/wrong/missing parts" reads were mag-less bare RECEIVERS, see that function), and
// the _full meshes are TRUE-sized (re-measured 2026-07-16, xmodel_bin_inspect.js: RPD 36.5u ~
// t6_hamr 36.0u, M60 45.8u, AK-47 38.2u), so the old under-size bumps (RPD/M60 1.25, XM4 1.2) are
// RETIRED. What's left: the Vanguard-scale PPSH mesh runs HOT (49.5u - longer than the M60) and
// shrinks; the XM4 carbine mesh (29.6u) gets a mild bump; the Apex npc_ SMG meshes (12-16u, no
// _full exists for Apex) keep their bumps. Purely cosmetic - the display entity is a throwaway
// tag_origin script_model; the give path never sees the scale. Weapon .name is the bare runtime
// id (the pack _zm suffix is stripped). Widest mesh (Mahem 51.7u) nearly spans the 64u cabinet.
function acc_box_display_scale( weapon )
{
	if ( !isdefined( weapon ) ) return 1.0;
	switch ( weapon.name )
	{
		case "s4_ppsh41_base":  return 0.85;
		case "t9_xm4":          return 1.1;
		case "apex_alternator": return 1.2;
		case "apex_prowler":    return 1.15;
		default:                return 1.0;
	}
}

// [acc] Shelf lift (user 2026-07-16: "Lil Arnies and Ballistic Knife models are too low in the
// box... you have to look inside just to see it"): some meshes are rigged hanging BELOW their
// origin (the knife loot mesh spans z -10.2..+3.3 - measured, wpn_t7_loot_ballistic_knife_world;
// gun meshes straddle z~0), so at the shared display origin they sink under the shelf line. Lift
// the display ent per gun. Octobomb (Li'l Arnie) is a cooked stock asset (no local mesh to
// measure) - same symptom, same first-pass lift; tune from the next live test if it's off.
function acc_box_display_zoff( weapon )
{
	if ( !isdefined( weapon ) ) return 0;
	switch ( weapon.name )
	{
		case "knife_ballistic": return 6;
		case "octobomb":        return 6;
		default:                return 0;
	}
}

// [acc] The ONE display-model writer (both the idle cycle and the buy reveal): complete _full
// mesh where the raw worldModel is a bare receiver, per-gun size, per-gun shelf lift. self = the
// box struct (self.model spawned at self.origin in init_weaponbox and never moved elsewhere, so
// re-basing the origin each call is idempotent; box_knife_watcher's Distance2D is z-blind).
function acc_box_show_display_model( weapon )
{
	self.model SetModel( acc_map_randomizer::box_display_model( weapon ) );
	self.model SetScale( acc_box_display_scale( weapon ) );
	self.model.origin = self.origin + ( 0, 0, acc_box_display_zoff( weapon ) );
}

function cycle_weapons(){ //This function handles cycling through all available weapons to show in the box
	self endon("printer_go_away"); //End when the box moves
	self endon("printer_bought"); //End when the player buys a weapon
	self endon("stop_cycle");

	while(1){
		self.actual_weapon = (treasure_chest_ChooseWeightedRandomWeapon()); //Pick a random weapon from the loaded ones
		if(!isdefined(self.actual_weapon) || !isdefined(self.actual_weapon.worldModel)) continue;
		self acc_box_show_display_model( self.actual_weapon );   // [acc] _full mesh + per-gun size + shelf lift
		wait RandomFloatRange( 0.2, 1 ); //Wait a random amount of time for the player to react
	}
}

function pick_an_usable_weapon(player){
	keys = array::randomize( GetArrayKeys( level.zombie_weapons ) );
	pap_triggers = zm_pap_util::get_triggers();
	for ( i = 0; i < keys.size; i++ ) if ( treasure_chest_CanPlayerReceiveWeapon( player, keys[i], pap_triggers ) ) return keys[i];
}

function treasure_chest_CanPlayerReceiveWeapon( player, weapon, pap_triggers ){
	if ( !zm_weapons::get_is_in_box( weapon ) )	return false;

	if ( IsDefined( player ) && player zm_weapons::has_weapon_or_upgrade( weapon ) ) return false;

	if ( !zm_weapons::limited_weapon_below_quota( weapon, player, pap_triggers )) return false;
	
	if ( !player zm_weapons::player_can_use_content( weapon ) ) return false;
	
	if(isdefined(level.custom_magic_box_selection_logic))
	{
		if(![[level.custom_magic_box_selection_logic]](weapon, player, pap_triggers))
		{
			return false;
		}
	}

	if ( weapon.name == "ray_gun" )	if ( player zm_weapons::has_weapon_or_upgrade( GetWeapon( "raygun_mark2" ) ) )	return false;
	
	if ( weapon.name == "raygun_mark2" ) if ( player zm_weapons::has_weapon_or_upgrade( GetWeapon( "ray_gun" ) ) ) return false;

	// enable special level by level weapon checks
	if( IsDefined( player ) && isdefined( level.special_weapon_magicbox_check ) ) return player [[level.special_weapon_magicbox_check]]( weapon );
	return true;
}

function treasure_chest_ChooseWeightedRandomWeapon(){ //Returns a random weapon from the ones loaded in the level
	keys = array::randomize( GetArrayKeys( level.zombie_weapons ) );
	i = 0;
	max_size = keys.size;
	while(1){
		while( !zm_weapons::get_is_in_box( keys[i] ) && i < max_size) i++;
		wait 0.05;
		if(!zm_weapons::get_is_in_box( keys[i] ) ) continue;
		else break;
	}
	
	return keys[i];
}

function box_bought(player){ //Function that handles what happens once the player interacts with the box
    self zm_unitrigger::unregister_unitrigger(self.unitrigger_stub); //Delete trigger to avoid multiple buys

	// [acc] charge the EFFECTIVE price (firesale $10 / Armory 10%-off) - computed once so the
	// affordability gate, the charge, and the teddy refund all agree on the same number.
	cost = self acc_box_effective_cost();

	if( !player zm_score::can_player_purchase( cost ) ){ // Do nothing if player doesn't have money
		player zm_audio::create_and_play_dialog( "general", "outofmoney", 0 );
        self thread spawn_chest(); //Reset this chest
		return;
	}

	self.state = "open";
	self notify("printer_bought"); //Notify the box that it was accessed
    if(!IS_TRUE( level.zombie_vars["zombie_powerup_fire_sale_on"] ))level.chest_accessed++; // Increase var
	player zm_score::minus_to_player_score( cost ); //Take points from player

	self.grabber = player;
	self.anyone_can_take = false;   // [acc] knife-to-share reset for this pull (user 2026-07-13)

	if( self treasure_chest_should_move() ){ //Check if it should move

		self.animmodel thread animation::play("dlc_weapon_mystery_box_01_malfunction", self.animmodel.origin, self.animmodel.angles); //Play the broken box anim
		self.animmodel waittill("box_malfunction"); //Wait till anim notify
		self.model SetModel("tag_origin"); //The cycling model set to inbisible
		player zm_score::add_to_player_score( cost , false, "magicbox_bear" ); //Refund points
		self thread box_move_away(player); //Move the box
		return;

	}

	// [acc] THE REAL DRAW (replaces the vendor's has_weapon re-pick): route the final pick
	// through our per-run weighting hook (level.CustomRandomWeaponWeights =
	// acc_map_randomizer::acc_box_only_weapon_keys). That one call applies the per-run box
	// pool, tier weighting, Lucky Clover odds, no-duplicate pruning, wonder claim caps, AND
	// stamps player.acc_box_pending_tactical for the fixed-odds Monkey/Arnie rolls (finalized
	// by acc_boss_items::watch_box_tactical_grab on the "user_grabbed_weapon" notify fired in
	// box_get_weapon). The spinning cycle_weapons flicker stays cosmetic - like the stock box,
	// the shown cycle is not the draw. Stock eligibility gates still apply via
	// treasure_chest_CanPlayerReceiveWeapon (in-box / limits / content / raygun exclusivity).
	keys = array::randomize( GetArrayKeys( level.zombie_weapons ) );
	if ( isdefined( level.CustomRandomWeaponWeights ) )
		keys = player [[ level.CustomRandomWeaponWeights ]]( keys );
	picked = undefined;
	pap_triggers = zm_pap_util::get_triggers();
	for ( i = 0; i < keys.size; i++ )
	{
		if ( treasure_chest_CanPlayerReceiveWeapon( player, keys[ i ], pap_triggers ) )
		{
			picked = keys[ i ];
			break;
		}
	}
	if ( !isdefined( picked ) )
		picked = keys[ 0 ];   // stock keys[0] fallback (player owns everything = max-ammo dupe edge)
	self.actual_weapon = picked;
	// [acc] Tier-B box telemetry (docs/41 §3.7): the box landed on this gun = one OFFER the
	// spinner can take or walk away from. Pointer hook (set by acc_weapon_usage::init) - the
	// same no-#using idiom as level.CustomRandomWeaponWeights above; dev/god gating lives in
	// the hook. take_rate = takes/offers is the availability-free preference metric.
	if ( isdefined( level.acc_box_offer_fn ) )
		[[ level.acc_box_offer_fn ]]( picked );
	if ( isdefined( self.actual_weapon.worldModel ) )
		self acc_box_show_display_model( self.actual_weapon );   // [acc] _full mesh + per-gun size + shelf lift

	// [acc] WONDER PULL = GOLD holo (user 2026-07-12): the print/rise of one of the 5 wonder
	// weapons (Thundergun / Blast-O-Matic / Fire Bow / Leviathan Axe / Winter's Howl -
	// wonder_cap_key is the canonical test) renders in the gold dr_fx_holo_gold overlay
	// instead of the cyan one, selling the pull's power. Value 1 (cyan) was set by
	// reset_chest; the reveal below (set 0) clears either color.
	if ( isdefined( acc_map_randomizer::wonder_cap_key( self.actual_weapon ) ) )
		self.model clientfield::set( "exo_magicbox_dr_holo", 2 );

    //If box doesn't move then proceed with giving a weapon
	self.animmodel PlaySound("interact_mystery_box"); //Open box sound
	wait 0.65; //For sound/anim synch.
	self thread open_box_lid();
    //Now spawn a new trigger
	wait 2.08;
	self.model clientfield::set("exo_magicbox_dr_holo", 0); //Make the clone glow
	acc_set_box_gun( self.actual_weapon );   // [acc] push the printed gun's id so the LUI card shows name/desc/tag (2026-07-13)
	// [acc] "for <x>" phrasing = the stock idiom the LUI router classifies as the box-take
	// weapon card (isMysteryBoxWeapon needs "hold"+"for"; getWeaponFromHint renders the text
	// after " for " on the card).
	// CONSTANT string (2026-07-12 triggerstring-cache fix): this used to append
	// self.actual_weapon.displayName, burning one PERMANENT BG-cache 'triggerstring' slot
	// (cap 250, shared match-wide, never freed) per DISTINCT gun printed - ~50 over a long
	// session, which tipped the cap on the box's first day (the in-game "string error"; the
	// overflow blames whoever registers NEXT - that session, the Thundergun PaP tier hint).
	// Stock's own box take-hint carries no gun name either; the printed gun is visible in
	// the cabinet + gold holo. See CHANGELOG 2026-07-12 + memory aw-3d-printer-box-swap.
	self thread set_up_unitrigger(64, 64, 64, false, "Hold ^3[{+activate}]^7 for Printed Weapon" , &box_get_weapon, &trigger_update_prompt_get_weapon);
	//Start counting down, removes the weapon if the player doesnt acquire it
    self thread wpn_box_timeout();
	self thread box_knife_watcher();   // [acc] any NON-buyer can knife the float to share it (user 2026-07-13)
}

// [acc] MYSTERY-BOX GUN CARD (user 2026-07-13): push the printed gun's STABLE weapon-usage id
// (acc_gun_id, 0..31; 0 = none/unknown) to the "acc_box_gun" toplayer clientfield so
// PromptMysteryBox.lua renders the gun's NAME + short desc + ENERGY/EXPLOSIVE tag on the take card -
// WITHOUT a per-gun hint string (per-gun SetHintStrings burn PERMANENT BG-cache triggerstring slots,
// cap 250 - the leak removed 2026-07-12; the hint stays the CONSTANT "Printed Weapon"). Field
// registered + bridged to the same-named UI model in _zm_aetherium_hud.gsc/.csc. self = the box struct.
//
// PER-PLAYER TARGETING (user 2026-07-14, box-card UI bug): the card must reach ONLY the player the
// offer belongs to - the buyer (self.grabber) - or EVERYONE once the float is knifed to share
// (self.anyone_can_take). The old code pushed the same id to ALL players, so a NON-buyer standing at
// the box read the BUYER's gun on their own card (the reported bug). Everyone not eligible is forced
// to 0 (the generic "Printed Weapon" card) so a stale value can never linger on the wrong client.
// Clearing the card (weapon undefined -> id 0) always broadcasts 0 to all. Set on reveal (buyer only);
// re-pushed to all on knife-to-share; cleared on take/timeout.
function acc_set_box_gun( weapon )
{
    id = 0;
    if ( isdefined( weapon ) && isdefined( weapon.name ) )
        id = acc_weapon_usage::acc_gun_id( weapon.name );

    b_share  = ( id == 0 ) || IS_TRUE( self.anyone_can_take );   // clear or shared float -> everyone
    e_grabber = self.grabber;
    foreach ( p in GetPlayers() )
    {
        // TOPLAYER scope needs set_to_player (NOT ::set = world/entity) or it never reaches the client
        // (matches acc_objective/acc_implants/acc_badges).
        if ( b_share || ( isdefined( e_grabber ) && p == e_grabber ) )
            p clientfield::set_to_player( "acc_box_gun", id );
        else
            p clientfield::set_to_player( "acc_box_gun", 0 );
    }
}

// [acc] KNIFE-TO-SHARE (user 2026-07-13, "make the box knifeable like recent CoD"): the BUYER of this
// spin can melee the floating printed gun to turn it GREEN and let ANY teammate grab it (the flow:
// you spin, don't want the gun, so you knife it to donate it to a teammate). ONLY the buyer can trigger
// this - a teammate meleeing it does nothing. self = the box struct (self.model = floating gun,
// self.grabber = buyer). Short window (the float) + buyer-only + must be at the box, so the
// MeleeButtonPressed false-positive (buyer swinging at a zombie by the box) is low-harm - it just shares
// the gun the buyer is walking away from anyway.
function box_knife_watcher()
{
	self endon( "printer_go_away" );
	self.model endon( "weapon_obtained" );
	self.model endon( "weapon_timeout" );
	level endon( "end_game" );

	for ( ;; )
	{
		wait 0.05;
		if ( IS_TRUE( self.anyone_can_take ) ) return;
		if ( !isdefined( self.model ) || !isdefined( self.grabber ) ) return;
		buyer = self.grabber;
		if ( !zm_utility::is_player_valid( buyer ) ) continue;
		if ( !( buyer MeleeButtonPressed() ) ) continue;
		if ( Distance2D( buyer.origin, self.model.origin ) > 84 ) continue;   // buyer must be at the box
		self box_unlock_for_all();
		return;
	}
}

// [acc] flip the float to "anyone can take" + GREEN holo (clientfield value 3, handled in the .csc). self = box.
function box_unlock_for_all()
{
	if ( IS_TRUE( self.anyone_can_take ) ) return;
	self.anyone_can_take = true;
	if ( isdefined( self.model ) )
		self.model clientfield::set( "exo_magicbox_dr_holo", 3 );   // 3 = GREEN = shared
	if ( isdefined( self.animmodel ) )
		self.animmodel PlaySound( "interact_mystery_box" );          // audible "unlocked" cue
	// [acc] now shared - re-push the gun card to EVERYONE (was buyer-only while locked, user 2026-07-14)
	acc_set_box_gun( self.actual_weapon );
}

function open_box_lid(){
	self.animmodel animation::play("dlc_weapon_mystery_box_01_open", self.animmodel.origin, self.animmodel.angles); //Play open box anim
	WAIT_SERVER_FRAME;
	self.animmodel thread animation::play("dlc_weapon_mystery_box_01_open_idle", self.animmodel.origin, self.animmodel.angles); //Lock the box in it's open state
}

function box_get_weapon(player){//Function that handles what happens once the player gets the weapon
    self zm_unitrigger::unregister_unitrigger(self.unitrigger_stub); //Delete trigger to avoid multiple buys
	acc_set_box_gun( undefined );   // [acc] offer taken - clear the box gun card (2026-07-13)
	self.model SetModel("tag_origin");
    self.model notify("weapon_obtained");
	WAIT_SERVER_FRAME;
	WAIT_SERVER_FRAME;
	// [acc] the load-bearing stock notify (stock _zm_magicbox.gsc:809 fires it BEFORE the
	// switch; weapon_give's 3rd arg does the transitional SwitchToWeapon). This ONE line
	// drives all five box listeners: variant/Mega reconcile defer
	// (_acc_weapon_variants::box_grab_defer_watcher - notify is synchronous, so it sets
	// player.acc_box_grabbing and captures the pre-grab gun before the give below runs),
	// PaP tier reset (_acc_pap_levels), box-rolled tactical finalizer (_acc_boss_items),
	// gun-badge mule freeze, and the weapon-usage sampler pause. Do NOT set/clear
	// acc_box_grabbing here - box_grab_defer_watcher owns that flag's lifecycle.
	// [acc] 2026-07-12 mule-kick double-swap fix: the notify CARRIES the granted weapon object.
	// Listeners that must identify the box gun (variant defer settle, PaP tier reset) use the arg
	// instead of inferring it from GetCurrentWeapon() churn - at 3/3 guns (Mule Kick) the at-limit
	// give's take + engine auto-switch parks the view on ANOTHER owned gun long enough to fake a
	// "settled" read, which un-deferred the twin reconcile mid-raise = the visible second draw.
	// (Stock fires this notify bare from _zm_magicbox:809; extra notify args are ignored by
	// listeners that don't bind them, so this stays stock-shape compatible.)
	player notify( "user_grabbed_weapon", self.actual_weapon );
	// [acc] Tier-B box telemetry (docs/41 §3.7): the offered gun was grabbed = one TAKE
	// (the timeout/walk-away path never reaches here, leaving the offer untaken).
	if ( isdefined( level.acc_box_take_fn ) )
		[[ level.acc_box_take_fn ]]( self.actual_weapon );
	// [acc] TACTICAL rolls (Monkey Bomb / Li'l Arnie) NEVER go through the stock give (2026-07-17):
	// octobomb is not in level.zombie_tactical_grenade_list (stock zm_usermap registers only
	// cymbal_monkey), so zm_weapons::weapon_give ran its PRIMARY flow on it - at the 2-gun limit that
	// weapon_take()'d the HELD GUN (the "box tactical traded my gun" bug, user 2026-07-17). The
	// watch_box_tactical_grab finalizer (_acc_boss_items) already performs the COMPLETE tactical grant
	// (active slot + ammo 4 + thrown-grenade callback) off the notify above - for the buyer via their
	// pending flag, for a knife-to-share grabber via the weapon object on the notify arg - so the stock
	// give is redundant AND harmful here; skip it. Clear the BUYER's pending flag too: on a shared grab
	// the grabber's finalizer consumed the grant, and a flag left on the buyer would falsely grant the
	// tactical on their NEXT box grab.
	if ( acc_map_randomizer::is_box_tactical( self.actual_weapon ) )
	{
		if ( isdefined( self.grabber ) )
			self.grabber.acc_box_pending_tactical = undefined;
	}
	else
	{
		player zm_weapons::weapon_give(self.actual_weapon, false, true);
	}
	self.animmodel animation::stop();
	WAIT_SERVER_FRAME;
	self.animmodel animation::play("dlc_weapon_mystery_box_01_close"); //Close the box
	wait 0.005;
	if(!IS_TRUE(self.waiting_to_spawn) )
		self thread spawn_chest(); //Reset this location to its original state
	self.state = "close";
}

function box_move_away(player_vox){ //This function handles moving the box to a new location
	level.chest_moves++;
	level.chest_accessed = 0;
	self.state = "leaving";

	level thread zm_audio::sndAnnouncerPlayVox("boxmove"); // Make the announcer talk
	wait 1;
	player_vox util::delay( randomintrange(5,7), undefined, &zm_audio::create_and_play_dialog, "general", "box_move"  ); //Make the character respond to the box moving
	self thread reset_chest(); //Reset this box to it's original state 
	self thread set_up_unitrigger(64, 64, 64, false, HINT_AWAY_PRINTER, undefined, &trigger_update_prompt_default);
	wait 10; //After 1 second disable the location
	self.state = "close";
	level.chest_index = get_next_chest_index(); //Choose a new box location

	if(!IS_TRUE(self.waiting_to_spawn))
		level.available_chests[level.chest_index] thread spawn_chest(); //Spawn the box at the new location
}

function get_next_chest_index(){ //This function gets an index for the new box location, keeps rolling until it's different from the current one
	do{
		newI = RandomInt(level.available_chests.size);
        wait 0.05;
	}while(newI == level.chest_index);
	return newI;
}

function wpn_box_timeout(){ //Start counting down, removes the weapon if the player doesnt acquire it
	self.model endon("weapon_obtained"); //Stop immediatly if the player gets the weapon

	wait 8;
	self.model thread weapon_model_blink(); //After 8 seconds start blinking!
	wait 4;
	self.model notify("weapon_timeout"); //Let the weapon model know the weapon has timeout-ed. (This is used to stop the blinking of the model)
	acc_set_box_gun( undefined );   // [acc] offer expired - clear the box gun card (2026-07-13)
	// [acc] walked away from a floated TACTICAL (2026-07-17): drop the buyer's pending flag so it
	// can't linger and falsely grant the tactical on a LATER grab (e.g. taking a teammate's shared
	// float) - the per-spin clear in acc_box_only_weapon_keys only runs when THIS player spins again.
	if ( isdefined( self.grabber ) )
		self.grabber.acc_box_pending_tactical = undefined;
	self zm_unitrigger::unregister_unitrigger(self.unitrigger_stub); //Delete trigger to avoid multiple buys
	self.animmodel animation::stop();
	WAIT_SERVER_FRAME;
	self.animmodel animation::play("dlc_weapon_mystery_box_01_close"); //Close the box
	WAIT_SERVER_FRAME;
	self.state = "close";
	if(!IS_TRUE(self.waiting_to_spawn))
		self thread spawn_chest(); // Reset current box to it's normal behaviour
}

//Make the weapon model blink when time is running out
function weapon_model_blink(){
    self endon("weapon_timeout"); //Stop when the weapon hasn't been picked up
    self endon("weapon_obtained"); //Stop when the weapon has been picked up

	while(1){
		self Ghost(); //Send network info but dont render.
		wait 0.5;
		self Show();
		wait 0.5;
	}

}

function box_encounter_vo(){ //This function handles the initial encounter vox
	level flag::wait_till( "initial_blackscreen_passed" );
	
	while (1){
		foreach (player in getPlayers()){
			distanceFromPlayerToBox = distance(player.origin, self.origin);
			
			if (distanceFromPlayerToBox < 300){
				player zm_audio::create_and_play_dialog( "box", "encounter" );
				return;				
			}			
		}
		wait 0.5;
	}
}

function treasure_chest_should_move(){ //This function handles choosing if the box needs to move
	// Increase the chance of joker appearing from 0-100 based on amount of the time chest has been opened.
	if( ( GetDvarString( "magic_chest_movable") == "1") && !treasure_chest_firesale_active() ){
		// random change of getting the joker that moves the box
		random = Randomint(100);

		if( !isdefined( level.chest_min_move_usage ) ) level.chest_min_move_usage = 4;
		if( level.chest_accessed < level.chest_min_move_usage )	chance_of_joker = -1;
		else{
			chance_of_joker = level.chest_accessed + 20;

			// make sure teddy bear appears on the 8th pull if it hasn't moved from the initial spot
			if ( level.chest_moves == 0 && level.chest_accessed >= 8 )chance_of_joker = 100;

			// pulls 4 thru 8, there is a 15% chance of getting the teddy bear
			// NOTE:  this happens in all cases
			if( level.chest_accessed >= 4 && level.chest_accessed < 8 ){
				if( random < 15 ) chance_of_joker = 100;
				else chance_of_joker = -1;
			}

			// after the first magic box move the teddy bear percentages changes
			if ( level.chest_moves > 0 ){
				// between pulls 8 thru 12, the teddy bear percent is 30%
				if( level.chest_accessed >= 8 && level.chest_accessed < 13 )
				{
					if( random < 30 ) chance_of_joker = 100;
					else chance_of_joker = -1;
				}	
				// after 12th pull, the teddy bear percent is 50%
				if( level.chest_accessed >= 13 ){
					if( random < 50 ) chance_of_joker = 100;
					else chance_of_joker = -1;
				}
			}
		}

		if(IsDefined(self.is_static)) chance_of_joker = -1;

		if ( chance_of_joker > random ) return true; 
	}
	return false; 	
}

function treasure_chest_firesale_active(){ //Self explanatory
	return IS_TRUE( level.zombie_vars["zombie_powerup_fire_sale_on"] ); 
}

////
// UNITRIGGER FUNCS
////

function trigger_update_prompt_get_weapon( player ){// Handles standard visibility for unitriggers
	self endon( "kill_trigger" );
	
	if ( isdefined( self ) ){
		can_use = stub_update_prompt( player );
		if(isdefined(self.stub.trigger_target.grabber) && self.stub.trigger_target.grabber != player && !IS_TRUE(self.stub.trigger_target.anyone_can_take)) can_use = false;   // [acc] anyone_can_take = knifed-to-share (user 2026-07-13)
		self setInvisibleToPlayer( player, !can_use );
		self SetHintString( self.stub.hint_string );
		return can_use;
	}
	self SetHintString("");
	return false;
}

function trigger_update_prompt_default( player ){// Handles standard visibility for unitriggers
	self endon( "kill_trigger" );

	if ( isdefined( self ) ){
		can_use = stub_update_prompt( player );
		self setInvisibleToPlayer( player, !can_use );
		// [acc] the buy-armed state (triggered_func defined = &box_bought) re-renders its
		// price EVERY frame so the firesale $10 / Armory 10%-off show live (the vendor baked
		// the hint once at set_up_unitrigger). The AWAY/malfunction state has no
		// triggered_func and keeps its static string. Wording must keep "Mystery Box" (LUI
		// router cue) and avoid " for " (wallbuy matcher) - see spawn_chest.
		if ( isdefined( self.stub.triggered_func ) && isdefined( self.stub.trigger_target ) )
		{
			c = self.stub.trigger_target acc_box_effective_cost();
			self SetHintString( "Hold ^3[{+activate}]^7 to print from the Mystery Box [ Cost: " + c + " ]" );
		}
		else
		{
			self SetHintString( self.stub.hint_string );
		}
		return can_use;
	}
	self SetHintString("");
	return false;
}

//Sets up a new unitrigger, self == struct/ent
function set_up_unitrigger(width = 64, lenght = 64, height = 64, LOOKAT = false, HINTSTRING, TRIGGERED_FUNC, UPDATE_PROMPT ){
	self.unitrigger_stub = SpawnStruct();
	self.unitrigger_stub.origin = self.origin;
	self.unitrigger_stub.angles = self.angles;
	self.unitrigger_stub.script_unitrigger_type = "unitrigger_box_use";
	self.unitrigger_stub.script_width = width;
	self.unitrigger_stub.script_height = height;
	self.unitrigger_stub.script_length = lenght;
	self.unitrigger_stub.require_look_toward = LOOKAT;
	self.unitrigger_stub.cursor_hint = "HINT_NOICON";
	self.unitrigger_stub.hint_string = HINTSTRING;
	self.unitrigger_stub.trigger_target = self;
	self.unitrigger_stub.triggered_func = TRIGGERED_FUNC;
	self.unitrigger_stub.prompt_and_visibility_func = UPDATE_PROMPT;
	self zm_unitrigger::register_static_unitrigger( self.unitrigger_stub, &check_valid );
}

function check_valid(){
	self endon( "kill_trigger" );

	while( 1 ){
		self waittill( "trigger", player );
		if ( !zm_utility::is_player_valid( player ) )
			continue;
		if ( isdefined( self.stub.triggered_func ) )
			self.stub.trigger_target thread [[ self.stub.triggered_func ]]( player );
	}
}

function stub_update_prompt( player ){	
	if( !zm_utility::is_player_valid( player ) )
		return false;
	if( player zm_utility::in_revive_trigger() )
		return false;
	if( IS_DRINKING(player.is_drinking) )
		return false;
	return true;
}