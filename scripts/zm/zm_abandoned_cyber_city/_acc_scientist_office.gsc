// =============================================================================
// _acc_scientist_office.gsc - THE SCIENTIST'S OFFICE desk loot (user 2026-07-26)
//
// The office (gen_scientist_office.js room behind the Lab N wall, 2000-pt door
// enter_scientist_office) is the gun-stealing Scientist boss's lair (docs/44
// lore hook - "the scientist's office that comes around and steals your gun").
// ONE random CATEGORY-PAIRED loot set spawns per game, on/next to his desk:
//   - a random IMPLANT: High Caliber Rounds (bullet) / Warhead Bomber
//     (explosive) / Plasma Generator (energy) - on the ground by the desk,
//     via acc_boss_items::spawn_pickup persistent=true (the L4 balcony-gift
//     idiom: full carry/dupe/HUD flow, NO despawn timer).
//   - a random GUN of the SAME category on the desk top - the categories reuse
//     the EXACT classifiers the implants' damage gates read (_acc_damage::
//     weapon_is_bullet_gun / weapon_is_explosive_gun / is_energy_weapon), so
//     the pairing is definitionally consistent: the gun on the desk is always
//     one its implant buffs. Wonder weapons excluded (weapon_is_unbuffed_wonder
//     + the Blast-O-Matic, wonder-tier by docs/25) + the CYBERJACK (quest-only;
//     not in the box pool anyway - belt and suspenders).
// Pool source = the live mystery-box registry (level.zombie_weapons is_in_box),
// so roster changes auto-track. _acc_ variant twins skipped (the documented
// zombie_weapons-loop rule, memory variant-twin-upgrade-table-clobber).
//
// The gun display uses the armory-rack idiom (worldModel script_model + hover
// over the desk top) with the interact glow's blue unused-station pulse; take =
// zm_weapons::weapon_give with a full-slot deny (a silent give at the limit
// DESTROYS the held gun - _acc_armory.gsc:248 note). First-come, one per game.
// Hint strings are cursor-router-safe: no "for" (perk matcher = "hold"+"for",
// wallbuy = "hold"+" for " - memory lui-cursorhint-router-loose-weapon-matcher).
// =============================================================================

#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;     // is_player_alive (the module-standard alive gate)
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;      // find_item + spawn_pickup (persistent implant drop)
#using scripts\zm\zm_abandoned_cyber_city\_acc_damage;          // the 3 category classifiers (same fns the implants' damage gates use)
#using scripts\zm\zm_abandoned_cyber_city\_acc_interact_glow;   // blue unused-station pulse on the desk gun
#using scripts\zm\zm_abandoned_cyber_city\_acc_armory;          // the rack TRADE primitives: is_primary_owned / rack_tier_of / rack_restore_tier

// Desk top = z31 (p7_rus_desk_metal_vintage, sci_desk clip top); rack-idiom hover 6.
#define ACC_SCI_GUN_ORG     ( -75, 4490, 37 )
#define ACC_SCI_GUN_TRIG_Z  20
#define ACC_SCI_IMPLANT_ORG ( -170, 4420, 0 )

#namespace acc_scientist_office;

function init()
{
    level thread setup();
}

function setup()
{
    level endon( "end_game" );
    wait 1.5;   // after boss_items (item pool) + the stock weapon registry settle - the _acc_exo cadence

    // Roll the category ONCE - implant and gun stay paired by construction.
    roll = acc_utility::acc_rand_int( 3 );
    if ( roll == 0 )      { item_id = "high_caliber";     cat = "bullet"; }
    else if ( roll == 1 ) { item_id = "warhead_bomber";   cat = "explosive"; }
    else                  { item_id = "plasma_generator"; cat = "energy"; }

    // --- IMPLANT on the ground by the desk (persistent - no despawn timer) ----
    item_struct = acc_boss_items::find_item( item_id );
    if ( isdefined( item_struct ) )
        acc_boss_items::spawn_pickup( item_struct, ACC_SCI_IMPLANT_ORG, true );
    else
        acc_utility::log( "^1scientist_office: item '" + item_id + "' not in pool - implant skipped" );

    // --- matching GUN on the desk ---------------------------------------------
    pool = build_gun_pool( cat );
    if ( pool.size == 0 )
    {
        acc_utility::log( "^1scientist_office: empty '" + cat + "' gun pool - desk gun skipped" );
        return;
    }
    wpn = pool[ acc_utility::acc_rand_int( pool.size ) ];
    level thread spawn_desk_gun( wpn );

    acc_utility::log( "scientist_office: category=" + cat + " implant=" + item_id
                      + " gun=" + wpn.name + " (pool " + pool.size + ")" );
}

// The category pool from the LIVE box registry. Filters mirror the implants'
// own damage-gate classifiers so gun & implant always agree (see header).
function build_gun_pool( cat )
{
    pool = [];
    if ( !isdefined( level.zombie_weapons ) ) return pool;

    keys = GetArrayKeys( level.zombie_weapons );
    for ( i = 0; i < keys.size; i++ )
    {
        wpn = keys[ i ];
        if ( !isdefined( wpn ) || !isdefined( wpn.name ) ) continue;
        name = wpn.name;
        if ( IsSubStr( name, "_acc_" ) )                          continue;   // variant twins NEVER roll (the zombie_weapons-loop rule)
        if ( !IS_TRUE( level.zombie_weapons[ wpn ].is_in_box ) )  continue;   // box pool = the map's obtainable-gun universe
        if ( acc_damage::weapon_is_unbuffed_wonder( name ) )      continue;   // Fire Bow / Thundergun / Winter's Howl
        if ( IsSubStr( name, "t9_semiauto_cosplay" ) )            continue;   // Blast-O-Matic - wonder-tier (docs/25), user: "no wonder weapons"
        if ( IsSubStr( name, "apex_lstar" ) )                     continue;   // THE CYBERJACK chassis (quest-only; not in box - safety)

        if ( cat == "energy" )
        {
            if ( acc_damage::is_energy_weapon( name ) )
                pool[ pool.size ] = wpn;
        }
        else if ( cat == "explosive" )
        {
            if ( acc_damage::weapon_is_explosive_gun( name ) )
                pool[ pool.size ] = wpn;
        }
        else   // bullet
        {
            if ( acc_damage::weapon_is_bullet_gun( name ) )
                pool[ pool.size ] = wpn;
        }
    }
    return pool;
}

// Desk display (the ARMORY-RACK idiom, verbatim: worldModel guard + UseBuildKitWeaponModel;
// the first cut's bare SetModel(wpn.worldModel) shipped NO visible gun - live 2026-07-26).
// `player` = whoever's buildkit variant the model wears (host at boot, the trader after).
function desk_display( player, wpn )
{
    if ( !isdefined( wpn.worldModel ) ) return undefined;   // nothing to show (pack oddities)
    mdl = spawn( "script_model", ACC_SCI_GUN_ORG );
    if ( !isdefined( mdl ) ) return undefined;               // ent-pool guard (rack precedent)
    mdl.angles = ( 0, 0, 0 );   // lengthwise along the desk's long X axis (the rack orientation rule; a brief "sideways" ask was reverted same-day 2026-07-26)
    upgraded = zm_weapons::is_weapon_upgraded( wpn );
    camo = undefined;
    if ( upgraded )
        camo = zm_weapons::get_pack_a_punch_camo_index( undefined );
    mdl UseBuildKitWeaponModel( player, wpn, camo, upgraded );
    acc_interact_glow::glow_on( mdl );   // the blue unused-station pulse (user reminder 2026-07-26)
    return mdl;
}

// The Scientist's desk = a PERPETUAL TRADE station (user 2026-07-26 "it will remove the
// gun you are holding... place the gun you were holding on the desk. Like the gun
// exchange system we have near plaza"): hold-USE swaps your HELD primary with whatever
// rests on the desk - the prototype first, then whatever the last trader left. OC tier
// rides the desk gun exactly like the armory rack (rack_tier_of/rack_restore_tier).
function spawn_desk_gun( wpn )
{
    level endon( "end_game" );

    s = SpawnStruct();
    s.wpn = wpn;
    s.tier = 0;      // the prototype starts untiered; traded-in guns carry theirs
    s.mdl = undefined;

    // the buildkit display needs a player context - poll briefly (host exists by now)
    while ( GetPlayers().size == 0 )
        wait 0.25;
    s.mdl = desk_display( GetPlayers()[ 0 ], s.wpn );

    t = spawn( "trigger_radius_use", ACC_SCI_GUN_ORG + ( 0, 0, ACC_SCI_GUN_TRIG_Z ), 0, 48, 60 );
    t TriggerIgnoreTeam();   // REQUIRED on a script-spawned use trigger (stock _zm_perks.gsc:1523)
    t SetCursorHint( "HINT_NOICON" );
    // NO gun name in the hint/toast - the armory-rack precedent (2026-07-10 UI pass:
    // wpn.name is the internal class name, displayname localization unverifiable; the
    // desk-top world model IS the identity). Router-safe: no "for", no "upgrade"+"weapon".
    t SetHintString( "Hold ^3[{+activate}]^7 - trade your gun with the Scientist's desk" );

    t endon( "death" );
    for ( ;; )
    {
        t waittill( "trigger", player );
        if ( !acc_data_shards::is_player_alive( player ) ) continue;
        if ( player HasWeapon( s.wpn ) )
        {
            player iprintln( "^3You already carry the desk gun" );
            continue;
        }
        held = player GetCurrentWeapon();
        if ( !isdefined( held ) || held == level.weaponNone
             || zm_utility::is_melee_weapon( held ) || zm_utility::is_placeable_mine( held )
             || !acc_armory::is_primary_owned( player, held ) )
        {
            player iprintln( "^3Hold the primary you want to trade" );
            continue;
        }

        // TRADE: snapshot the held gun's tier BEFORE the take (the armory deposit rule),
        // swap the weapons, stamp the desk gun's tier onto the taker AFTER the give.
        held_tier = acc_armory::rack_tier_of( player, held );
        give      = s.wpn;
        give_tier = s.tier;
        player zm_weapons::weapon_take( held );
        player zm_weapons::weapon_give( give, false, false, false, true );   // b_switch: an intentional trade swaps to hand
        acc_armory::rack_restore_tier( player, give, give_tier );

        s.wpn  = held;
        s.tier = held_tier;
        if ( isdefined( s.mdl ) ) s.mdl Delete();
        s.mdl = desk_display( player, s.wpn );
        player iprintln( "^5The desk gun is yours^7 - your old one rests in the Scientist's office" );
    }
}
