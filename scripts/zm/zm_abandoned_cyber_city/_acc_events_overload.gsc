// =============================================================================
// _acc_events_overload.gsc - Vault Overload side event (Vault)
//
// Design reference: docs/05_mechanics.md (Vault Overload state machine),
// docs/12_coop_rules.md (activator tether).
//
// 90-second hold event near the acc_overload_point script_struct:
//   - progress (elapsed) accrues ONLY while the activator is on the point
//     (docs/05: "leaving the point pauses progress");
//   - off-point time accrues CUMULATIVELY across the event; >8s total fails
//     (docs/12 tether rule - stepping back on does NOT reset the meter);
//   - only the activator is tethered; other players roam freely;
//   - activator down/disconnect = immediate fail.
//
// State machine mirrors the Hack Terminal: Available -> Active -> Success
// (Consumed) | Failed (Locked + takedown wave); either outcome re-opens the
// event once if the activator has Parallel Processing (Cyberware sr2a).
//
// GREYBOX WAVES (the verified-simple path): spawn pressure = level.zombie_total
// bumps at the 0/30/60s wall-clock marks, so the stock round engine delivers
// the zombies (citations in overload_wave_schedule). Forced elite types per
// wave are the post-greybox target (TODO(acc-design) below).
//
// Success: 3 Data Shards (activator only) + Server->Roof shortcut unlock.
// The shortcut reward no-ops gracefully (with a log) while the
// acc_shortcut_server_roof door entities are not yet authored.
// =============================================================================

#using scripts\codescripts\struct;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

#define ACC_OVERLOAD_ACTIVATION_COST_POINTS 1000
#define ACC_OVERLOAD_DURATION_SEC 90
#define ACC_OVERLOAD_LEAVE_THRESHOLD_SEC 8
#define ACC_OVERLOAD_POINT_RADIUS 96
#define ACC_OVERLOAD_REWARD_SHARDS 3
#define ACC_OVERLOAD_TICK_SEC 0.5
#define ACC_OVERLOAD_TAKEDOWN_COUNT 9

#namespace acc_events_overload;

function init()
{
    acc_utility::log( "events_overload init" );

    level.acc_overload_state = "available";
    level.acc_overload_attempts_used = 0;

    level thread watch_terminal();
}

function watch_terminal()
{
    level endon( "end_game" );

    triggers = getentarray( "acc_overload_terminal", "targetname" );
    if ( triggers.size == 0 )
    {
        acc_utility::log( "overload: no terminal placed yet" );
        return;
    }

    for ( i = 0; i < triggers.size; i++ )
    {
        triggers[ i ] thread terminal_loop();
    }
}

// self = the acc_overload_terminal trigger_use.
function terminal_loop()
{
    self endon( "death" );

    point_struct = struct::get( "acc_overload_point", "targetname" );
    if ( !isdefined( point_struct ) )
    {
        acc_utility::log( "overload: no acc_overload_point struct placed - terminal disarmed" );
        return;
    }

    self setcursorhint( "HINT_NOICON" ); // repo convention (_acc_mega_bottles.gsc:208)
    self set_hint_for_state();

    for ( ;; )
    {
        // VERIFIED(acc): use triggers notify "trigger" with the activating
        // player as the arg (_zm_power.gsc:92 'self waittill("trigger", user)').
        self waittill( "trigger", player );

        if ( !isdefined( player ) || !isplayer( player ) )
        {
            continue;
        }

        if ( !can_attempt( player ) )
        {
            player iprintln( "Vault Overload: unavailable" );
            wait( 0.5 );
            continue;
        }

        // VERIFIED(acc): affordability via zm_score::can_player_purchase
        // (_zm_score.gsc:655 - checks self.score >= cost AND honors the
        // free-shopping GobbleGum). Replaces the old raw player.score read.
        if ( !( player zm_score::can_player_purchase( ACC_OVERLOAD_ACTIVATION_COST_POINTS ) ) )
        {
            player iprintln( "Vault Overload: needs " + ACC_OVERLOAD_ACTIVATION_COST_POINTS + " points" );
            wait( 0.5 );
            continue;
        }

        // VERIFIED(acc): never write player.score directly - stock spends via
        // zm_score::minus_to_player_score (_zm_score.gsc:551), which also syncs
        // pers["score"], stats, the "spent_points" notify, and free-purchase
        // GobbleGum handling.
        player zm_score::minus_to_player_score( ACC_OVERLOAD_ACTIVATION_COST_POINTS );
        level.acc_overload_state = "active";
        level.acc_overload_attempts_used += 1;
        self set_hint_for_state();

        result = run_overload( player, point_struct );

        if ( result == "success" )
        {
            // Trench-only economy (user 2026-06-19): shards come from the trench, so this TOPSIDE
            // Vault objective's shard reward is OFF by default. The map-shortcut unlock still fires
            // (it's the objective's real payoff). Set `acc_overload_shard_drop 1` to restore the +3.
            if ( getdvarint( "acc_overload_shard_drop", 0 ) )
                acc_data_shards::grant_player( player, ACC_OVERLOAD_REWARD_SHARDS, "overload" );
            unlock_map_shortcut();
            level.acc_overload_state = "consumed";
        }
        else
        {
            level.acc_overload_state = "locked";
            level thread spawn_takedown_wave();
        }

        // Parallel Processing (Cyberware sr2a): the ACTIVATOR's passive
        // re-opens the event for exactly one more attempt per run, after
        // either outcome ("attempted twice per run instead of once",
        // docs/15 sr2a-parallel-processing). A failed first attempt still
        // fires the takedown wave above.
        if ( isdefined( player ) && player_has_parallel_processing( player ) &&
             level.acc_overload_attempts_used < 2 )
        {
            level.acc_overload_state = "available";
        }

        self set_hint_for_state();
        wait( 1.0 );
    }
}

function can_attempt( player )
{
    if ( level.acc_overload_state == "locked" ) return false;
    if ( level.acc_overload_state == "consumed" ) return false;
    if ( level.acc_overload_state == "active" ) return false;
    return true;
}

// Cyberware sr2a passive flag (set by _acc_cyberware.gsc::apply_sr2a). The
// flag itself is permanent for the run; the "consumption" is the
// attempts_used < 2 gate at the callsite in terminal_loop.
function player_has_parallel_processing( player )
{
    if ( !isdefined( player ) ) return false;
    return IS_TRUE( player.acc_cw_events_retry );
}

// self = terminal trigger.
function set_hint_for_state()
{
    // TODO(acc-verify): raw-string hint (community-standard but unverified
    // against our toolchain; stock uses precached istrings, _zm_power.gsc:89).
    // If blank on first compile, precache a triggerstring instead.
    if ( level.acc_overload_state == "available" )
    {
        self sethintstring( "Hold ^3&&1^7 to overload the vault [Cost: " + ACC_OVERLOAD_ACTIVATION_COST_POINTS + "]" );
    }
    else if ( level.acc_overload_state == "active" )
    {
        self sethintstring( "Overload in progress..." );
    }
    else if ( level.acc_overload_state == "consumed" )
    {
        self sethintstring( "Vault spent" );
    }
    else // locked
    {
        self sethintstring( "Vault locked" );
    }
}

// ---------------------------------------------------------------------------
// Main event
// ---------------------------------------------------------------------------

function run_overload( player, point_struct )
{
    player iprintln( "Vault Overload starting - hold the point!" );

    level thread overload_wave_schedule( 0, 1 );
    level thread overload_wave_schedule( 30, 2 );
    level thread overload_wave_schedule( 60, 3 );

    result = run_defense_loop( player, point_struct );

    // Kill any wave threads still pending - a fail at 20s must NOT fire the
    // 30s/60s waves after the event is over (the old code leaked them).
    level notify( "acc_overload_event_over" );

    if ( isdefined( player ) )
    {
        if ( result == "success" )
        {
            player iprintln( "Vault Overload SUCCESS" );
        }
        else
        {
            player iprintln( "Vault Overload FAILED" );
        }
    }

    return result;
}

function run_defense_loop( player, point_struct )
{
    elapsed = 0;
    off_total = 0;
    last_off_warn = 0;
    next_progress_announce = 15;

    while ( elapsed < ACC_OVERLOAD_DURATION_SEC )
    {
        wait( ACC_OVERLOAD_TICK_SEC );

        // Activator downed or disconnected = immediate fail (the tether is on
        // the activator only - docs/12_coop_rules.md).
        // VERIFIED(acc): zm_utility::is_player_valid (_zm_utility.gsc:1600)
        // = defined/alive/spawned/not-laststand/not-spectator; also false for
        // an undefined (disconnected) player.
        if ( !zm_utility::is_player_valid( player ) )
        {
            if ( isdefined( player ) )
            {
                player iprintln( "Vault Overload: activator down" );
            }
            return "failed";
        }

        if ( is_player_on_point( player, point_struct ) )
        {
            // Progress accrues only on the point (docs/05: leaving pauses it).
            elapsed += ACC_OVERLOAD_TICK_SEC;

            if ( elapsed >= next_progress_announce && elapsed < ACC_OVERLOAD_DURATION_SEC )
            {
                player iprintln( "Overload: " + int( ACC_OVERLOAD_DURATION_SEC - elapsed ) + "s of hold remaining" );
                next_progress_announce += 15;
            }
        }
        else
        {
            // CUMULATIVE off-point meter - intentionally never reset
            // (docs/12 tether rule; the old per-re-entry reset is gone).
            off_total += ACC_OVERLOAD_TICK_SEC;

            whole_off = int( off_total );
            if ( whole_off >= 1 && whole_off > last_off_warn )
            {
                last_off_warn = whole_off;
                player iprintln( "Return to the point! (" + whole_off + "/" + ACC_OVERLOAD_LEAVE_THRESHOLD_SEC + "s)" );
            }

            if ( off_total >= ACC_OVERLOAD_LEAVE_THRESHOLD_SEC )
            {
                player iprintln( "Vault Overload: abandoned the point" );
                return "failed";
            }
        }
    }

    return "success";
}

function is_player_on_point( player, point_struct )
{
    // VERIFIED(acc): the defend point is a script_struct (struct::get,
    // codescripts/struct.gsc:13) - a script object, NOT an engine entity, so
    // IsTouching (an entity/trigger-volume method; stock usage
    // _zm_laststand.gsc:1138) cannot apply to it. Player-near-point via
    // DistanceSquared is the stock pattern (_zm_utility.gsc:1384).
    if ( !isdefined( player ) ) return false;
    return distancesquared( player.origin, point_struct.origin ) <=
           ( ACC_OVERLOAD_POINT_RADIUS * ACC_OVERLOAD_POINT_RADIUS );
}

// ---------------------------------------------------------------------------
// Wave schedule (greybox spawn pressure)
// ---------------------------------------------------------------------------

function overload_wave_schedule( at_sec, wave_level )
{
    level endon( "end_game" );
    level endon( "acc_overload_event_over" );

    if ( at_sec > 0 )
    {
        wait( at_sec );
    }

    zombie_count = 4 + ( 2 * wave_level );

    // GREYBOX spawn pressure - the verified-simple path: bump the stock round
    // budget and let the stock round engine deliver the zombies.
    // VERIFIED(acc): round_spawning re-reads level.zombie_total every loop
    // iteration (_zm.gsc:3735) and runs for the whole round (endons only at
    // _zm.gsc:3680-3682), so a mid-round bump yields exactly that many extra
    // stock spawns; round_wait keeps the round open until they die
    // (_zm.gsc:4733). Stock itself bumps the counter mid-round
    // (zombie_utility.gsc:1861, _zm_spawner.gsc:2418). Between rounds the
    // bump is harmlessly overwritten by the next round's reset
    // (_zm.gsc:3715-3717).
    level.zombie_total += zombie_count;
    acc_utility::log( "overload: wave " + wave_level + " (+" + zombie_count + " zombie budget)" );

    // TODO(acc-design): post-greybox, force elites per docs/05 (wave 2: +1
    // elite type, wave 3: +2 elite types) via acc_elites::spawn_elite.
}

function spawn_takedown_wave()
{
    level endon( "end_game" );

    // GREYBOX: failure penalty as raw spawn pressure (same verified
    // level.zombie_total bump as overload_wave_schedule - citations there).
    level.zombie_total += ACC_OVERLOAD_TAKEDOWN_COUNT;
    acc_utility::log( "overload: takedown wave (+" + ACC_OVERLOAD_TAKEDOWN_COUNT + " zombie budget)" );

    // TODO(acc-design): post-greybox, 3x acc_elites::spawn_elite for each of
    // shielded/teleporter/emp per docs/05.
}

// ---------------------------------------------------------------------------
// Reward: map shortcut
// ---------------------------------------------------------------------------

function unlock_map_shortcut()
{
    doors = getentarray( "acc_shortcut_server_roof", "targetname" );
    if ( doors.size == 0 )
    {
        // TODO(acc-geom): author the Server->Roof shortcut door
        // (script_brushmodel, targetname acc_shortcut_server_roof). Until
        // then the reward no-ops gracefully so Overload stays completable.
        acc_utility::log( "overload: shortcut reward skipped - no acc_shortcut_server_roof entities placed" );
        return;
    }

    for ( i = 0; i < doors.size; i++ )
    {
        // VERIFIED(acc): stock open-door pattern for script_brushmodels:
        // NotSolid (_zm_blockers.gsc:507) + ConnectPaths so AI can path
        // through the freed space (_zm_blockers.gsc:511-516, brushmodel/model
        // classnames only); Hide for the visual.
        doors[ i ] notsolid();
        doors[ i ] connectpaths();
        doors[ i ] hide();
    }

    acc_utility::log( "overload: shortcut Server->Roof unlocked (" + doors.size + " door ents)" );
}
