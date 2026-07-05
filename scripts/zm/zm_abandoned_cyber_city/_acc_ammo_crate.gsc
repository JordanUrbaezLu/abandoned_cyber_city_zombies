// =============================================================================
// _acc_ammo_crate.gsc - the trench AMMO CRATE (user 2026-06-27)
//
// A buyable ammo refill - TWO crates that BOOKEND the abyss descent (user 2026-06-27): one on L2 EAST
// (400,1948,-480) by the Overclock (entry refill) + one on L5 WEST (-400,1948,-1200) at the bottom before
// Paradise. (Layout: OC + crate L2, Glitch Altar L3, AK-47 wall-buy L4, crate L5 - see
// _acc_glitch_altar::spawn_altars.) Walk up, hold [activate], and your HELD weapon's reserve is topped off
// (like a personal Max Ammo). NOTE: the Action Figure melee is excluded (crate_cost returns 0 for it).
//
// PRICING - by the held weapon's PaP state (user 2026-06-27):
//   - a BASE (un-Pack-a-Punched) gun ........ 1000 points   (acc_ammo_crate_base)
//   - a PACK-A-PUNCHED gun .................. 5000 points   (acc_ammo_crate_pap)
//   - a gun with NO PaP version (melee / equipment / specials that can't be packed) ... NOTHING.
//     Those weapons can't be serviced here - the crate just tells you and charges nothing.
//
// The "has a PaP version" test is the SAME one _acc_weapon_variants uses (level.zombie_weapons[base].upgrade
// is a real, different weapon), and "is it PaP'd" is stock zm_weapons::is_weapon_upgraded - so the gate
// agrees with the rest of the PaP pipeline. Refill = GiveMaxAmmo (fills the shared RESERVE; the magazine
// fills on the next reload, exactly like the stock Max Ammo powerup).
//
// GSC-ONLY + LED-SAFE: the crate is a script-spawned model + a trigger_radius_use (no .map / brush / bake),
// mirroring acc_overclocks::spawn_terminal_at. Spawned by _acc_glitch_altar::spawn_altars alongside the
// overclock terminal (same room, same lifecycle - after the abyss layers + navmesh exist).
// =============================================================================

#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;       // can_player_purchase / minus_to_player_score (charge points)
#using scripts\zm\_zm_utility;     // is_player_valid
#using scripts\zm\_zm_weapons;     // is_weapon_upgraded / get_base_weapon (PaP state + base lookup)

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;   // hud_msg / log

#precache( "model", "p7_cai_stacking_cargo_crate" );

#namespace acc_ammo_crate;

// Script-spawn the ammo crate (model + use-trigger + loop) at origin, facing yaw. Pure GSC, no bake.
function spawn_crate_at( origin, yaw )
{
    m = spawn( "script_model", origin );
    m setmodel( "p7_cai_stacking_cargo_crate" );
    if ( isdefined( yaw ) ) m.angles = ( 0, yaw, 0 );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 64, 80 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (stock _zm_perks.gsc:1523).
    t SetCursorHint( "HINT_NOICON" );
    // CONSTANT hint - both prices baked in (prices stay numeric per the vague-UI rule). The LIVE cost can't go
    // in the hint (it changes with the held weapon = an unbounded string churn -> the 250-triggerstring cap);
    // the per-use result is shown via hud_msg (chat-style, cache-free) instead. Memory triggerstring-cap-hint-strings.
    // Buyable-UI audit fix (2026-07-03): "Pack-a-Punched" + "weapon" made the Aetherium router
    // show the PACK-A-PUNCH card here. "PaP'd" + "gun" avoid every router token -> DefaultHint.
    t SetHintString( "Hold ^3[{+activate}]^7  ^5AMMO CRATE^7 - refill held gun  ^2[1000 base / 5000 PaP'd]" );
    t thread crate_loop();

    acc_utility::log( "ammo crate spawned at " + origin );
}

function crate_loop()
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !isdefined( player ) || !zm_utility::is_player_valid( player ) )
            continue;

        weapon = player GetCurrentWeapon();
        cost   = crate_cost( weapon );

        // No PaP version (melee / equipment / no-pack specials) -> not serviceable here. Charge nothing.
        if ( cost <= 0 )
        {
            player acc_utility::hud_msg( "^5AMMO CRATE^7 - this weapon can't be refilled here" );
            wait( 0.75 );
            continue;
        }

        if ( !( player zm_score::can_player_purchase( cost ) ) )
        {
            player PlaySound( "zmb_no_purchase" );
            player acc_utility::hud_msg( "^5AMMO CRATE^7 - you need ^3" + cost + "^7 points" );
            wait( 0.75 );
            continue;
        }

        player zm_score::minus_to_player_score( cost );
        player PlaySound( "zmb_cha_ching" );
        player GiveMaxAmmo( weapon );   // fills the shared RESERVE (magazine tops off on the next reload)
        player acc_utility::hud_msg( "^5AMMO CRATE^7 - ammo refilled  ^1(-" + cost + ")" );
        wait( 0.75 );
    }
}

// The price for refilling `weapon`: 5000 if PaP'd, 1000 if a base gun that HAS a PaP version, 0 (= not
// serviceable) for no weapon or a weapon with no real PaP form. Live dvars acc_ammo_crate_base / _pap.
function crate_cost( weapon )
{
    if ( !isdefined( weapon ) || weapon == level.weaponNone )
        return 0;

    // Action Figure (melee special) is NEVER serviceable here - it has no ammo (one-knife). Its PaP forms (the
    // self-upgrade gate on the base + the speed twins marked is_weapon_upgraded for machine visibility) would
    // otherwise read as PaP'd/packable and get charged. Exclude the whole family by substring (covers the base +
    // t8_melee_figure_fast1/2/3) plus the off-hand. Matches _acc_pap_levels::is_actionfigure. user 2026-06-27.
    if ( isdefined( weapon.name ) && ( IsSubStr( weapon.name, "t8_melee_figure" ) || weapon.name == "t8_actionfigure_melee" ) )
        return 0;

    // Already Pack-a-Punched -> the 5k tier.
    if ( zm_weapons::is_weapon_upgraded( weapon ) )
        return getdvarint( "acc_ammo_crate_pap", 5000 );

    // Base form: does this gun even HAVE a PaP version? (Same test as _acc_weapon_variants line 180.)
    base = zm_weapons::get_base_weapon( weapon );
    if ( !isdefined( base ) || base == level.weaponNone )
        return 0;
    if ( !isdefined( level.zombie_weapons[ base ] ) )
        return 0;                                  // not a registered/packable gun
    up = level.zombie_weapons[ base ].upgrade;
    if ( !isdefined( up ) || up == level.weaponNone || up == base )
        return 0;                                  // no real upgrade form -> can't be serviced

    return getdvarint( "acc_ammo_crate_base", 1000 );
}
