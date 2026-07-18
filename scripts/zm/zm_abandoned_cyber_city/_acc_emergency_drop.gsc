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
        triggers[ i ] thread emergency_prompt_gate();
        triggers[ i ] thread emergency_loop();
    }
}

// PROMPT GATE - a HARD PROGRESSION BLOCK guard (2026-07-15). The emergency trigger now sits ON
// the stock power switch (its box is built around the switch's own use trigger so the clutch
// button is where the switch is). emergency_loop below gates the ACTION on "power_on" - but a
// trigger_use PROMPTS from map load regardless of what its script thread does with the notify.
// So pre-power there were TWO overlapping trigger_use ents on the breaker: if the engine picked
// ours, [F] fired our notify, we `continue`d (power is off), and THE PLAYER COULD NEVER TURN THE
// POWER ON = unwinnable run. Gating the action is NOT enough; the PROMPT itself must not exist
// until power is on. After power-on there is no conflict to gate: stock _zm_power::electric_switch
// delete()s use_elec_switch (our prefab sets no script_noteworthy "allow_power_off").
//
// Re-enable is LIVE-SIDE ONLY: _acc_map_randomizer::disable_dead_side_emergency_triggers()
// triggerenable(false)s the dead side's copy every run, so a blanket re-enable here would
// RESURRECT it. We read level.acc_map_state.power_switch_side at power-on time (long after the
// randomizer has run) and leave a dead-side trigger disabled forever, which is also exactly what
// emergency_loop's own "only the POWER-ACTIVE side offers emergency drops" comment intends.
function emergency_prompt_gate()    // self = an emergency trigger (either side)
{
    self endon( "death" );

    if ( !level flag::get( "power_on" ) )
    {
        self triggerenable( false );
        level flag::wait_till( "power_on" );
    }

    live_side = "corp";
    if ( isdefined( level.acc_map_state ) && isdefined( level.acc_map_state.power_switch_side ) )
        live_side = level.acc_map_state.power_switch_side;

    if ( self.targetname == "acc_power_" + live_side )
    {
        self triggerenable( true );
        acc_utility::log( "emergency_drop: prompt armed on " + self.targetname + " (power on)" );
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

    case "random_perk":
        // VERIFIED(acc): give_random_perk() takes zero params, called ON the
        // player (_zm_perks.gsc:1093; caller _zm_powerup_free_perk.gsc:69).
        player zm_perks::give_random_perk();
        // Kortifex "Random perk!" line - nil-guarded fn-pointer so this module
        // needs NO #using on _acc_kortifex (absent/killed = silent no-op).
        if ( isdefined( level.acc_kx_announce_random_perk ) )
            [[ level.acc_kx_announce_random_perk ]]();
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
