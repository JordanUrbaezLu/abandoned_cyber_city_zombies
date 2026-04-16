// =============================================================================
// _acc_emergency_drop.gsc - the "clutch button"
//
// Design reference: docs/06_mechanics.md (Emergency Drop System).
//
// Spend 3 Data Shards at any power switch to call a random powerup drop.
// Drop weights bias toward economy at low rounds, survival at high rounds.
// =============================================================================

#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

#define ACC_EMERGENCY_COST_SHARDS 3
#define ACC_EMERGENCY_LATE_ROUND_THRESHOLD 25

init()
{
    _acc_utility::log( "emergency_drop init" );

    level thread watch_power_triggers();
}

watch_power_triggers()
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
        _acc_utility::log( "emergency_drop: no power triggers found" );
        return;
    }

    for ( i = 0; i < triggers.size; i++ )
    {
        triggers[ i ] thread emergency_loop();
    }
}

emergency_loop()
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
        if ( !level._zm_is_power_on() )
        {
            continue;
        }

        if ( !_acc_data_shards::try_spend( player, ACC_EMERGENCY_COST_SHARDS ) )
        {
            player iprintln( "Emergency Drop: needs " + ACC_EMERGENCY_COST_SHARDS + " Shards" );
            wait( 0.5 );
            continue;
        }

        drop = pick_drop_type( level.round_number );
        deliver_drop( player, drop );
        wait( 0.5 );
    }
}

pick_drop_type( round_number )
{
    if ( round_number >= ACC_EMERGENCY_LATE_ROUND_THRESHOLD )
    {
        // Late rounds: survival bias.
        return _acc_utility::acc_weighted_pick( array(
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
        return _acc_utility::acc_weighted_pick( array(
            weighted( 30, "max_ammo" ),
            weighted( 15, "insta_kill" ),
            weighted( 25, "double_points" ),
            weighted( 15, "overclock_scroll" ),
            weighted( 15, "random_perk" )
        ) );
    }
}

deliver_drop( player, drop_type )
{
    _acc_utility::log( "emergency drop: " + drop_type );
    player iprintln( "Emergency Drop: " + drop_type );

    switch ( drop_type )
    {
    case "max_ammo":
        // TODO(acc-verify): stock powerup spawn helper.
        // _zm_powerups::specific_powerup_drop( "full_ammo", player.origin );
        break;

    case "insta_kill":
        // _zm_powerups::specific_powerup_drop( "insta_kill", player.origin );
        break;

    case "double_points":
        // _zm_powerups::specific_powerup_drop( "double_points", player.origin );
        break;

    case "overclock_scroll":
        // Set a flag so next Overclock apply/reroll is free.
        player.acc_oc_free_scrolls = ( isdefined( player.acc_oc_free_scrolls ) ? player.acc_oc_free_scrolls : 0 ) + 1;
        break;

    case "random_perk":
        // TODO(acc-verify): _zm_perks::give_random_perk( player ) or equivalent.
        break;
    }
}

weighted( w, v )
{
    s = spawnstruct();
    s.weight = w;
    s.value = v;
    return s;
}
