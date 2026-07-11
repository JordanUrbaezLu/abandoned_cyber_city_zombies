// =============================================================================
// _acc_emergency_drop.gsc - the "clutch button"
//
// Design reference: docs/05_mechanics.md (Emergency Drop System).
//
// Spend 3 Data Shards at any power switch to call a random powerup drop.
// Drop weights bias toward economy at low rounds, survival at high rounds.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_powerups;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

#define ACC_EMERGENCY_COST_SHARDS 3
#define ACC_EMERGENCY_LATE_ROUND_THRESHOLD 25

#namespace acc_emergency_drop;

function init()
{
    acc_utility::log( "emergency_drop init" );

    level thread watch_power_triggers();
}

function watch_power_triggers()
{
    level endon( "end_game" );

    // Players use the power switch trigger (either side) to call a drop.
    // We piggyback on the same triggers placed for power activation.
    triggers = [];
    corp_trigs = getentarray( "acc_power_corp", "targetname" );
    vault_trigs = getentarray( "acc_power_vault", "targetname" );

    for ( i = 0; i < corp_trigs.size; i++ )  triggers[ triggers.size ] = corp_trigs[ i ];
    for ( i = 0; i < vault_trigs.size; i++ ) triggers[ triggers.size ] = vault_trigs[ i ];

    if ( triggers.size == 0 )
    {
        acc_utility::log( "emergency_drop: no power triggers found" );
        return;
    }

    for ( i = 0; i < triggers.size; i++ )
    {
        triggers[ i ] thread emergency_loop();
    }
}

function emergency_loop()
{
    self endon( "death" );

    for ( ;; )
    {
        self waittill( "trigger", player );

        // Only the POWER-ACTIVE side offers emergency drops (the dead side's
        // trigger was disabled by _acc_map_randomizer).
        if ( !isdefined( player ) ) continue;

        // TODO(acc-ux): show a 2-choice prompt ("activate power" / "emergency
        // drop") - for Phase 3 we just always offer emergency if power is on.
        // VERIFIED(acc): level._zm_is_power_on does not exist in BO3 (BO1/BO2
        // field); stock checks the "power_on" flag (_zm_powerups.gsc:399).
        if ( !level flag::get( "power_on" ) )
        {
            continue;
        }

        if ( !acc_data_shards::try_spend( player, ACC_EMERGENCY_COST_SHARDS ) )
        {
            player acc_utility::hud_msg( "Emergency Drop: needs " + ACC_EMERGENCY_COST_SHARDS + " Shards" );
            wait( 0.5 );
            continue;
        }

        drop = pick_drop_type( level.round_number );
        deliver_drop( player, drop );
        wait( 0.5 );
    }
}

function pick_drop_type( round_number )
{
    if ( round_number >= ACC_EMERGENCY_LATE_ROUND_THRESHOLD )
    {
        // Late rounds: survival bias.
        return acc_utility::acc_weighted_pick( array(
            weighted( 20, "max_ammo" ),
            weighted( 30, "insta_kill" ),
            weighted( 15, "double_points" ),
            weighted( 10, "overclock_scroll" ),
            weighted( 25, "random_perk" )
        ) );
    }
    else
    {
        // Early / mid rounds: economy bias.
        return acc_utility::acc_weighted_pick( array(
            weighted( 30, "max_ammo" ),
            weighted( 15, "insta_kill" ),
            weighted( 25, "double_points" ),
            weighted( 15, "overclock_scroll" ),
            weighted( 15, "random_perk" )
        ) );
    }
}

function deliver_drop( player, drop_type )
{
    acc_utility::log( "emergency drop: " + drop_type );
    player acc_utility::hud_msg( "Emergency Drop: " + drop_type );

    // VERIFIED(acc): zm_powerups::specific_powerup_drop( name, drop_spot )
    // (_zm_powerups.gsc:688, trailing 5 args optional); stock callers invoke
    // it ON level (_zm_ai_dogs.gsc:292). Powerup names confirmed registered:
    // "full_ammo" / "insta_kill" / "double_points".
    switch ( drop_type )
    {
    case "max_ammo":
        level thread zm_powerups::specific_powerup_drop( "full_ammo", player.origin );
        break;

    case "insta_kill":
        level thread zm_powerups::specific_powerup_drop( "insta_kill", player.origin );
        break;

    case "double_points":
        level thread zm_powerups::specific_powerup_drop( "double_points", player.origin );
        break;

    case "overclock_scroll":
        // Set a flag so next Overclock apply/reroll is free.
        player.acc_oc_free_scrolls = ( isdefined( player.acc_oc_free_scrolls ) ? player.acc_oc_free_scrolls : 0 ) + 1;
        break;

    case "random_perk":
        // VERIFIED(acc): give_random_perk() takes zero params, called ON the
        // player (_zm_perks.gsc:1093; caller _zm_powerup_free_perk.gsc:69).
        player zm_perks::give_random_perk();
        break;
    }
}

function weighted( w, v )
{
    s = spawnstruct();
    s.weight = w;
    s.value = v;
    return s;
}
