// =============================================================================
// _acc_events_hack.gsc - Hack Terminal side event (Corporate Plaza)
//
// Design reference: docs/06_mechanics.md (Hack Terminal state machine),
// docs/15_coop_rules.md (activator gating).
//
// State machine:
//   Available -> Active -> (Success | Failed)
//   Success   -> Consumed
//   Failed    -> Locked (penalty wave spawns)
//   Either outcome -> back to Available ONCE if the activator has Parallel
//   Processing (Cyberware sr2a, self.acc_cw_events_retry - "attempted twice
//   per run instead of once", docs/20 sr2a-parallel-processing).
//
// GREYBOX STAGE SET (interim until elite density exists - the docs/06
// kill-stage set needs reliable Shielded-elite uptime before stage 2 is
// physically completable):
//   Stage 1 "Breach":  hold USE on the terminal until the meter fills.
//   Stage 2 "Survive": survive the trace window; any player's zombie kills
//                      purge the trace early (team-wide progress, counted
//                      via the verified zombie-death callback below).
//   Stage 3 "Confirm": return to the terminal and hold USE again in time.
// Parallel Processing's second attempt rotates the tuning (longer hold,
// longer trace, headshot-only purge kills at round 11+) so it isn't a replay.
// TODO(acc-design): restore the docs/06 kill-stage set (10 kills/40s,
// 3 Shielded/60s, 15 headshots/45s) once elite pressure pulses are validated.
// =============================================================================

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

#define ACC_HACK_ACTIVATION_COST_POINTS 500
#define ACC_HACK_REWARD_SHARDS 2
#define ACC_HACK_PENALTY_WAVE_COUNT 8
#define ACC_HACK_CHANNEL_TICK_SEC 0.1
#define ACC_HACK_SURVIVE_TICK_SEC 0.5

#namespace acc_events_hack;

function init()
{
    acc_utility::log( "events_hack init" );

    level.acc_hack_state = "available";
    level.acc_hack_attempts_used = 0;

    // Kill counting for the Survive stage. Registered ONCE here; the callback
    // no-ops unless a stage opens level.acc_hack_kill_window.
    // VERIFIED(acc): there is no level-wide "zombie_killed" notify in stock
    // (the only notify site is on the PLAYER, no args, insta-kill path only -
    // _zm_powerups.gsc:1463). The stock per-kill hook is
    // zm_spawner::register_zombie_death_event_callback (_zm_spawner.gsc:2463),
    // dispatched ON the dying zombie with the attacker as the only arg
    // (_zm_spawner.gsc:2344 -> 2449-2459, 'self [[ callback ]]( attacker )');
    // mod/hit-location live on the zombie (self.damagemod /
    // self.damagelocation, read the same way by stock at _zm_spawner.gsc:1790).
    // Same pattern as _acc_points.gsc / _acc_elites.gsc.
    zm_spawner::register_zombie_death_event_callback( &acc_hack_zombie_death_watch );

    level thread watch_terminal();
}

function watch_terminal()
{
    level endon( "end_game" );

    triggers = getentarray( "acc_hack_terminal", "targetname" );
    if ( triggers.size == 0 )
    {
        acc_utility::log( "hack: no terminal placed yet" );
        return;
    }

    for ( i = 0; i < triggers.size; i++ )
    {
        triggers[ i ] thread terminal_loop();
    }
}

// self = the acc_hack_terminal trigger_use.
function terminal_loop()
{
    self endon( "death" );

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
            player iprintln( "Hack Terminal: unavailable" );
            wait( 0.5 );
            continue;
        }

        // VERIFIED(acc): affordability via zm_score::can_player_purchase
        // (_zm_score.gsc:655 - checks self.score >= cost AND honors the
        // free-shopping GobbleGum). Replaces the old raw player.score read.
        if ( !( player zm_score::can_player_purchase( ACC_HACK_ACTIVATION_COST_POINTS ) ) )
        {
            player iprintln( "Hack Terminal: needs " + ACC_HACK_ACTIVATION_COST_POINTS + " points" );
            wait( 0.5 );
            continue;
        }

        // VERIFIED(acc): never write player.score directly - stock spends via
        // zm_score::minus_to_player_score (_zm_score.gsc:551), which also syncs
        // pers["score"], stats, the "spent_points" notify, and free-purchase
        // GobbleGum handling.
        player zm_score::minus_to_player_score( ACC_HACK_ACTIVATION_COST_POINTS );
        level.acc_hack_state = "active";
        level.acc_hack_attempts_used += 1;
        self set_hint_for_state();

        result = run_hack_sequence( player, self );

        if ( result == "success" )
        {
            acc_data_shards::grant_player( player, ACC_HACK_REWARD_SHARDS, "hack_terminal" );
            // TODO(acc-oc): grant a free Overclock roll voucher as documented
            // once the overclock voucher system exists.
            level.acc_hack_state = "consumed";
        }
        else
        {
            level.acc_hack_state = "locked";
            level thread spawn_penalty_wave();
        }

        // Parallel Processing (Cyberware sr2a): the ACTIVATOR's passive
        // re-opens the event for exactly one more attempt per run, after
        // either outcome ("attempted twice per run instead of once",
        // docs/20 sr2a-parallel-processing). A failed first attempt still
        // fires the penalty wave above.
        if ( isdefined( player ) && player_has_parallel_processing( player ) &&
             level.acc_hack_attempts_used < 2 )
        {
            level.acc_hack_state = "available";
        }

        self set_hint_for_state();
        wait( 1.0 );
    }
}

function can_attempt( player )
{
    if ( level.acc_hack_state == "locked" ) return false;
    if ( level.acc_hack_state == "consumed" ) return false;
    if ( level.acc_hack_state == "active" ) return false;
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
    if ( level.acc_hack_state == "available" )
    {
        self sethintstring( "Hold ^3&&1^7 to hack [Cost: " + ACC_HACK_ACTIVATION_COST_POINTS + "]" );
    }
    else if ( level.acc_hack_state == "active" )
    {
        self sethintstring( "Hack in progress..." );
    }
    else if ( level.acc_hack_state == "consumed" )
    {
        self sethintstring( "Terminal spent" );
    }
    else // locked
    {
        self sethintstring( "Terminal locked" );
    }
}

// ---------------------------------------------------------------------------
// Three-stage hack sequence (greybox set - see file header)
// ---------------------------------------------------------------------------

function run_hack_sequence( player, terminal )
{
    stages = build_stages( level.round_number, level.acc_hack_attempts_used );

    for ( i = 0; i < stages.size; i++ )
    {
        s = stages[ i ];
        if ( isdefined( player ) )
        {
            player iprintln( "Hack Stage " + ( i + 1 ) + "/" + stages.size + ": " + s.prompt );
        }

        ok = run_stage( player, terminal, s );
        if ( !ok )
        {
            if ( isdefined( player ) ) player iprintln( "Hack FAILED" );
            return "failed";
        }
    }

    if ( isdefined( player ) ) player iprintln( "Hack SUCCESS" );
    return "success";
}

// Stage tuning. attempt_number is 1-based (level.acc_hack_attempts_used is
// incremented before the sequence runs). Attempt 2 (Parallel Processing only)
// rotates the tuning so it is not a replay (docs/06).
function build_stages( round_number, attempt_number )
{
    stages = [];

    if ( attempt_number <= 1 )
    {
        stages[ 0 ] = make_stage( "channel", "Hold [USE] to breach the firewall", 30, 6, 0, "any" );
        stages[ 1 ] = make_stage( "survive", "Survive the trace - kills purge it faster", 45, 0, 10, "any" );
        stages[ 2 ] = make_stage( "channel", "Return to the terminal - hold [USE] to confirm", 30, 1, 0, "any" );
    }
    else
    {
        flavor = "any";
        if ( round_number >= 11 ) flavor = "headshot";

        stages[ 0 ] = make_stage( "channel", "Hold [USE] to breach the hardened firewall", 30, 8, 0, "any" );
        if ( flavor == "headshot" )
        {
            stages[ 1 ] = make_stage( "survive", "Survive the deep trace - HEADSHOT kills purge it", 60, 0, 15, flavor );
        }
        else
        {
            stages[ 1 ] = make_stage( "survive", "Survive the deep trace - kills purge it faster", 60, 0, 15, flavor );
        }
        stages[ 2 ] = make_stage( "channel", "Return to the terminal - hold [USE] to confirm", 20, 1, 0, "any" );
    }

    return stages;
}

function make_stage( type, prompt, window_sec, hold_sec, kill_target, kill_flavor )
{
    s = spawnstruct();
    s.type = type;
    s.prompt = prompt;
    s.window_sec = window_sec;
    s.hold_sec = hold_sec;
    s.kill_target = kill_target;
    s.kill_flavor = kill_flavor;
    return s;
}

function run_stage( player, terminal, s )
{
    if ( s.type == "channel" )
    {
        return run_stage_channel( player, terminal, s );
    }
    return run_stage_survive( player, s );
}

// Hold USE while standing in the terminal trigger until hold_sec accumulates;
// fail if window_sec elapses first or the activator goes down/disconnects.
function run_stage_channel( player, terminal, s )
{
    held = 0;
    elapsed = 0;
    last_announced = 0;

    while ( elapsed < s.window_sec )
    {
        wait( ACC_HACK_CHANNEL_TICK_SEC );
        elapsed += ACC_HACK_CHANNEL_TICK_SEC;

        // VERIFIED(acc): zm_utility::is_player_valid (_zm_utility.gsc:1600)
        // = defined/alive/spawned/not-laststand/not-spectator; also false for
        // an undefined (disconnected) player.
        if ( !zm_utility::is_player_valid( player ) )
        {
            return false;
        }

        // VERIFIED(acc): player IsTouching( trigger ) is the stock
        // in-the-trigger-volume test (_zm_laststand.gsc:1138);
        // UseButtonPressed is the stock hold-use poll (_zm_blockers.gsc:1889).
        if ( player istouching( terminal ) && player usebuttonpressed() )
        {
            held += ACC_HACK_CHANNEL_TICK_SEC;
            if ( held >= s.hold_sec )
            {
                return true;
            }

            whole = int( held );
            if ( whole >= 1 && whole > last_announced )
            {
                last_announced = whole;
                player iprintln( "Hack: " + whole + "/" + s.hold_sec + "s" );
            }
        }
    }

    return false;
}

// Survive window_sec; any player's qualifying zombie kills (kill_target of
// them) complete the stage early. Surviving the full window also completes it
// (greybox completability must not depend on spawn availability). Fails only
// if the activator goes down or disconnects.
function run_stage_survive( player, s )
{
    window = spawnstruct();
    window.kills = 0;
    window.flavor = s.kill_flavor;
    level.acc_hack_kill_window = window;

    elapsed = 0;
    result = true;

    while ( elapsed < s.window_sec )
    {
        wait( ACC_HACK_SURVIVE_TICK_SEC );
        elapsed += ACC_HACK_SURVIVE_TICK_SEC;

        if ( !zm_utility::is_player_valid( player ) )
        {
            result = false;
            break;
        }

        if ( s.kill_target > 0 && window.kills >= s.kill_target )
        {
            player iprintln( "Trace purged early (" + window.kills + " kills)" );
            break;
        }
    }

    level.acc_hack_kill_window = undefined;
    return result;
}

// Registered once in init(); dispatched ON the dying zombie (self) with the
// attacker as the only arg (_zm_spawner.gsc:2449-2459). No-ops unless a
// Survive stage opened the kill window. ANY player's kills count (team-wide
// stage progress; the reward stays activator-gated - docs/15_coop_rules.md).
function acc_hack_zombie_death_watch( attacker )
{
    window = level.acc_hack_kill_window;
    if ( !isdefined( window ) ) return;
    if ( !isdefined( attacker ) || !isplayer( attacker ) ) return;

    if ( window.flavor == "headshot" && !is_headshot( self.damagelocation ) )
    {
        return;
    }

    window.kills += 1;
}

function is_headshot( hit_loc )
{
    // Mirror of _acc_points.gsc::is_headshot; keep in sync.
    // VERIFIED(acc): valid hitlocs are "head"/"helmet"/"neck"
    // (_zm_utility.gsc:5261, _loadout.gsc:1418); "neck" counted by our design
    // choice (see _acc_damage.gsc note); "j_head" is a bone tag, never a hitloc.
    if ( !isdefined( hit_loc ) ) return false;
    if ( hit_loc == "head" )   return true;
    if ( hit_loc == "helmet" ) return true;
    if ( hit_loc == "neck" )   return true;
    return false;
}

// ---------------------------------------------------------------------------
// Penalty wave on failure
// ---------------------------------------------------------------------------

function spawn_penalty_wave()
{
    level endon( "end_game" );

    // GREYBOX spawn pressure - the verified-simple path: bump the stock round
    // budget instead of hand-rolling spawn_zombie calls.
    // VERIFIED(acc): round_spawning re-reads level.zombie_total every loop
    // iteration (_zm.gsc:3735) and runs for the whole round (endons only at
    // _zm.gsc:3680-3682), so a mid-round bump yields exactly that many extra
    // stock spawns; round_wait keeps the round open until they die
    // (_zm.gsc:4733). Stock itself bumps the counter mid-round
    // (zombie_utility.gsc:1861, _zm_spawner.gsc:2418). Between rounds the
    // bump is harmlessly overwritten by the next round's reset
    // (_zm.gsc:3715-3717).
    level.zombie_total += ACC_HACK_PENALTY_WAVE_COUNT;
    acc_utility::log( "hack: penalty wave (+" + ACC_HACK_PENALTY_WAVE_COUNT + " zombie budget)" );

    // TODO(acc-design): post-greybox, spawn these near the terminal with
    // forced sprint speed (zombie_utility::spawn_zombie + nearby riser struct;
    // see the validated pattern in _acc_elites.gsc::spawn_elite).
}
