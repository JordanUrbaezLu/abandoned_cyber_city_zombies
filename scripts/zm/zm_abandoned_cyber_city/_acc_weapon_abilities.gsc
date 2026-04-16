// =============================================================================
// _acc_weapon_abilities.gsc - per-category active weapon abilities
//
// Design reference: docs/05_weapons.md (Weapon Abilities - intrinsic).
//
// Every weapon CATEGORY has one signature active ability, triggered by a
// hotkey with a cooldown. The ability is intrinsic to the weapon (no unlock,
// no cost) and available from round 1.
//
// Status: STUB. Ability table + cooldown scaffold is in place; effect
// implementations are stubbed with TODO markers for Phase 4 authoring.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_overclocks;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

init()
{
    _acc_utility::log( "weapon_abilities init" );

    level.acc_abilities = build_ability_table();

    level thread watch_ability_keypress();
}

on_player_connect( player )
{
    // Per-player cooldown map: ability_id -> gametime ready (ms).
    player.acc_ability_ready_at = [];
}

// ---------------------------------------------------------------------------
// Ability table - source of truth for cooldowns and effects.
// Keep in sync with docs/05_weapons.md "Weapon Abilities" table.
// ---------------------------------------------------------------------------

build_ability_table()
{
    t = [];

    t[ "pistol" ]         = ability( "triple_tap",      15, &effect_triple_tap );
    t[ "ar_full" ]        = ability( "stabilizer",      25, &effect_stabilizer );
    t[ "ar_semi" ]        = ability( "precision_mode",  30, &effect_precision_mode );
    t[ "shotgun" ]        = ability( "slug_round",      20, &effect_slug_round );
    t[ "sniper" ]         = ability( "thermal_vision",  30, &effect_thermal_vision );
    t[ "melee" ]          = ability( "whirlwind",       20, &effect_whirlwind );
    t[ "grenade_lethal" ] = ability( "extended_fuse",   15, &effect_extended_fuse );
    t[ "grenade_tac" ]    = ability( "overcharge",      20, &effect_overcharge );

    return t;
}

ability( id, cooldown_sec, on_activate )
{
    a = spawnstruct();
    a.id = id;
    a.cooldown_sec = cooldown_sec;
    a.on_activate = on_activate;
    return a;
}

// ---------------------------------------------------------------------------
// Category lookup (weapon category != overclock family; semi-auto ARs are
// a SEPARATE category here because their ability differs, even though they
// share the AR Overclock pool).
// ---------------------------------------------------------------------------

weapon_name_to_ability_category( weapon_name )
{
    // TODO(acc-data): consolidate category tables into a GDT-driven dict.
    ar_full_list  = array( "icr1_zm", "xr2_zm", "ak47_zm" );
    ar_semi_list  = array( "m14ebr_zm", "g3_zm", "fnfal_zm" );
    pistol_list   = array( "b23r_zm" );
    shotgun_list  = array( "haymaker12_zm", "brecci_zm", "tac19_zm" );
    sniper_list   = array( "drakon_zm", "locus_zm", "intervention_zm" );
    melee_list    = array( "bowie_knife_zm", "cyber_cleaver_zm" );
    grenade_lethal_list = array( "frag_grenade_zm" );
    grenade_tac_list    = array( "emp_grenade_zm" );

    if ( array::contains( pistol_list, weapon_name ) ) return "pistol";
    if ( array::contains( ar_full_list, weapon_name ) ) return "ar_full";
    if ( array::contains( ar_semi_list, weapon_name ) ) return "ar_semi";
    if ( array::contains( shotgun_list, weapon_name ) ) return "shotgun";
    if ( array::contains( sniper_list, weapon_name ) ) return "sniper";
    if ( array::contains( melee_list, weapon_name ) ) return "melee";
    if ( array::contains( grenade_lethal_list, weapon_name ) ) return "grenade_lethal";
    if ( array::contains( grenade_tac_list, weapon_name ) ) return "grenade_tac";
    return "none";
}

// ---------------------------------------------------------------------------
// Input handling
//
// TODO(acc-input): BO3 doesn't expose arbitrary keybinds cleanly. Common
// community approaches:
//   (a) Use a stock unused button (e.g. melee + ADS combo) as ability key.
//   (b) Hijack the stock "use" button with a context check.
//   (c) Register a dvar the player can bind via console.
// For the scaffold, we listen for an "acc_ability" notify that we assume
// comes from a console `bind X notify acc_ability` binding.
// ---------------------------------------------------------------------------

watch_ability_keypress()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "connected", player );
        player thread player_ability_listener();
    }
}

player_ability_listener()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "acc_ability" );
        try_activate_ability( self );
    }
}

try_activate_ability( player )
{
    weapon = player getcurrentweapon();
    category = weapon_name_to_ability_category( weapon );
    if ( category == "none" )
    {
        player iprintln( "No ability on this weapon" );
        return;
    }

    ability = level.acc_abilities[ category ];
    if ( !isdefined( ability ) )
    {
        player iprintln( "No ability defined for category " + category );
        return;
    }

    now = gettime();
    ready_at = 0;
    if ( isdefined( player.acc_ability_ready_at[ ability.id ] ) )
    {
        ready_at = player.acc_ability_ready_at[ ability.id ];
    }

    if ( now < ready_at )
    {
        seconds_left = ( ready_at - now ) / 1000;
        player iprintln( ability.id + " on cooldown (" + int( seconds_left ) + "s)" );
        return;
    }

    // Start cooldown immediately so rapid presses can't double-activate.
    player.acc_ability_ready_at[ ability.id ] = now + ( ability.cooldown_sec * 1000 );

    player [[ ability.on_activate ]]();
    player iprintln( "Activated: " + ability.id );
}

// ---------------------------------------------------------------------------
// Effect implementations - STUBS
//
// Each runs on `self` = the player activating. Phase 4 work fleshes these
// out. For now they log and mark a flag other systems can read.
// ---------------------------------------------------------------------------

effect_triple_tap()
{
    // Next shot from B23R fires all 3 burst rounds as a tight cluster.
    // TODO(acc-weapon): patch B23R firing to check self.acc_ability_triple_tap_primed.
    self.acc_ability_triple_tap_primed = true;
    _acc_utility::log( "ability: triple_tap primed" );
}

effect_stabilizer()
{
    // 5s zero recoil + 20% fire rate.
    // TODO(acc-weapon): set recoil multiplier via weapon-override GDT flag.
    self.acc_ability_stabilizer_until = gettime() + 5000;
    _acc_utility::log( "ability: stabilizer 5s" );
}

effect_precision_mode()
{
    // Next 3 shots auto-crit (4x).
    self.acc_ability_precision_shots_remaining = 3;
    _acc_utility::log( "ability: precision_mode, 3 shots" );
}

effect_slug_round()
{
    // Next shotgun shot is a slug (tight cone, 3x single-target, 2x range).
    self.acc_ability_slug_primed = true;
    _acc_utility::log( "ability: slug_round primed" );
}

effect_thermal_vision()
{
    // 3s see-through-walls on enemies in view cone.
    // TODO(acc-ui): needs LUI overlay + client-side rendering.
    self.acc_ability_thermal_until = gettime() + 3000;
    _acc_utility::log( "ability: thermal_vision 3s" );
}

effect_whirlwind()
{
    // 360 spin hits all enemies within 96 units; insta-kill chaff early.
    // TODO(acc-combat): perform the AoE immediately; apply damage to all
    // zombies in radius; play spin animation.
    _acc_utility::log( "ability: whirlwind (unimplemented)" );
}

effect_extended_fuse()
{
    // Next frag throw auto-airbursts at optimal height.
    self.acc_ability_extended_fuse_primed = true;
    _acc_utility::log( "ability: extended_fuse primed" );
}

effect_overcharge()
{
    // Next EMP grenade stun is 2x duration.
    self.acc_ability_overcharge_primed = true;
    _acc_utility::log( "ability: overcharge primed" );
}
