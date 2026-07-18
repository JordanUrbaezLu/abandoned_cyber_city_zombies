// =============================================================================
// _acc_ammo_crate.gsc - the trench AMMO CRATE (user 2026-06-27)
//
// A buyable ammo refill - THREE crates: two BOOKEND the abyss descent (user 2026-06-27): one on L2 EAST
// (400,1948,-480) by the Overclock (entry refill) + one on L5 WEST (-400,1948,-1200) at the bottom before
// Paradise; a third IN Paradise itself (850,-1650,-1200, east wall - user 2026-07-09) so the finale
// onslaught has an in-arena refill. (Layout: OC + crate L2, Glitch Altar L3, AK-47 wall-buy L4, crate L5 -
// see _acc_glitch_altar::spawn_altars; the Paradise crate is spawned by spawn_paradise there.) Walk up,
// hold [activate], and your HELD weapon's reserve is topped off (like a personal Max Ammo). NOTE: the
// Action Figure melee is excluded (crate_cost returns 0 for it).
//
// PRICING - by the held weapon's PaP state (user 2026-06-27):
//   - a BASE (un-Pack-a-Punched) gun ........ 1000 points   (acc_ammo_crate_base)
//   - a PACK-A-PUNCHED gun .................. 5000 points   (acc_ammo_crate_pap)
//   - a WONDER weapon ....................... 10000 points  (acc_ammo_crate_wonder, user 2026-07-08) -
//     flat, regardless of PaP state. "Wonder" = _acc_pap_levels::pap_price_bucket == WONDER (the same
//     single-source list as the WONDER PaP price tier: Thundergun / Fire Bow / Blast-O-Matic; the
//     Leviathan Axe is also WONDER there but is a melee with no ammo -> not serviceable here).
//   - a gun with NO PaP version (melee / equipment / specials that can't be packed) ... NOTHING.
//     Those weapons can't be serviced here - the crate just tells you and charges nothing.
//     (Exception: the WONDER check runs FIRST, so the Fire Bow - custom in-place PaP, no registered
//     .upgrade form - is still refillable here at the wonder price.)
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
#using scripts\zm\zm_abandoned_cyber_city\_acc_pap_levels; // pap_price_bucket (the WONDER-tier gun list, single source of truth)

// STATION REMODEL v2 (user 2026-07-12): [West] Ammo Crates pack (Westchief596; ZeRoY's S4
// ammo-crate model + textures) - MODEL-ONLY lift, same recipe as the EC machine (memory
// ec-machine-model-west-pack): GDT = install source_data\acc_west_ammo_crate.gdt, assets under
// _custom\westchief596\ammo_crate\. Replaced the stock Shangri-La stack (78x20x21); new bounds
// 28.9x33.3x25.2, floor-flush, x NOT origin-centered (min -19.6 / max +9.3) - the
// add_prop_clips.js clips mirror that offset. NO _col LOD -> stays clip-dependent.
#precache( "model", "west_ammo_crate_model" );

#namespace acc_ammo_crate;

// Script-spawn the ammo crate (model + use-trigger + loop) at origin, facing yaw. Pure GSC, no bake.
function spawn_crate_at( origin, yaw )
{
    m = spawn( "script_model", origin );
    m setmodel( "west_ammo_crate_model" );
    // 2.5x VISUAL scale (user 2026-07-12: "these tiny boxes you have to look down to even see" -
    // the West model is only ~29x33x25 units, knee-high; was 3x same day, user tuned down to 2.5x).
    // SetScale is the AW-box-proven visual-only scaler: the model has NO _col LOD, so collision
    // comes from the .map prop clips - which are BAKED AT 2.5x TO MATCH (user 2026-07-12
    // "clips must align with the actual model size"; acc_clip_ammo_crate_l2/_l5 +
    // acc_clip_paradise_ammo_crate scaled about each model origin in the .map). The dvar below is
    // still live-tunable for a quick visual experiment, but a PERMANENT scale change must re-size
    // those three clip brushes too (geometry -> full build + LED bake).
    scale = getdvarfloat( "acc_ammo_crate_scale", 2.5 );
    if ( scale > 0 && scale != 1 ) m SetScale( scale );
    if ( isdefined( yaw ) ) m.angles = ( 0, yaw, 0 );

    // Use-radius grows with the crate so the prompt still reaches from the enlarged face
    // (64 was flush against the 1x footprint).
    r = int( 64 + ( scale - 1 ) * 24 );
    if ( r < 64 ) r = 64;
    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, r, 80 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (stock _zm_perks.gsc:1523).
    t SetCursorHint( "HINT_NOICON" );
    // CONSTANT hint - both prices baked in (prices stay numeric per the vague-UI rule). The LIVE cost can't go
    // in the hint (it changes with the held weapon = an unbounded string churn -> the 250-triggerstring cap);
    // the per-use result is shown via hud_msg (chat-style, cache-free) instead. Memory triggerstring-cap-hint-strings.
    // Buyable-UI audit fix (2026-07-03): "Pack-a-Punched" + "weapon" made the Aetherium router
    // show the PACK-A-PUNCH card here. "PaP'd" + "gun" avoid every router token -> DefaultHint.
    t SetHintString( "Hold ^3[{+activate}]^7  ^5AMMO CRATE^7 - refill held gun  ^2[2000 base / 10000 PaP'd / 20000 wonder]" );
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

// The price for refilling `weapon`: 10000 if PaP'd, 2000 if a base gun that HAS a PaP version, 0 (= not
// serviceable) for no weapon or a weapon with no real PaP form. Live dvars acc_ammo_crate_base / _pap.
// Prices DOUBLED 2026-07-13 (user "cost of buying ammo needs a nerf, double the current costs").
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

    // WONDER weapons = flat 10k, regardless of PaP state (user 2026-07-08). Same single-source list as
    // the WONDER PaP price tier (_acc_pap_levels::pap_price_bucket). Checked BEFORE the PaP'd/upgradeable
    // gates on purpose: the Fire Bow's PaP is a custom in-place tier bump (no registered .upgrade form),
    // so the has-a-PaP-version gate below would wrongly read it as unserviceable. The Leviathan Axe is
    // WONDER-bucketed too but is a melee with NO ammo - GiveMaxAmmo would charge 10k for nothing, so it
    // stays unserviceable (same treatment as the Action Figure above).
    if ( isdefined( weapon.name ) )
    {
        if ( IsSubStr( weapon.name, "leviathan" ) )
            return 0;   // melee wonder - no ammo to refill
        if ( acc_pap_levels::pap_price_bucket( weapon.name ) == "WONDER" )
            return getdvarint( "acc_ammo_crate_wonder", 20000 );
    }

    // Already Pack-a-Punched -> the 5k tier.
    if ( zm_weapons::is_weapon_upgraded( weapon ) )
        return getdvarint( "acc_ammo_crate_pap", 10000 );

    // Base form: does this gun even HAVE a PaP version? (Same test as _acc_weapon_variants line 180.)
    base = zm_weapons::get_base_weapon( weapon );
    if ( !isdefined( base ) || base == level.weaponNone )
        return 0;
    if ( !isdefined( level.zombie_weapons[ base ] ) )
        return 0;                                  // not a registered/packable gun
    up = level.zombie_weapons[ base ].upgrade;
    if ( !isdefined( up ) || up == level.weaponNone || up == base )
        return 0;                                  // no real upgrade form -> can't be serviced

    return getdvarint( "acc_ammo_crate_base", 2000 );
}
