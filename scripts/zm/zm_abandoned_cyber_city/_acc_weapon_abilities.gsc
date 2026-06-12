// =============================================================================
// _acc_weapon_abilities.gsc - per-category active weapon abilities
//
// Design reference: docs/05_weapons.md (Weapon Abilities - intrinsic).
//
// Every weapon CATEGORY has one signature active ability, triggered by a
// hotkey with a cooldown. The ability is intrinsic to the weapon (no unlock,
// no cost) and available from round 1.
//
// Status: PARTIAL.
//  - Live: ability table, ADS+melee chord listener, per-player cooldowns,
//    and three effects:
//      * Precision Mode (ar_semi) - arms player.acc_ability_crit_shots = 3;
//        _acc_damage::on_ai_damage consumes it (auto-crit 4x per hit,
//        decrements). The damage math lives in _acc_damage, NOT here.
//      * Slug Round (shotgun) - arms player.acc_ability_slug_next = true;
//        _acc_damage consumes it (3x once, then clears). The 2x-range /
//        tight-cone half needs a weapon-override GDT and stays Phase 4.
//      * Whirlwind (melee) - self-contained 96-unit AoE, implemented below.
//  - Phase 4 stubs (honest no-ops; cooldown still consumed so the input
//    loop is testable end-to-end): Triple Tap, Stabilizer, Thermal Vision,
//    Extended Fuse, Overcharge. Each needs a weapon-fire hook, a
//    weapon-override GDT, or LUI/clientfield work that does not exist yet -
//    see the per-function comments.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_overclocks;

#define ACC_WHIRLWIND_RADIUS_SQ    9216  // 96u * 96u (docs/05_weapons.md)
#define ACC_WHIRLWIND_ELITE_DAMAGE 1000  // flat - elites are not chaff
#define ACC_PRECISION_CRIT_SHOTS   3

#namespace acc_weapon_abilities;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "weapon_abilities init" );

    level.acc_abilities = build_ability_table();

    level thread watch_ability_keypress();
}

function on_player_connect( player )
{
    // Per-player cooldown map: ability_id -> gametime ready (ms).
    player.acc_ability_ready_at = [];

    // Effect state consumed by _acc_damage::on_ai_damage (see the CONTRACT
    // comments on effect_precision_mode / effect_slug_round). Initialized
    // here so the damage module can read them without isdefined guards.
    player.acc_ability_crit_shots = 0;
    player.acc_ability_slug_next = false;
}

// ---------------------------------------------------------------------------
// Ability table - source of truth for cooldowns and effects.
// Keep in sync with docs/05_weapons.md "Weapon Abilities" table.
// ---------------------------------------------------------------------------

function build_ability_table()
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

function ability( id, cooldown_sec, on_activate )
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
//
// Stock BO3 weapon names are CLASS-based and unsuffixed - the old
// "<marketing>_zm" strings (BO1/BO2 convention) can NEVER match a runtime
// weapon name and have been replaced.
// VERIFIED(acc): "pistol_standard" = MR6, the starting/laststand pistol
//   (zm_usermap.gsc:331, _zm.gsc:1152).
// VERIFIED(acc): in-map roster names "ar_accurate" (ICR-1 - "ar_standard"
//   is the KN-44!), "shotgun_fullauto" (Haymaker 12), "sniper_fastsemi"
//   (Drakon), "ar_marksman" (Sheiva), "bowie_knife", "frag_grenade" -
//   docs/19_stock_api_verification.md "BO3 weapon names" row; the
//   map_source wallbuy structs use exactly these strings.
// Box-roster stock names "shotgun_semiauto" (Brecci), "ar_longburst"
//   (XR-2), "sniper_fastbolt" (Locus) come from the same ledger row -
//   TODO(acc-verify): mapped from GDT naming, confirm on first compile.
//
// Future Skye imports are engine-prefixed (iw4_=MW2, t5_=BO1, t6_=BO2,
// s1_=AW, h1_=MWR - docs/21_weapon_import_sources.md). Each commented line
// below activates when its GDT lands on the Windows box.
// ---------------------------------------------------------------------------

function weapon_name_to_ability_category( weapon_name )
{
    // TODO(acc-data): consolidate category tables into a GDT-driven dict
    // shared with _acc_overclocks::weapon_name_to_family.

    pistol_list   = array( "pistol_standard" );
    // TODO(acc-import): + "t6_b23r" (B23R starter, Skye BO2 pack)

    ar_full_list  = array( "ar_accurate", "ar_longburst" );
    // TODO(acc-import): + "iw4_ak47" (AK-47; t5_/t6_/s1_/h1_ era alternates)

    ar_semi_list  = array( "ar_marksman" );
    // TODO(acc-import): + "iw4_m14ebr" (M14 EBR), "h1_g3" (G3),
    // "t5_fal" (FN FAL)

    shotgun_list  = array( "shotgun_fullauto", "shotgun_semiauto" );
    // TODO(acc-import): + "s1_tac19" (Tac-19, Skye AW pack)

    sniper_list   = array( "sniper_fastsemi", "sniper_fastbolt" );
    // TODO(acc-import): + "iw4_intervention" (Intervention)

    melee_list    = array( "bowie_knife" );
    // (Cyber Cleaver is a Phase 5 art reskin of the SAME bowie GDT - no
    // separate weapon name exists; docs/05_weapons.md.)

    grenade_lethal_list = array( "frag_grenade" );

    grenade_tac_list = [];
    // TODO(acc-import): + "emp_grenade_zm" (custom-authored Phase 4 GDT -
    // we own the name, so the _zm suffix is OUR choice, not a stock claim;
    // see _acc_weapon_emp_grenade.gsc plan in docs/05_weapons.md).

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
// We use (a): an ADS+melee chord, replaced by a real LUI keybind in Phase 4.
// ---------------------------------------------------------------------------

function watch_ability_keypress()
{
    level endon( "end_game" );

    for ( ;; )
    {
        // VERIFIED(acc): level notify( "connected", player ) fires per
        // connecting player (gametypes/_globallogic_player.gsc:63).
        level waittill( "connected", player );
        player thread player_ability_listener();
    }
}

function player_ability_listener()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        // VERIFIED(acc): BO3 has no console command that fires a script
        // notify on the player, so a waittill("acc_ability") can never fire.
        // Poll an ADS+melee chord instead (stock button builtins:
        // AdsButtonPressed _zm.gsc:4976, MeleeButtonPressed
        // shared/bots/_bot.gsc:601).
        // TODO(acc-input): replace with a real LUI keybind in Phase 4.
        while ( !( self AdsButtonPressed() && self MeleeButtonPressed() ) )
        {
            wait 0.05;
        }
        try_activate_ability( self );
        wait 0.5; // debounce so one chord press activates once
    }
}

function try_activate_ability( player )
{
    weapon = player getcurrentweapon();
    // VERIFIED(acc): GetCurrentWeapon returns a weapon OBJECT; the string
    // lives in .name (_zm.gsc:5288). Passing the object to a string compare
    // can never match.
    if ( !isdefined( weapon ) || weapon == level.weaponNone )
    {
        return;
    }

    // VERIFIED(acc): PaP'd weapons KEEP the _upgraded suffix in
    // rootWeapon.name; the base<->upgrade mapping is table-driven via
    // zm_weapons::get_base_weapon (_zm_weapons.gsc:1624), which falls
    // through to the weapon itself when not upgraded. Resolving the base
    // here keeps abilities working after PaP (docs/05: abilities are
    // intrinsic and ignore the upgrade tracks).
    w_base = zm_weapons::get_base_weapon( weapon );
    category = weapon_name_to_ability_category( w_base.name );
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
    // Timestamps (not tickers) mean the cooldown runs while holstered too
    // (docs/05: cooldowns tick down equipped AND holstered).
    player.acc_ability_ready_at[ ability.id ] = now + ( ability.cooldown_sec * 1000 );

    player iprintln( "Activated: " + ability.id );
    player [[ ability.on_activate ]]();
}

// ---------------------------------------------------------------------------
// Effect implementations
//
// Each runs on `self` = the player activating.
//
// Two contracts with _acc_damage::on_ai_damage (the ONLY damage-math owner):
//   self.acc_ability_crit_shots  (int)  - each hit auto-crits at 4x and
//                                         decrements; this module only arms.
//   self.acc_ability_slug_next   (bool) - next shot 3x once, then cleared.
// ---------------------------------------------------------------------------

function effect_triple_tap()
{
    // docs/05: next B23R shot fires the 3-round burst as one tight cluster.
    // NOT implementable yet: collapsing burst ballistics needs a weapon-fire
    // intercept / weapon-override GDT swap - GSC alone cannot reshape a
    // burst's projectile pattern. Cooldown is still consumed by design so
    // the chord -> cooldown loop stays honest and testable.
    self iprintln( "Triple Tap - effect lands in Phase 4" );
    acc_utility::log( "ability: triple_tap stub (needs weapon-fire hook / override GDT)" );
}

function effect_stabilizer()
{
    // docs/05: 5s zero recoil + 20% fire rate.
    // NOT implementable yet: recoil tables and fire time are GDT properties;
    // GSC has no per-player recoil or fire-rate setter on a live weapon. The
    // Phase 4 plan is an override-GDT variant swapped in for the duration.
    self iprintln( "Stabilizer - effect lands in Phase 4" );
    acc_utility::log( "ability: stabilizer stub (needs weapon-override GDT)" );
}

function effect_precision_mode()
{
    // docs/05: next 3 shots auto-crit (4x damage, ignore hit-loc).
    // CONTRACT: _acc_damage::on_ai_damage consumes acc_ability_crit_shots -
    // it treats each hit as an auto-crit at 4x and decrements the counter.
    // The damage math lives in _acc_damage; this module only arms the state.
    self.acc_ability_crit_shots = ACC_PRECISION_CRIT_SHOTS;
    acc_utility::log( "ability: precision_mode armed (" + ACC_PRECISION_CRIT_SHOTS + " crit shots)" );
}

function effect_slug_round()
{
    // docs/05: next shotgun shot is a slug - 2x range, 3x single-target
    // damage, tight cone.
    // CONTRACT: _acc_damage::on_ai_damage consumes acc_ability_slug_next
    // (applies 3x once, then clears the flag). The 2x-range / tight-cone
    // half needs a weapon-override GDT at fire time - Phase 4, same
    // mechanism as Stabilizer above.
    self.acc_ability_slug_next = true;
    acc_utility::log( "ability: slug_round armed (3x next shot)" );
}

function effect_thermal_vision()
{
    // docs/05: 3s see-through-walls on enemies in view cone.
    // NOT implementable yet: per-player enemy outlines need a
    // clientfield-driven visionset/LUI overlay rendered in the client VM -
    // and .csc cannot be driven from here until the Phase 4 client modules
    // exist (CLAUDE.md: .csc cannot call .gsc; separate VMs).
    self iprintln( "Thermal Vision - effect lands in Phase 4" );
    acc_utility::log( "ability: thermal_vision stub (needs LUI/clientfield)" );
}

function effect_whirlwind()
{
    // docs/05: 360 spin hits all enemies within 96 units; insta-kill chaff.
    // Self-contained - no shot fires, so this does NOT use the primed-flag
    // contract. DoDamage routes through the stock actor damage pipeline, so
    // _acc_damage::on_ai_damage still records the hit for the 70/30 point
    // split and stock kill credit pays points via zm_score - this module
    // never writes player.score.
    //
    // VERIFIED(acc): GetAITeamArray( level.zombie_team ) is the stock
    // enumerate-live-zombies call (_zm_blockers.gsc:620);
    // level.zombie_team = "axis" (gametypes/_globallogic.gsc:115).
    // VERIFIED(acc): zombie DoDamage( zombie.health + 666, origin, attacker )
    // is the stock guaranteed-kill idiom (_zm_blockers.gsc:636,
    // kill_trapped_zombies).
    // VERIFIED(acc): flat-damage AoE on zombies with attacker/inflictor =
    // player and "none" hitloc is the electric cherry reload-shock pattern
    // (_zm_perk_electric_cherry.gsc:484).

    zombies = GetAITeamArray( level.zombie_team );
    hits = 0;

    foreach ( zombie in zombies )
    {
        if ( !isdefined( zombie ) || !IsAlive( zombie ) )
        {
            continue;
        }
        if ( DistanceSquared( zombie.origin, self.origin ) > ACC_WHIRLWIND_RADIUS_SQ )
        {
            continue;
        }

        // Bosses (full + mini) are excluded entirely - their HP pools and
        // phase logic are owned by _acc_boss.
        if ( IS_TRUE( zombie.acc_is_boss ) || IS_TRUE( zombie.acc_is_mini_boss ) )
        {
            continue;
        }

        if ( IS_TRUE( zombie.acc_is_elite ) )
        {
            // Elites are not chaff: flat chunk instead of the insta-kill.
            zombie DoDamage( ACC_WHIRLWIND_ELITE_DAMAGE, self.origin, self, self, "none" );
        }
        else
        {
            // Chaff: guaranteed kill, stock health+666 idiom.
            // TODO(acc-tune): docs/05 says insta-kill "until round ~15" -
            // first pass is unconditional; add a round-gated flat-damage
            // falloff in playtest if it trivializes high rounds.
            zombie DoDamage( zombie.health + 666, self.origin, self, self, "none" );
        }

        hits++;
    }

    // TODO(acc-anim): 360 spin animation + FX are Phase 4/5 polish.
    self iprintln( "Whirlwind: hit " + hits + " enemies" );
    acc_utility::log( "ability: whirlwind hit " + hits );
}

function effect_extended_fuse()
{
    // docs/05: next frag throw auto-airbursts at optimal height.
    // NOT implementable yet: needs a grenade-throw watcher plus a custom
    // detonation that replaces the stock fuse. The hook point exists -
    // VERIFIED(acc): players notify "grenade_fire" with the grenade entity
    // + weapon (zm/gametypes/_weapons.gsc:891, _zm.gsc:2353) - but the
    // airburst detonation itself is authored grenade behavior that lands
    // alongside _acc_weapon_emp_grenade.gsc in Phase 4.
    self iprintln( "Extended Fuse - effect lands in Phase 4" );
    acc_utility::log( "ability: extended_fuse stub (needs grenade_fire watcher + custom detonation)" );
}

function effect_overcharge()
{
    // docs/05: next EMP grenade stun is 2x duration.
    // NOT implementable yet: the EMP grenade itself is Phase 4 work
    // (_acc_weapon_emp_grenade.gsc, docs/05 Custom Weapon GSC Notes). The
    // 2x-stun consume hook belongs inside that module's explosion handler
    // once it exists.
    self iprintln( "Overcharge - effect lands in Phase 4" );
    acc_utility::log( "ability: overcharge stub (needs _acc_weapon_emp_grenade)" );
}
