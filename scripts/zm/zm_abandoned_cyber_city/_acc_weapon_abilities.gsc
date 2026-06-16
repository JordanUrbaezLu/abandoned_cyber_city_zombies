// =============================================================================
// _acc_weapon_abilities.gsc - per-category active weapon abilities
//
// Design reference: docs/05_weapons.md (Weapon Abilities - intrinsic).
//
// Every weapon CATEGORY has one signature active ability, triggered by a
// hotkey with a cooldown. The ability is intrinsic to the weapon (no unlock,
// no cost) and available from round 1.
//
// Status: LIVE for all 5 shipped guns (user, 2026-06-14). Each HELD gun maps to
// one LIVE effect (build_ability_table):
//      * Five-Seven (pistol)  -> Precision Mode: arms player.acc_ability_crit_shots
//        = 3; _acc_damage::on_ai_damage consumes it (auto-crit 4x/hit, decrements).
//      * ASM1 (smg)           -> Whirlwind: self-contained 96-unit AoE (below).
//      * Tac-19 (shotgun)     -> Slug Round: arms player.acc_ability_slug_next;
//        _acc_damage consumes it (3x once). The 2x-range/tight-cone half needs a
//        weapon-override GDT and stays Phase 4.
//      * AK-47 + AE4 (ar)     -> Focus Fire: arms acc_ability_crit_shots = 6 (same
//        damage contract as Precision Mode, longer burst for full-auto ARs; both
//        ARs share the category ability - AE4's identity is energy + penetration).
//  - UNUSED effects (kept defined, not in the table, no reachable weapon now):
//    effect_triple_tap, effect_stabilizer (variant-swap; the recoil twins are
//    Deadshot-perk-driven, not this), effect_thermal_vision, effect_extended_fuse,
//    effect_overcharge. Re-add to build_ability_table if a matching gun returns.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_overclocks;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;

#define ACC_WHIRLWIND_RADIUS_SQ    9216  // 96u * 96u (docs/05_weapons.md)
#define ACC_WHIRLWIND_ELITE_DAMAGE 1000  // flat - elites are not chaff
#define ACC_PRECISION_CRIT_SHOTS   3
#define ACC_FOCUS_FIRE_CRIT_SHOTS  6   // AK-47 (AR): longer auto-crit burst (full-auto)

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

    // The map ships 5 HELD guns; each gets ONE LIVE signature ability.
    // (Melee/grenade/sniper categories stay gone: getcurrentweapon() never
    // returns an offhand and no sniper gun exists, so they could never fire -
    // see weapon_name_to_ability_category. effect_triple_tap / _stabilizer /
    // _thermal_vision / _extended_fuse / _overcharge remain defined but unused.)
    t[ "pistol" ]  = ability( "precision_mode", 30, &effect_precision_mode ); // Five-Seven: 3 auto-crit shots
    t[ "smg" ]     = ability( "whirlwind",      20, &effect_whirlwind );      // ASM1: 96u AoE panic clear
    t[ "shotgun" ] = ability( "slug_round",     20, &effect_slug_round );     // Tac-19: next shot 3x single-target
    t[ "ar" ]      = ability( "focus_fire",     25, &effect_focus_fire );     // AK-47 + AE4: 6 auto-crit shots

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
// THE MAP SHIPS 5 GUNS (user, 2026-06-14):
//   Five-Seven  t6_fiveseven  (pistol)  - start pistol; ability = Precision Mode
//   ASM1        s1_asm1       (smg)     - ability = Whirlwind (96u AoE panic)
//   Tac-19      s1_tac19      (shotgun) - ability = Slug Round (next shot 3x)
//   AK-47       t6_ak47       (ar)      - ability = Focus Fire (6 auto-crit shots)
//   AE4         s1_ae4        (ar)      - AW directed-energy; shares Focus Fire
// Offhand framework weapons (knife melee, frag_grenade lethal) + laststand
// pistol_standard stay for the framework but have NO ability (never the HELD
// weapon, so getcurrentweapon never returns them). Everything else
// (ICR/Man-O-War/Locus/etc.) was removed. Skye imports engine-prefixed
// (s1_=AW, t6_=BO2, docs/21); stock names class-based + unsuffixed.
// ---------------------------------------------------------------------------

function weapon_name_to_ability_category( weapon_name )
{
    // Only the 5 HELD guns map to a category. getcurrentweapon() drives this
    // (try_activate_ability) - the offhand knife + grenades are never the
    // "current weapon", so they have no reachable ability and are absent.
    pistol_list  = array( "pistol_standard", "t6_fiveseven" );  // Five-Seven (+ laststand)
    smg_list     = array( "s1_asm1",                            // ASM1
                          "iw6_ripper_smg", "iw6_ripper_smg_zm",
                          "iw6_ripper_ar", "iw6_ripper_ar_zm" );  // Ripper (both modes -> Whirlwind)
    shotgun_list = array( "s1_tac19", "t6_olympia" );           // Tac-19, Olympia (BO2, 2026-06-15) -> Slug Round
    ar_list      = array( "t6_ak47", "s1_ae4", "t6_galil" );   // AK-47, AE4, Galil (BO2, 2026-06-15) -> Focus Fire

    if ( array::contains( pistol_list, weapon_name ) ) return "pistol";
    if ( array::contains( smg_list, weapon_name ) ) return "smg";
    if ( array::contains( shotgun_list, weapon_name ) ) return "shotgun";
    if ( array::contains( ar_list, weapon_name ) ) return "ar";
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
    // docs/05: 5s zero recoil + 20% fire rate. Both are baked weapon-GDT
    // properties with no live setter, so they are delivered by the weapon-variant
    // SWAP framework (_acc_weapon_variants): hand the player a reduced-recoil +
    // fast-fire twin of their current gun for the duration, then swap the base
    // back. Maps to the strongest baked recoil tier (-40%, recoil40) + fastfire
    // (no literal "zero" twin; -40% is the closest level). In Phase 1 the fast half
    // no-ops until fastfire twins exist (Phase 2).
    // Inert until the twins are baked + allow-listed (docs/31 §4-5); the cooldown
    // is still consumed so the input loop stays testable end-to-end.
    self acc_weapon_variants::apply_timed_variant( array( "recoil40", "fastfire" ), 5 );
    self iprintln( "Stabilizer: 5s recoil/fire-rate boost" );
    acc_utility::log( "ability: stabilizer -> timed weapon-variant (inert until twins baked)" );
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

function effect_focus_fire()
{
    // docs/05: AK-47 (AR) signature - next ACC_FOCUS_FIRE_CRIT_SHOTS shots
    // auto-crit (4x, ignore hit-loc). Reuses the SAME damage CONTRACT as
    // Precision Mode (_acc_damage::on_ai_damage consumes acc_ability_crit_shots,
    // decrementing per hit) but arms a longer burst to fit a full-auto AR.
    self.acc_ability_crit_shots = ACC_FOCUS_FIRE_CRIT_SHOTS;
    acc_utility::log( "ability: focus_fire armed (" + ACC_FOCUS_FIRE_CRIT_SHOTS + " crit shots)" );
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
