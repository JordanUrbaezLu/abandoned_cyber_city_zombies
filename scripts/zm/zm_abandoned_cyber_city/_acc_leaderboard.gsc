// =============================================================================
// _acc_leaderboard.gsc - the GLOBAL LEADERBOARD (docs/40). Replaced the Stage-0
// spike 2026-07-11 (the spike's full 11-run ledger lives in docs/40; its findings
// are baked into THE WORKING RECIPE this module ships).
//
// WHAT SHIPS:
//   1. RECORDER - at end_game, ONE client (players[0]) opens the invisible LUI menu
//      "acc_lb_rec" (ui/uieditor/menus/hud/acc_lb_rec.lua, GENERATED - see below).
//      Its hksc bytecode chunk gathers the roster client-side (PlayerList.<i>
//      .playerName UI models), reads the round (gameScore.roundsPlayed, raw-1),
//      mints session id + timestamp (os.time), appends the machine-local record
//      (players/acc_lb_records.txt) and curl-POSTs the game to the Cloudflare
//      Worker (backend/leaderboard/, dedup-by-session upsert).
//      >>> USER RULE (2026-07-11): if DEV MODE or GOD MODE is on, NO record is
//      made and NOTHING is posted/stored - this function returns before the menu
//      ever opens. Assisted runs never touch the board (local file included). <<<
//   2. PLAZA STATION (user 2026-07-11: "inside plaza so players can view as soon
//      as they load into the map"; placement rule: WEST of the Implant door -
//      "the other side of the door, not on the same side as the mystery box") -
//      a network-data terminal against the Plaza south wall by spawn. Hold-USE ->
//      the "acc_lb_board" LUI menu curl-GETs
//      top10.txt in the background, lands rows in dvars acc_lb_r1..r10 (+
//      acc_lb_done "net:N"/"loc:N"), and this module renders them on the standard
//      acc_ui card. Net-fail -> the LUI falls back to the machine-local records.
//   3. DEV FETCH PROBE (acc_dev only) - 15s in, runs the fetch path ONCE, log-only
//      (NO card, NO on-screen UI - memory debug-banners-gated-by-acc-dev-only),
//      and logs gameScore.roundsPlayed-vs-level.round_number so the round offset
//      stays verified. GET-only: dev runs never post (the user rule above).
//
// BRIDGES (all proven, docs/40 "THE WORKING RECIPE" + v5a):
//   GSC -> LUI: OpenLUIMenu is the trigger; roster/round are read client-side so
//   no value channel is needed. LUI -> GSC: Engine.Exec "set acc_lb_*" dvars,
//   mirrored to console_mp.log by watch_trace_dvar (the crash-surviving channel).
//
// GENERATED LUI: ui/uieditor/menus/hud/acc_lb_rec.lua + acc_lb_board.lua are
// build artifacts of `node tools/build_lb_lui.js` (chunk sources in
// tools/lui_chunks/; backend URL + write key spliced from the gitignored
// backend/leaderboard/deployed.local.json). Edit the chunks, re-run the tool,
// sync + build. NEVER hand-edit the generated files.
//
// Kill switch: acc_lb_on 0 (live-balance style, default 1).
// Harvest a run's traces: tools/read_lb_logs.ps1 (console_mp.log [LB] lines +
// the players/acc_lb_* artifacts).
// =============================================================================

#using scripts\shared\flag_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_ui;

#precache( "lui_menu", "acc_lb_rec" );
#precache( "lui_menu", "acc_lb_board" );
#precache( "lui_menu", "acc_lb_boot" );
#precache( "model", "p7_zm_sta_dragon_network_data_terminal" );

// Plaza south wall (y=-240 plane), WEST of the Implant Lab doorway (x[-260,-180]) -
// the OPPOSITE side of that door from the acc_box_plaza mystery-box chest at
// (100,-150) (user 2026-07-11: "other side of the door, not on the same side as the
// mystery box"; the initial box spawn is ALWAYS plaza, _acc_map_randomizer). Clear of
// the west-wall corner (~x=-480), the spawn structs (x[-200,40] y[-130,-90]) and the
// plaza_cache_1 crate clip at (-320,30) - and still in view the moment you load in.
// Faces +y into the plaza (same model as the Overclock terminals; retune yaw in-game
// if the mesh forward differs).
#define ACC_LB_STATION_ORIGIN  ( -340, -210, 0 )
#define ACC_LB_STATION_YAW     90

// ZMCursorHintNew router audit (memory lui-cursorhint-router-loose-weapon-matcher):
// the box matcher hijacks ANY hint containing "hold"+"for" (plain substring!) and
// other cards key on "buy"/"cost"/"upgrade"+"weapon"/"open door to"/perk names -
// these strings avoid ALL of them, so the hint falls through to the readable
// DefaultHint card. Do not add the word "for" (even inside another word).
#define ACC_LB_HINT_IDLE  "Hold ^3[{+activate}]^7  ^5NEURAL NET RANKINGS^7 - the global top 10"
#define ACC_LB_HINT_BUSY  "^5NEURAL NET RANKINGS^7 - syncing with the net..."

#namespace acc_leaderboard;

// Called by acc_main::init.
function init()
{
    if ( getdvarint( "acc_lb_on", 1 ) != 1 )
        return;

    level.acc_lb_cooldown_until = 0;

    level thread boot_agents();
    level thread record_at_end_game();
    level thread station_setup();
    level thread dev_fetch_probe();
}

// ---------------------------------------------------------------------------
// BACKGROUND AGENT BOOT (the fullscreen tab-out fix)
// ---------------------------------------------------------------------------
// os.execute from LUI spawns a console window that yanks exclusive fullscreen
// (the reported interact/game-end tab-out). So the game execs ONCE per match at
// initial_blackscreen_passed (the PROVEN-SAFE timing + client LUI ready): the
// boot menu's createMenu SYNCHRONOUSLY writes + spawns the hidden agent
// (players\acc_lb_agent_*.bat), which then serves every curl via trigger FILES -
// the rec/board chunks never exec. Details: acc_lb_boot_chunk.lua.
//
// HARD-LEARNED (2026-07-12): keep this shape. Two attempts to hide the residual
// match-start console flash (a UITimer-polled liveness handshake; opening the menu
// early at spawned_player with a two-menu ping/pong) BOTH FROZE THE ENGINE at load
// (agent spawned fine, game locked the next frame). The safe lever for the flash
// is the LAUNCHER PRE-SPAWN (run_game.ps1), which spawns the agent windowless
// BEFORE the game and lets the launcher's own ping/pong skip a duplicate - it never
// touches the fragile in-game load path. Do NOT reintroduce an in-game handshake or
// an earlier-than-blackscreen open without a full in-game load test.

function boot_agents()
{
    level endon( "end_game" );

    // THE SILENT PATH (user 2026-07-12: "it just starts up my terminal every
    // time... do it silently"): the play scripts pre-spawn the agent WINDOWLESS
    // before the game (tools/spawn_lb_agent.ps1, PowerShell -WindowStyle Hidden)
    // and pass `+set acc_lb_agent 1` - then the in-game spawn (whose os.execute
    // console is what the user saw) is skipped entirely. Launch-time dvar, the
    // acc_dev idiom; Workshop players without a launcher fall through to the
    // in-game boot below.
    if ( getdvarint( "acc_lb_agent", 0 ) == 1 )
    {
        lb_log( "agent pre-spawned by the launcher (acc_lb_agent 1) - in-game boot skipped, no console" );
        return;
    }

    SetDvar( "acc_lb_boot_trace", "" );
    level flag::wait_till( "initial_blackscreen_passed" );

    // Every MACHINE needs its own agent (in co-op the interacting player's own
    // client runs the station fetch). One boot per level load.
    foreach ( player in GetPlayers() )
        player thread boot_one_agent();
}

// self = player. Single synchronous boot menu (createMenu writes + spawns the
// agent). NO handshake, NO UITimer, NO early open - the proven-safe shape.
function boot_one_agent()
{
    self endon( "disconnect" );

    m = self OpenLUIMenu( "acc_lb_boot" );
    wait 3;
    if ( isdefined( m ) )
        self CloseLUIMenu( m );
}

// ---------------------------------------------------------------------------
// RECORDER
// ---------------------------------------------------------------------------

// Deliberately NO endon("end_game") anywhere below this line - this chain RUNS at
// end_game (GSC keeps executing through the game-over screen / intermission).
function record_at_end_game()
{
    level waittill( "end_game" );

    // USER RULE (2026-07-11): dev mode or god mode -> no POST, no record, nothing
    // stored anywhere (DB *and* the machine-local file). The LUI menu never opens.
    if ( IS_TRUE( level.acc_dev ) || IS_TRUE( level.acc_god ) )
    {
        lb_log( "record SKIPPED - dev/god active (user rule: assisted runs never stored)" );
        return;
    }

    if ( IS_TRUE( level.acc_lb_recorded ) )   // end_game paranoia guard: one record per level
        return;
    level.acc_lb_recorded = true;

    players = GetPlayers();
    if ( players.size == 0 || !isdefined( players[ 0 ] ) )
        return;
    // players[0] = the listen-server host in practice, but ANY client works: the
    // chunk reads the same PlayerList/round models every client has (docs/40).
    recorder = players[ 0 ];

    // MARATHON GUARD: the load-time agent self-expires after ~2h. If this game
    // outlived it, boot a fresh one on the recorder BEFORE queueing the POST so
    // the trigger file has a live consumer. (Under ~100 min the load-time agent
    // still runs - no game-over-screen spawn.) The game is over, so a console
    // flash here is invisible regardless.
    if ( GetTime() > 100 * 60 * 1000 )
    {
        recorder OpenLUIMenu( "acc_lb_boot" );
        wait 2;
    }

    SetDvar( "acc_lb_rec_trace", "" );
    level thread watch_trace_dvar( "acc_lb_rec_trace", 12, false );

    lb_log( "end_game: round_number=" + level.round_number + " players=" + players.size + " - recording" );
    recorder OpenLUIMenu( "acc_lb_rec" );
    // Nothing to close: the chunk runs at menu-create (pure io - it writes the
    // record + queues the POST trigger for the background agent, docs/40); its
    // trace (r<raw>, w1, j1, q1, done) lands in the log above. The agent being a
    // detached process means the POST survives even an instant quit-to-menu.
}

// ---------------------------------------------------------------------------
// PLAZA STATION
// ---------------------------------------------------------------------------

function station_setup()
{
    level endon( "end_game" );

    m = spawn( "script_model", ACC_LB_STATION_ORIGIN );
    m setmodel( "p7_zm_sta_dragon_network_data_terminal" );
    m.angles = ( 0, ACC_LB_STATION_YAW, 0 );

    // The proven script-spawned station recipe (_acc_overclocks::spawn_terminal_at):
    // raised trigger origin gives the use-cursor something to land on;
    // TriggerIgnoreTeam is REQUIRED or the trigger is never usable (stock _zm_perks:1523).
    t = spawn( "trigger_radius_use", ACC_LB_STATION_ORIGIN + ( 0, 0, 40 ), 0, 64, 80 );
    t TriggerIgnoreTeam();
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( ACC_LB_HINT_IDLE );

    level.acc_lb_trig = t;
    acc_utility::log( "leaderboard: Plaza station spawned at " + ACC_LB_STATION_ORIGIN );

    for ( ;; )
    {
        t waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) )
            continue;

        // debounce: one fetch at a time; the card itself lives ~14s
        if ( GetTime() < level.acc_lb_cooldown_until )
            continue;
        level.acc_lb_cooldown_until = GetTime() + 8000;

        player thread show_board( t );
    }
}

// self = the interacting player. Opens the invisible fetch menu, waits for the
// LUI to land rows in the dvars, renders the acc_ui card, cleans up.
function show_board( t )
{
    self endon( "disconnect" );
    level endon( "end_game" );

    clear_board_dvars();
    if ( IS_TRUE( level.acc_dev ) )
        level thread watch_trace_dvar( "acc_lb_board_trace", 10, true );

    if ( isdefined( t ) )
        t SetHintString( ACC_LB_HINT_BUSY );

    m = self OpenLUIMenu( "acc_lb_board" );

    // the LUI always terminates: done lands by ~8s (agent poll + curl) or the
    // local fallback fills in
    done = "";
    end_ms = GetTime() + 10000;
    while ( GetTime() < end_ms )
    {
        done = GetDvarString( "acc_lb_done", "" );
        if ( done != "" )
            break;
        wait 0.1;
    }

    // hint back to idle the moment the fetch resolves - the card IS the feedback
    // (user 2026-07-11 UI pass: "SYNCING..." must not linger under the card)
    if ( isdefined( t ) )
        t SetHintString( ACC_LB_HINT_IDLE );

    lines = board_lines();

    src = "";
    if ( done == "" )
        src = " ^1(no link)";
    else if ( IsSubStr( done, "loc" ) )
        src = " ^3(offline)";

    if ( lines.size == 0 )
    {
        lines[ 0 ] = "^7No runs on the record yet.";
        lines[ 1 ] = "^5- ^7Finish a match to claim a slot.";
    }

    self acc_ui::card_show( "NEURAL NET RANKINGS" + src, ( 0.4, 0.9, 1.0 ), undefined, lines );

    wait 12;

    self acc_ui::card_hide();
    if ( isdefined( m ) )
        self CloseLUIMenu( m );
}

// dvar rows ("round|name1,name2,...") -> pre-formatted card lines
function board_lines()
{
    lines = [];
    for ( i = 1; i <= 10; i++ )
    {
        v = GetDvarString( "acc_lb_r" + i, "" );
        if ( v == "" )
            continue;

        parts = StrTok( v, "|" );
        if ( parts.size < 1 )
            continue;
        round_s = parts[ 0 ];
        names_s = ( ( parts.size > 1 ) ? parts[ 1 ] : "?" );
        if ( names_s.size > 30 )   // keep rows inside the 300px card
            names_s = GetSubStr( names_s, 0, 30 );

        // "1.  Round 4   Glide Gladiator" (user 2026-07-11 UI pass: spell out
        // "Round {number}"; rank teal, round gold, names white)
        rank = lines.size + 1;
        lines[ lines.size ] = "^5" + rank + ".^7  Round ^3" + round_s + "^7   " + names_s;
    }
    return lines;
}

function clear_board_dvars()
{
    SetDvar( "acc_lb_done", "" );
    SetDvar( "acc_lb_board_trace", "" );
    SetDvar( "acc_lb_round_raw", "" );
    for ( i = 1; i <= 10; i++ )
        SetDvar( "acc_lb_r" + i, "" );
}

// ---------------------------------------------------------------------------
// DEV FETCH PROBE (acc_dev only; GET-only, log-only - no card, no POST)
// ---------------------------------------------------------------------------

function dev_fetch_probe()
{
    level endon( "end_game" );

    if ( !IS_TRUE( level.acc_dev ) )
        return;

    level flag::wait_till( "initial_blackscreen_passed" );
    wait 15;

    players = GetPlayers();
    if ( players.size == 0 || !isdefined( players[ 0 ] ) )
        return;
    p = players[ 0 ];

    clear_board_dvars();
    level thread watch_trace_dvar( "acc_lb_board_trace", 12, true );

    lb_log( "DEV PROBE: fetch-only pass (dev never records/POSTs). round_number=" + level.round_number );
    m = p OpenLUIMenu( "acc_lb_board" );

    done = "";
    end_ms = GetTime() + 9000;
    while ( GetTime() < end_ms )
    {
        done = GetDvarString( "acc_lb_done", "" );
        if ( done != "" )
            break;
        wait 0.1;
    }

    // the round-offset oracle: chunk snapshots gameScore.roundsPlayed on "go";
    // rec posts raw-1, so raw should read round_number+1 here.
    lb_log( "DEV PROBE: done='" + done + "' round_raw='" + GetDvarString( "acc_lb_round_raw", "" )
            + "' vs round_number=" + level.round_number );

    rows = board_lines();
    for ( i = 0; i < rows.size; i++ )
        lb_log( "DEV PROBE row " + rows[ i ] );

    if ( isdefined( m ) )
        p CloseLUIMenu( m );
    lb_log( "DEV PROBE COMPLETE (" + rows.size + " rows)" );
}

// ---------------------------------------------------------------------------
// SHARED PLUMBING
// ---------------------------------------------------------------------------

// Mirror one line to the durable oracles: IPrintLnBold -> console_mp.log
// "[ SCRIPTER]" lines (docs/17), acc_utility::log -> dev-block println.
function lb_log( line )
{
    IPrintLnBold( "^5[LB]^7 " + line );
    acc_utility::log( "lb: " + line );
}

// Poll a LUI-written breadcrumb dvar, mirror every CHANGE into the log (the v5a
// Exec->dvar bridge, generalized from the spike's watcher). end_game_safe=false
// keeps it alive through end_game (the recorder path).
function watch_trace_dvar( name, seconds, end_game_safe )
{
    if ( IS_TRUE( end_game_safe ) )
        level endon( "end_game" );

    last = "";
    end_ms = GetTime() + seconds * 1000;
    while ( GetTime() < end_ms )
    {
        v = GetDvarString( name, "" );
        if ( v != "" && v != last )
        {
            lb_log( "[" + name + "] " + v );
            last = v;
        }
        wait 0.05;
    }
}
