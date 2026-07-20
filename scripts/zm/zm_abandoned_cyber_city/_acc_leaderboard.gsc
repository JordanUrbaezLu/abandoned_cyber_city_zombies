// =============================================================================
// _acc_leaderboard.gsc - the GLOBAL LEADERBOARD (docs/40). Replaced the Stage-0
// spike 2026-07-11 (the spike's full 11-run ledger lives in docs/40; its findings
// are baked into THE WORKING RECIPE this module ships).
//
// WHAT SHIPS:
//   1. RECORDER - at end_game (AND at a Paradise win, 2026-07-17 - same session, Worker
//      upserts), the HOST client (pick_recorder - never a peer) opens the invisible LUI menu
//      "acc_lb_rec" (ui/uieditor/menus/hud/acc_lb_rec.lua, GENERATED - see below).
//      Its hksc bytecode chunk gathers the roster client-side (PlayerList.<i>
//      .playerName UI models), reads the round (gameScore.roundsPlayed, raw-1),
//      mints session id + timestamp (os.time), appends the machine-local record
//      (players/acc_lb_records.txt) and curl-POSTs the game to the Cloudflare
//      Worker (backend/leaderboard/, dedup-by-session upsert).
//      >>> USER RULE (2026-07-11): if DEV MODE or GOD MODE is on, NO record is
//      made and NOTHING is posted/stored - this function returns before the menu
//      ever opens. Assisted runs never touch the board (local file included). <<<
//   2. PLAZA STATION - the "LEADERBOARDS" terminal (user 2026-07-12: renamed from
//      "Neural Net Rankings" - "its just the map Leaderboards"). Placed WEST of the
//      Implant door ("the other side of the door, not on the same side as the
//      mystery box", user 2026-07-11). Hold-USE -> the "acc_lb_board" LUI menu
//      curl-GETs top10.txt?v2=N in the background and RENDERS THE BOARD ITSELF
//      (board UI 2026-07-15): a centered LUI panel with per-game rank/ROUND rows +
//      nested per-player KILLS/REVIVES/DOWNS columns (the player_stats data,
//      docs/40). The chunk still lands legacy rows in dvars acc_lb_r1..r10 (+
//      acc_lb_done "net:N"/"loc:N") and reports the render on acc_lb_lui ("ok:N") -
//      no "ok" on a working bridge -> GSC falls back to the old acc_ui card, so the
//      station can never show nothing. Net-fail -> the LUI falls back to the
//      machine-local records (which now carry stats too). ONE FETCH PER SESSION per
//      lobby size (user 2026-07-12): the result file on disk is the cache
//      (acc_lb_use_cache 1 -> the chunk skips the curl; GSC keys it via
//      level.acc_lb_have_cache/_cache_pc).
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
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_usage;   // serialize() the gun blob for the POST (docs/41)
#using scripts\zm\zm_abandoned_cyber_city\_acc_interact_glow;  // cyan "usable" holo on the plaza board terminal

#precache( "lui_menu", "acc_lb_rec" );
#precache( "lui_menu", "acc_lb_board" );
#precache( "lui_menu", "acc_lb_boot" );
#precache( "model", "p7_zm_sta_dragon_network_data_terminal" );

// CO-OP PEER RELAY models (2026-07-16, user: "non host players cant see the UI for the
// Leaderboards"): every board data lane is HOST-MACHINE-ONLY - the curl agent is host-only
// (boot_agents), the records file lives on the recording machine, and a server SetDvar
// never replicates to a remote client - so a peer's menu shell had NOTHING to render.
// These per-player controller UI models (SetControllerUIModelValue - the docs/16 Wonderfizz
// bridge / docs/19 M2, the ONLY replicated GSC->LUI string channel we have) carry the
// HOST's last-fetched rows to the peer: accLbR<i> = "round|names|stats" (the same v2 row
// text the chunk's parse_rows eats), accLbTot = "games|wins", accLbSrc = "net"/"loc".
#precache( "lui_menu_data", "accLbR1" );
#precache( "lui_menu_data", "accLbR2" );
#precache( "lui_menu_data", "accLbR3" );
#precache( "lui_menu_data", "accLbR4" );
#precache( "lui_menu_data", "accLbR5" );
#precache( "lui_menu_data", "accLbR6" );
#precache( "lui_menu_data", "accLbR7" );
#precache( "lui_menu_data", "accLbR8" );
#precache( "lui_menu_data", "accLbR9" );
#precache( "lui_menu_data", "accLbR10" );
#precache( "lui_menu_data", "accLbTot" );
#precache( "lui_menu_data", "accLbSrc" );
// LEAVE-FLUSH hook arm (2026-07-18): "1" on the HOST machine only = the pause menu's
// Leave Game / Restart Level must ask GSC to record before exiting (leave_flush_watch).
#precache( "lui_menu_data", "accLbLeaveHook" );

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
// NOTE the phrasing: NO "for" (see the router audit above - "hold"+"for" is
// hijacked into a blank weapon card). "Fetch the top 10 map leaderboards" reads
// the way the user asked without tripping it.
#define ACC_LB_HINT_IDLE  "Hold ^3[{+activate}]^7  Fetch the top 10 map leaderboards"
#define ACC_LB_HINT_BUSY  "^5LEADERBOARDS^7 - loading top 10..."

#namespace acc_leaderboard;

// Called by acc_main::init.
function init()
{
    if ( getdvarint( "acc_lb_on", 1 ) != 1 )
        return;

    level.acc_lb_cooldown_until = 0;
    level.acc_lb_lane_until = 0;   // board-lane lease (see lane_take below clear_board_dvars)

    // Stale-leak guard (mirrors acc_weapon_usage::init clearing acc_lb_guns): the per-player
    // stats transport dvar starts empty every load so a prior game's blob can't bleed into the
    // next POST. publish_and_open_rec republishes it fresh right before OpenLUIMenu.
    SetDvar( "acc_lb_stats", "" );
    // Per-MATCH session id (2026-07-17): the rec chunk mints it on the first record and parks
    // it here so a second record (Paradise win-time + the final end_game) upserts the SAME
    // Worker row. Cleared every load so a new match can never reuse the last one.
    SetDvar( "acc_lb_session", "" );
    // Pause-menu leave-flush handshake (2026-07-18): stale-proof both ends every load so a
    // prior game's leftover req/ack can neither insta-record nor insta-release a new leave.
    SetDvar( "acc_lb_leave_req", "" );
    SetDvar( "acc_lb_leave_ack", "" );

    level thread boot_agents();
    level thread leave_flush_watch();
    level thread record_at_end_game();
    level thread record_on_paradise_win();
    level thread record_every_round();
    level thread station_setup();
    level thread dev_fetch_probe();
}

// ---------------------------------------------------------------------------
// OPT-IN CONSENT + BACKGROUND AGENT BOOT (the fullscreen tab-out fix, v2)
// ---------------------------------------------------------------------------
// os.execute from LUI spawns a console window that yanks exclusive fullscreen (the
// reported "it tabs us out / looks like the map is hacking me"). v1 hid the agent but
// still exec'd at EVERY match start for EVERY player. v2 (user 2026-07-13) makes it
// OPT-IN and default OFF:
//   * A player who never opts in spawns NOTHING - no console, no tab-out, ever.
//   * The one-time prompt (prompt_consent) appears at spawn-in ONLY for an undecided
//     player whose Exec<->dvar bridge round-trips (solo / co-op host). Hold [Melee] to
//     enable; ignore it to stay off (the safe default). The choice persists in the LUI
//     file players\acc_lb_consent.txt, so it is asked exactly once.
//   * Even an opted-in player no longer spawns at blackscreen: "check" mode only REPORTS
//     the saved choice; the agent is spawned at END_GAME (record_at_end_game, "spawn"
//     mode) where a console flash is invisible on the game-over screen. The only in-play
//     os.execute is the instant a player deliberately holds [Melee] to enable ("set1").
//
// HARD-LEARNED (2026-07-12): all boot io/os stays SYNCHRONOUS in createMenu. NEVER a
// UITimer-driven spawn (two clean loads FROZE THE ENGINE). The launcher pre-spawn
// (run_game.ps1 + acc_lb_agent 1) still skips this whole path for the dev box. Do NOT add
// an in-game ping/pong handshake at blackscreen without a full in-game load test.

// AUTO OPT-IN (user 2026-07-14): the per-player consent PROMPT is gone. Every game auto-enrolls the HOST
// so data ALWAYS posts (the prior consent_flow/prompt_consent path left level.acc_lb_consent UNSET on the
// launcher `acc_lb_agent 1` path -> record_at_end_game's opt-out gate silently skipped the POST, which is
// why real host games stopped sending data). Only the HOST spawns the background agent (the single console
// "tab-out"), matching the prior host-only architecture; co-op peers stay passive and the host's record
// covers the shared game. The board is auto-fetched once at match start (auto_fetch_board) + a 20s pre-game
// zombie-spawn buffer (zombie_spawn_grace) so any player can read the board immediately. consent_flow /
// prompt_consent / dev_prompt_test below are SUPERSEDED (no longer called) - kept for reference/history.
// NOTE dev/god still never POST (record_at_end_game gate) - that user rule is unchanged.
function boot_agents()
{
    level endon( "end_game" );

    SetDvar( "acc_lb_boot_trace", "" );

    level flag::wait_till( "initial_blackscreen_passed" );

    host = pick_recorder();
    if ( !isdefined( host ) )
        return;

    // Auto opt-in the host: EVERY game records now (dev/god still gated out downstream).
    level.acc_lb_consent = true;

    // LEAVE-FLUSH ARM (user 2026-07-18 "override the leave button ... send data first",
    // "should only have to override for the host"): tell the pause menu on the HOST's
    // machine (the recorder - the only machine whose quit kills the whole session AND the
    // only one with the record/agent lanes) that Leave Game / Restart Level must flush the
    // record first. AetheriumStartMenu.lua reads the accLbLeaveHook controller model -
    // per-player + fresh each match, so a peer or a new lobby can never see a stale arm
    // (the reason this is NOT a dvar). Every player is explicitly written "0" first; only
    // the host arms, and never on a DEV run (user 2026-07-20, supersedes the 07-11 dev/god rule:
    // "DB should only be behind dev mode" - god-mode runs DO store now; leave_flush_record
    // re-checks the same gate server-side anyway).
    foreach ( p in GetPlayers() )
        p SetControllerUIModelValue( "accLbLeaveHook", "0" );
    if ( !IS_TRUE( level.acc_dev ) )
        host SetControllerUIModelValue( "accLbLeaveHook", "1" );

    // 20s pre-game buffer + auto-fetch so any player can read the board right away.
    level.acc_lb_decided = true;          // no decision to wait for -> straight to the 20s spawn buffer
    level thread zombie_spawn_grace();

    // The agent MUST be alive early now (the auto-fetch curls through it). Launcher path pre-spawned it
    // WINDOWLESS (tools/spawn_lb_agent.ps1 + `acc_lb_agent 1`) - no in-game console. Otherwise spawn it
    // for the HOST here (the one accepted tab-out); the game-time flash is the host-only cost.
    if ( getdvarint( "acc_lb_agent", 0 ) == 1 )
    {
        lb_log( "agent pre-spawned by the launcher (acc_lb_agent 1) - auto opt-in, host records" );
        level.acc_lb_agent_up = true;
    }
    else
    {
        // SUBSCRIBER LANE (2026-07-17 outage fix, memory lb-pipeline-outage-2026-07-16-republish):
        // the old code fired ONE "spawn" open on the exact initial_blackscreen_passed frame and
        // ASSUMED success. Post-mortem of the lost 2026-07-16 Paradise quad: that open silently did
        // nothing (no agent .bat ever written) while the board menu 3s later ran fine - a menu open
        // that early can't be trusted (dvar bridge / engine context not ready). Settle first, then
        // boot_agent_verified() CONFIRMS the spawn via the chunk's acc_lb_boot_trace Exec and
        // retries; only a CONFIRMED spawn sets level.acc_lb_agent_up, so record paths retry later.
        wait 2;   // engine/LUI settle after blackscreen - the prime suspect in the outage
        level.acc_lb_agent_up = host boot_agent_verified();
    }

    host thread auto_fetch_board();
}

// The player whose MACHINE runs the record/post/agent lanes. This MUST be the listen-server
// HOST: the rec/boot menus do their file io + agent hand-off on whatever client they open on,
// and only the host's machine has the agent, the records file and the Exec->dvar bridge. The
// old players[0] pick merely ASSUMED the host sits at index 0 - in co-op a peer there strands
// the record on a machine that can never POST it (the 2026-07-17 lost-quad suspect #2).
// IsHost() scan with players[0] fallback; never an entity==undefined compare (memory
// gsc-t7-runtime-traps).
function pick_recorder()
{
    players = GetPlayers();
    if ( players.size == 0 || !isdefined( players[ 0 ] ) )
        return undefined;
    foreach ( p in players )
    {
        if ( isdefined( p ) && isplayer( p ) && ( p IsHost() ) )
            return p;
    }
    return players[ 0 ];
}

// self = the host. Spawn the background curl agent via the acc_lb_boot chunk and CONFIRM it
// actually happened: the chunk Execs acc_lb_boot_trace "spawn1" (agent launched) / "spawn0"
// (bat write or wscript failed) / "check_*" (the chunk never SAW mode=spawn - the mode dvar
// read came up empty, the 2026-07-16 outage signature). Empty trace = the chunk never ran at
// all. Up to 3 attempts with a settle wait between them; true only on a CONFIRMED "spawn1".
function boot_agent_verified()
{
    for ( attempt = 1; attempt <= 3; attempt++ )
    {
        SetDvar( "acc_lb_boot_trace", "" );
        SetDvar( "acc_lb_boot_cmd", "spawn" );
        wait 0.2;   // let the mode dvar land client-side before the chunk's createMenu reads it

        m = self OpenLUIMenu( "acc_lb_boot" );

        tr = "";
        end_ms = GetTime() + 3000;
        while ( GetTime() < end_ms )
        {
            tr = GetDvarString( "acc_lb_boot_trace", "" );
            if ( tr != "" )
                break;
            wait 0.1;
        }
        if ( isdefined( m ) )
            self CloseLUIMenu( m );

        lb_log( "agent spawn attempt " + attempt + "/3: trace='" + tr + "'" );
        if ( IsSubStr( tr, "spawn1" ) )
            return true;

        wait 2;   // settle before the retry (empty/check trace = menu or bridge not ready yet)
    }
    lb_log( "agent spawn NOT confirmed after 3 attempts - fetches offline; record paths will retry" );
    return false;
}

// self = the HOST. Fetch the top-10 board ONCE at match start and cache it on the level, so the FIRST
// player to use the Plaza terminal renders instantly instead of waiting on a live curl (user 2026-07-14:
// "auto fetch the leaderboards once host is in match"). Mirrors show_board's fetch+cache but with NO card
// (acc_lb_board's createMenu is pure fetch io; the visible card is render_board_card, which we skip). The
// 20s spawn buffer covers the agent-poll + curl round-trip, so the board is usually cached before round 1.
function auto_fetch_board()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    wait 1;   // agent already CONFIRMED by boot_agents before this threads (2026-07-17) - brief settle only

    // BOARD LANE LEASE: a player already at the Plaza station owns the channel - their
    // visible fetch fills the same cache this pre-warm would, so just bow out.
    if ( lane_busy() )
    {
        lb_log( "auto-fetch board: skipped - a visible board session owns the channel" );
        return;
    }
    lane_take( 14000 );   // 12s done-wait + settle, self-expiring

    pc = acc_lb_player_count();
    SetDvar( "acc_lb_players", "" + pc );
    clear_board_dvars();
    SetDvar( "acc_lb_board_show", "0" );   // SILENT fetch: the menu shell must not render the panel
    SetDvar( "acc_lb_use_cache", "0" );
    wait 0.1;   // let the dvars land client-side before the chunk's createMenu reads them (de-race, 2026-07-17)

    m = self OpenLUIMenu( "acc_lb_board" );

    done = "";
    end_ms = GetTime() + 12000;
    while ( GetTime() < end_ms )
    {
        done = GetDvarString( "acc_lb_done", "" );
        if ( done != "" )
            break;
        wait 0.1;
    }

    lines = board_lines();

    // Cache ONLY a real network result (done starts "net:") - an offline/empty fallback is not frozen
    // in, so the Plaza terminal retries the network once it's reachable (same rule as show_board).
    // The cached PAYLOAD is the result FILE on disk (board UI 2026-07-15) - GSC only keys it.
    if ( IsSubStr( done, "net" ) )
    {
        level.acc_lb_have_cache = true;
        level.acc_lb_cache_pc = pc;
    }

    if ( isdefined( m ) ) self CloseLUIMenu( m );
    lane_free();
    lb_log( "auto-fetch board: done='" + done + "' pc=" + pc + " lines=" + lines.size + ( IsSubStr( done, "net" ) ? " (cached)" : " (not cached)" ) );
}

// self = the HOST player. Resolve leaderboard consent (prompt ONCE if undecided, DEFAULT ON), persist it,
// set level.acc_lb_consent, and spawn the agent on a FRESH Enable (the one-time flash the player accepted).
// A RETURNING enabled player does NOT spawn here - the agent comes up invisibly at end_game
// (record_at_end_game), so there is zero gameplay-time console for them.
function consent_flow()
{
    self endon( "disconnect" );

    // "check": the chunk reads players\acc_lb_consent.txt -> reports it on acc_lb_consent (Exec->dvar).
    SetDvar( "acc_lb_consent", "" );
    SetDvar( "acc_lb_boot_cmd", "check" );
    m = self OpenLUIMenu( "acc_lb_boot" );
    c = "";
    end_ms = GetTime() + 2000;
    while ( GetTime() < end_ms )
    {
        c = GetDvarString( "acc_lb_consent", "" );
        if ( c != "" )
            break;
        wait 0.05;
    }
    if ( isdefined( m ) ) self CloseLUIMenu( m );

    if ( c == "1" )
    {
        level.acc_lb_consent = true;    // opted in previously -> agent spawns invisibly at end_game
        return;
    }
    if ( c == "0" )
    {
        level.acc_lb_consent = false;   // disabled previously -> nothing runs, ever
        return;
    }

    // undecided ("none", or "" if the bridge hiccuped) -> the one-time prompt, DEFAULT ON, with the
    // zombie-spawn grace + 10s pre-game buffer.
    level.acc_lb_decided = false;
    level thread zombie_spawn_grace();
    enabled = self prompt_consent();
    level.acc_lb_decided = true;

    if ( enabled )
    {
        // write consent=1 AND spawn the agent NOW (the one-time flash they just accepted) so the board
        // works this session; mark it up so end_game doesn't double-spawn.
        SetDvar( "acc_lb_boot_cmd", "set1" );
        level.acc_lb_agent_up = true;
    }
    else
    {
        SetDvar( "acc_lb_boot_cmd", "set0" );   // write consent=0, spawn nothing
    }
    m = self OpenLUIMenu( "acc_lb_boot" );
    wait 1;
    if ( isdefined( m ) ) self CloseLUIMenu( m );

    level.acc_lb_consent = enabled;
    lb_log( "consent resolved: " + ( enabled ? "ENABLED" : "DISABLED" ) );
}

// self = player. DEV-ONLY prompt test (user 2026-07-13): show the opt-in card every dev launch so the
// new UI is visible/iterable. Not persisted, not gated on the saved file. Zombie spawning is PAUSED for
// a ~12s grace while the player reads + chooses. On-screen result via IPrintLnBold so you see it even
// if the lb_log debug channel were off (lb_log rides level.acc_dev; the acc_lb_debug dvar was removed
// 2026-07-16).
function dev_prompt_test()
{
    self endon( "disconnect" );

    level.acc_lb_decided = false;
    level thread zombie_spawn_grace();        // hold spawns until the decision, then a 10s pre-game buffer

    enabled = self prompt_consent();          // up to 30s; ENABLED by default; only a [Aim] hold disables

    level.acc_lb_decided = true;              // decision made -> the 10s pre-game countdown begins

    // ENABLE -> spawn the hidden helper now so the ONE-TIME console flash (the "tab out") shows on THIS
    // player's screen and the Plaza terminal can fetch the board (demonstrates the real per-player
    // outcome: enable = you get the helper + the leaderboards). DISABLE -> spawn NOTHING: no helper, no
    // flash, no tab-out, ever. (Dev never POSTs regardless - record_at_end_game.) The launcher also
    // pre-spawned a SILENT agent, so a declined dev run still fetches; on a real subscriber build there is
    // no pre-spawn, so decline = fully offline.
    if ( enabled )
    {
        SetDvar( "acc_lb_boot_cmd", "spawn" );
        m = self OpenLUIMenu( "acc_lb_boot" );
        wait 3;
        if ( isdefined( m ) ) self CloseLUIMenu( m );
    }

    lb_log( "DEV prompt: " + ( enabled ? "ENABLED (helper spawned)" : "DISABLED (nothing runs)" ) );
    if ( IS_TRUE( level.acc_dev ) )   // dev-only readout (this fn is already superseded/dead; gate keeps it ship-safe if ever re-armed)
        IPrintLnBold( "^5[LB]^7 online leaderboard: " + ( enabled ? "^2ENABLED" : "^1DISABLED" ) + " ^7(dev test - not stored)" );
}

// Hold zombie spawning OFF for a pre-game buffer (20s, user 2026-07-14), THEN resume. With auto opt-in
// there is no consent decision to wait for (boot_agents sets level.acc_lb_decided=true), so the decision
// loop below breaks immediately and only the 20s buffer runs - covering the auto-fetch and giving players
// time to read the board before round 1. "spawn_zombies" is the stock spawn gate (_zm.gsc:3753; Paradise
// uses the same lever). RE-CLEARED each tick because the round-1 system SETS it a beat after blackscreen
// (a one-shot clear would leak a wave). LEVEL thread + endon("end_game") only, so a mid-prompt disconnect
// can never strand spawns paused. The 35s decision cap is a safety net (prompt_consent self-times at 30s).
function zombie_spawn_grace()
{
    level endon( "end_game" );

    if ( !level flag::exists( "spawn_zombies" ) )
        return;   // flag not up yet (shouldn't happen post-blackscreen) - skip, never risk a hang

    cap = GetTime() + 35000;
    while ( GetTime() < cap )
    {
        level flag::clear( "spawn_zombies" );
        if ( IS_TRUE( level.acc_lb_decided ) )
            break;
        wait 0.1;
    }

    buffer = GetTime() + 20000;   // 20s pre-game buffer (user 2026-07-14) - covers the auto-fetch + lets players read the board before round 1
    while ( GetTime() < buffer )
    {
        level flag::clear( "spawn_zombies" );
        wait 0.1;
    }

    level flag::set( "spawn_zombies" );
}

// self = player. The one-time consent card, TWO explicit choices (user 2026-07-13): HOLD [Melee] =
// Enable (Recommended), HOLD [Aim] = Disable. ENABLED BY DEFAULT (user 2026-07-13): doing nothing / the
// timeout keeps it ON - only a deliberate [Aim] hold turns it off. Both are non-[Use] so neither can trip
// a wallbuy. Returns true unless the player explicitly Disabled. The caller pauses zombie spawns around
// this (zombie_spawn_grace).
function prompt_consent()
{
    self endon( "disconnect" );

    wait 0.5;   // brief settle before the card appears

    title = "^5ONLINE LEADERBOARD";
    base = [];
    base[ base.size ] = "^7Post your best round to the global";
    base[ base.size ] = "^7board (top 10 at the Plaza terminal).";
    base[ base.size ] = "^2ON by default.^7  Disable = stay fully";
    base[ base.size ] = "^7offline (no helper, no interruption).";
    base[ base.size ] = "";
    base[ base.size ] = "^2Hold [{+melee}]^7  Enable  ^2(Recommended)";
    base[ base.size ] = "^1Hold [Aim]^7  Disable";
    self acc_ui::card_show( title, ( 0.4, 0.9, 1.0 ), "", base );

    tick = 0.05;
    need = 1.0;          // ~1s continuous hold for either choice
    en = 0;
    dis = 0;
    deadline = GetTime() + 30000;   // stays up to 30s (user 2026-07-13); timeout -> ENABLED by default
    choice = "none";     // "enable" / "disable" / "none" (timeout -> ENABLED by default)
    shown = "base";

    while ( GetTime() < deadline )
    {
        if ( self MeleeButtonPressed() )
        {
            en += tick;
            dis = 0;
            if ( en >= need ) { choice = "enable"; break; }
        }
        else if ( self AdsButtonPressed() )
        {
            dis += tick;
            en = 0;
            if ( dis >= need ) { choice = "disable"; break; }
        }
        else
        {
            en  = ( en  > tick ? en  - tick : 0 );   // decay (tolerate a 1-frame hiccup; a real release drains it)
            dis = ( dis > tick ? dis - tick : 0 );
        }

        want = "base";
        if ( en >= 0.15 ) want = "enabling";
        else if ( dis >= 0.15 ) want = "disabling";
        if ( want != shown )
        {
            shown = want;
            if ( want == "enabling" )
            {
                hl = [];
                hl[ hl.size ] = "^2Enabling the online leaderboard...";
                hl[ hl.size ] = "";
                hl[ hl.size ] = "^2Keep holding [{+melee}]";
                self acc_ui::card_show( title, ( 0.3, 1.0, 0.4 ), "", hl );
            }
            else if ( want == "disabling" )
            {
                hl = [];
                hl[ hl.size ] = "^1Disabling the online leaderboard...";
                hl[ hl.size ] = "";
                hl[ hl.size ] = "^1Keep holding [Aim]";
                self acc_ui::card_show( title, ( 1.0, 0.5, 0.4 ), "", hl );
            }
            else
            {
                self acc_ui::card_show( title, ( 0.4, 0.9, 1.0 ), "", base );
            }
        }

        wait tick;
    }

    if ( choice != "disable" )   // explicit Enable OR the default (timeout) -> ON
    {
        cl = [];
        cl[ cl.size ] = ( choice == "enable" ? "^2Online leaderboard ENABLED." : "^2Online leaderboard ON ^7(default)^2." );
        cl[ cl.size ] = "^7Your score submits; view it at the Plaza.";
        self acc_ui::card_show( "^2ONLINE LEADERBOARD", ( 0.3, 1.0, 0.4 ), "", cl );
        wait 1.5;
    }
    else
    {
        cl = [];
        cl[ cl.size ] = "^1Online leaderboard DISABLED.";
        cl[ cl.size ] = "^7Nothing runs - fully offline for you.";
        self acc_ui::card_show( "^7ONLINE LEADERBOARD", ( 0.7, 0.7, 0.7 ), "", cl );
        wait 1.5;
    }
    self acc_ui::card_hide();
    return ( choice != "disable" );
}

// ---------------------------------------------------------------------------
// RECORDER
// ---------------------------------------------------------------------------

// Deliberately NO endon("end_game") anywhere below this line - this chain RUNS at
// end_game (GSC keeps executing through the game-over screen / intermission).
function record_at_end_game()
{
    level waittill( "end_game" );

    // USER RULE (2026-07-20, supersedes 07-11): only DEV mode blocks storage - "DB should only
    // be behind dev mode". God-mode runs post like normal play (user accepts god-run records).
    if ( IS_TRUE( level.acc_dev ) )
    {
        lb_log( "record SKIPPED - dev active (user rule 2026-07-20: dev runs never stored)" );
        return;
    }

    // OPT-OUT GATE (user 2026-07-13, LIVE): the leaderboard is ON by default; a player who explicitly
    // DISABLED it stores NOTHING - no POST, no local record file, no data leaves the machine.
    // level.acc_lb_consent is set by consent_flow at spawn-in (default ON). Only the host's choice is read
    // here (the host is the recorder); a co-op peer's individual opt-out isn't separately honored in v1,
    // but the host's record - when the host is enabled - covers the shared game.
    if ( !IS_TRUE( level.acc_lb_consent ) )
    {
        lb_log( "record SKIPPED - online leaderboard DISABLED by the host" );
        return;
    }

    if ( IS_TRUE( level.acc_lb_recorded ) )   // end_game paranoia guard: one record per level
        return;
    level.acc_lb_recorded = true;

    // The recorder MUST be the HOST (pick_recorder, 2026-07-17): the rec chunk writes the
    // record + the POST trigger on the machine the menu opens on, and only the host has the
    // agent. The old players[0] pick could land on a co-op PEER and strand the record there.
    recorder = pick_recorder();
    if ( !isdefined( recorder ) )
        return;

    // ENSURE A LIVE AGENT for the POST: the subscriber spawn at blackscreen may not have
    // confirmed (level.acc_lb_agent_up false), and a marathon run (>100 min) may have outlived
    // the agent. Verified spawn with retries; the record below proceeds REGARDLESS - worst case
    // the local record + queued POST wait on disk and the next live agent sends the queue (the
    // boot chunk no longer clears acc_lb_do_post.txt; the Worker upserts by session, so a late
    // re-send is safe). The game is over, so any console flash is invisible on the scoreboard.
    if ( !IS_TRUE( level.acc_lb_agent_up ) || GetTime() > 100 * 60 * 1000 )
    {
        level.acc_lb_agent_up = recorder boot_agent_verified();
    }

    lb_log( "end_game: round_number=" + level.round_number + " players=" + GetPlayers().size + " - recording" );
    publish_and_open_rec( recorder );
}

// Publish every record payload on host-local dvars, then open the rec chunk on the recorder.
// Shared by record_at_end_game and record_on_paradise_win (2026-07-17) - both posts carry the
// SAME session id (the rec chunk mints it once and parks it on acc_lb_session; init clears it),
// so the Worker's dedup-by-session upsert lands them as ONE game with the highest round.
// Callers gate dev/god/consent BEFORE calling - this function stores unconditionally.
function publish_and_open_rec( recorder )
{
    // RECORD-LANE SERIALIZATION (per-round records 2026-07-18): FOUR lanes call this now
    // (end_game, Paradise win, leave flush, every-round) and two interleaved publishes
    // would cross their payload dvars / double-open the rec menu. Bounded wait - never a
    // skip, the caller already decided to record - then a short self-expiring lease
    // (timed, not a boolean, same rationale as the board lane lease).
    end_ms = GetTime() + 3000;
    while ( isdefined( level.acc_lb_rec_lane_until ) && GetTime() < level.acc_lb_rec_lane_until && GetTime() < end_ms )
        wait 0.1;
    level.acc_lb_rec_lane_until = GetTime() + 2000;

    // SESSION RE-ASSERT (split-session hardening 2026-07-18): the rec chunk parks its
    // minted id on acc_lb_session and REUSES it per match; a transient dvar-read hiccup
    // there would mint a SECOND id mid-match and split the run into two board rows
    // (per-round records give it ~40 chances per game). Capture the id server-side once
    // minted (capture_session_id below) and re-write the dvar before every record, so
    // the chunk's read can't come up empty. Historic splits: backend cleanup.js.
    if ( isdefined( level.acc_lb_session_id ) && level.acc_lb_session_id != "" )
        SetDvar( "acc_lb_session", level.acc_lb_session_id );

    SetDvar( "acc_lb_rec_trace", "" );
    level thread watch_trace_dvar( "acc_lb_rec_trace", 12, false );

    // WEAPON-USAGE PAYLOAD (docs/41 Phase 4): publish the anonymous gun blob + game
    // duration on host-local dvars the rec chunk reads, RIGHT BEFORE the menu opens
    // (R4: fresh each record). serialize() returns "" if the sampler tracked nothing, so
    // in dev/god (callers already returned) or an empty game the guns field is simply
    // absent. GetTime() is match-relative ms -> /1000 = ~game seconds.
    guns = acc_weapon_usage::serialize();
    SetDvar( "acc_lb_guns", guns );
    SetDvar( "acc_lb_dur", "" + int( GetTime() / 1000 ) );
    lb_log( "record guns='" + guns + "' dur=" + int( GetTime() / 1000 ) + "s" );

    // Tier-B box telemetry (docs/41 §3.7): per-gun "id:offers:takes" from the AW box
    // hooks - take_rate = takes/offers is the availability-FREE preference metric
    // (conditioned on the offer, so box odds cancel out). Same dvar transport as the
    // gun blob; "" when the box was never rolled -> the rec chunk omits the field.
    box = acc_weapon_usage::serialize_box();
    SetDvar( "acc_lb_box", box );
    lb_log( "record box='" + box + "'" );

    // Tier-C retention telemetry (docs/41 §3.9): per-gun "id:acquires:replaced" from the
    // sampler's carried-set diff - replace_rate = replaced/acquires is the availability-
    // FREE retention signal (do players KEEP a gun or swap it away; death/down/Mule losses
    // are excluded in GSC). Same dvar transport as the gun/box blobs; "" when nothing was
    // acquired -> the rec chunk omits the field.
    drop = acc_weapon_usage::serialize_drop();
    SetDvar( "acc_lb_drop", drop );
    lb_log( "record drop='" + drop + "'" );

    // PARADISE WINNER tag (user 2026-07-12): level.acc_paradise_won is latched true by
    // acc_paradise::win() BEFORE it lets play continue. The rec chunk turns "1" into
    // "paradise_winner":true in the POST; the board renders "(Paradise Winner)" on the
    // entry. GSC ternary MUST be fully paren-wrapped.
    SetDvar( "acc_lb_paradise", ( IS_TRUE( level.acc_paradise_won ) ? "1" : "0" ) );

    // PER-PLAYER STATS (user 2026-07-14): kills / downs / revives for each player, on the
    // SAME host-local-dvar transport as the gun blob. "" when no player had a scrubbable
    // name -> the rec chunk omits the field. dev/god never reach here (caller gates).
    stats = serialize_stats();
    SetDvar( "acc_lb_stats", stats );
    lb_log( "record stats='" + stats + "' paradise=" + ( IS_TRUE( level.acc_paradise_won ) ? "1" : "0" ) );

    wait 0.1;   // let the payload dvars land client-side before the rec chunk's createMenu reads them
    recorder OpenLUIMenu( "acc_lb_rec" );
    // Nothing to close: the chunk runs at menu-create (pure io - it writes the
    // record + queues the POST trigger for the background agent, docs/40); its
    // trace (r<raw>, w1, j1, q1, done) lands in the log above. The agent being a
    // detached process means the POST survives even an instant quit-to-menu.
    level thread capture_session_id();
}

// Grab the session id the rec chunk parked on acc_lb_session (first record mints it;
// the chunk X-sets the dvar) into a server-side level var, so publish_and_open_rec can
// re-assert it before every later record (the split-session hardening above). Short
// bounded poll - the chunk writes it within its createMenu frame.
function capture_session_id()
{
    end_ms = GetTime() + 3000;
    while ( GetTime() < end_ms )
    {
        s = GetDvarString( "acc_lb_session", "" );
        if ( s != "" )
        {
            level.acc_lb_session_id = s;
            return;
        }
        wait 0.1;
    }
}

// PARADISE WIN-TIME RECORD (2026-07-17): a winning crew that never wipes afterward (quit to
// menu - the natural move after beating the map) used to fire NO end_game, so the run was
// never stored ANYWHERE; the win() comment's "the run ends later on death/quit" is wrong
// about quit (quitting tears the VM down without the notify). Record the moment the win
// latches: same gates as record_at_end_game, same payload publishes. acc_lb_recorded is NOT
// set here, so the eventual end_game re-records the FINAL round - the rec chunk reuses the
// parked session id and the Worker upserts by session (MAX round + paradise latch), so the
// two posts land as ONE board entry. No cross-module call needed: this module polls the
// level flag it already reads, keeping the #using graph unchanged.
function record_on_paradise_win()
{
    level endon( "end_game" );   // a wipe hands off to record_at_end_game (no double record)

    while ( !IS_TRUE( level.acc_paradise_won ) )
        wait 1;

    // USER RULE (2026-07-20, supersedes 07-11): only DEV blocks storage; an opted-out host
    // still stores nothing - the same gates record_at_end_game applies.
    if ( IS_TRUE( level.acc_dev ) )
        return;
    if ( !IS_TRUE( level.acc_lb_consent ) )
        return;

    recorder = pick_recorder();
    if ( !isdefined( recorder ) )
        return;

    if ( !IS_TRUE( level.acc_lb_agent_up ) )
        level.acc_lb_agent_up = recorder boot_agent_verified();

    lb_log( "PARADISE WIN latched - recording NOW (a later end_game upserts the final round)" );
    publish_and_open_rec( recorder );
}

// ---------------------------------------------------------------------------
// LEAVE FLUSH (user 2026-07-18: "override the leave button ... to send data first").
// A deliberate quit (pause-menu Leave Game / Restart Level) tears the server VM down
// WITHOUT firing end_game - record_at_end_game never runs, so any run ended by QUITTING
// was never stored anywhere (the Paradise win-time record 2026-07-17 fixed one instance
// of this hole; this fixes the general case). The pause menu now asks first:
//   Lua (AetheriumStartMenu.lua): unpause (the solo pause freezes server GSC) ->
//   set acc_lb_leave_req 1 -> poll acc_lb_leave_ack on a UITimer (4s hard cap) ->
//   then disconnect / map_restart.
//   GSC (this watcher): the same gates + publish path as record_at_end_game -> ack.
// The POST rides the DETACHED background agent, so it lands even though the game exits
// moments later; with no live agent the record + POST trigger queue on disk and the next
// session's agent sends them (the boot chunk never clears acc_lb_do_post.txt).
// HOST-ONLY by construction (user 2026-07-18 "should only have to override for the
// host"): only the host's pause menu is armed (accLbLeaveHook model, boot_agents), and
// GSC only exists on the host machine anyway - a peer's quit doesn't end the game and
// the host still records it at end_game. Deliberately NO endon("end_game"): a Leave
// pressed on the game-over screen must still ack (instantly - acc_lb_recorded gates the
// double record below).
// ---------------------------------------------------------------------------
function leave_flush_watch()
{
    for ( ;; )
    {
        if ( GetDvarString( "acc_lb_leave_req", "" ) == "1" )
        {
            SetDvar( "acc_lb_leave_req", "" );
            leave_flush_record();
            SetDvar( "acc_lb_leave_ack", "1" );   // ALWAYS ack - a gated run must release the menu instantly
        }
        wait 0.1;
    }
}

// The same gates as record_at_end_game (dev/god/consent/already-recorded), then the same
// publish path. acc_lb_recorded is NOT latched here: a Restart flush is followed by a
// fresh level init (which re-clears everything) and a Leave by full teardown, so nothing
// can double-record - and leaving it unlatched keeps a later end_game upserting the FINAL
// round if the exit somehow doesn't happen (mirrors the Paradise win-time record).
function leave_flush_record()
{
    if ( IS_TRUE( level.acc_dev ) )
        return;   // user rule 2026-07-20 (supersedes 07-11): only dev runs store nothing
    if ( !IS_TRUE( level.acc_lb_consent ) )
        return;
    if ( IS_TRUE( level.acc_lb_recorded ) )
        return;   // end_game already stored this run - just ack

    recorder = pick_recorder();
    if ( !isdefined( recorder ) )
        return;

    // NO agent boot here (unlike record_at_end_game): boot_agent_verified is up to ~15s of
    // retries and the player is sitting on a Leave click. The record + POST trigger land on
    // disk regardless; a down agent just means the next live one sends the queue.
    lb_log( "LEAVE flush: recording before quit (round_number=" + level.round_number
            + " agent_up=" + ( IS_TRUE( level.acc_lb_agent_up ) ? "1" : "0" ) + ")" );
    publish_and_open_rec( recorder );
    wait 0.5;   // the rec chunk's io is synchronous in createMenu - one client frame + margin
}

// ---------------------------------------------------------------------------
// PER-ROUND RECORD (user 2026-07-18: "log data at end of every round ... lets go").
// The Worker upserts by session id (games.round = MAX, every stats table MAX-merges -
// the exact mechanism the Paradise win-time record already rides), so recording every
// round needs NO backend change: each POST re-lands the SAME board row at the highest
// round. This closes the hole the leave flush can't reach - a CRASH mid-round N has
// already posted round N at that round's start, so at most the in-progress round's
// stats deltas are lost, never the run. Cost per round: one small POST (the Worker's
// rate gate is 20/min/IP; rounds are minutes apart) + one local-records line (the
// board chunk's "local" mode dedups by session, 2026-07-18). The leave flush stays
// valuable on top: it re-posts at quit time with the FRESHEST stats/guns/duration.
// The rec chunk posts raw-1 = the just-STARTED round ("reached round N" - the same
// semantic end_game stores when you die on N).
// ---------------------------------------------------------------------------
function record_every_round()
{
    level endon( "end_game" );   // record_at_end_game owns the final record

    // only DEV runs store nothing (user rule 2026-07-20, supersedes 07-11)
    if ( IS_TRUE( level.acc_dev ) )
        return;

    level flag::wait_till( "initial_blackscreen_passed" );

    // BASELINE record ~30s in (clear of the 20s pre-game spawn buffer + the agent
    // boot/auto-fetch): a game that crashes or quits ON round 1 still lands a row, so
    // the map-wide totals count every real game, not just games that reached round 2.
    wait 30;
    round_record( "baseline" );

    // House round-transition pattern (_acc_lui.gsc round poller): poll round_number,
    // record once per change. Poll (not "between_round_over") so a missed notify can
    // never silently end the lane for the rest of a marathon.
    last = ( isdefined( level.round_number ) ? level.round_number : 1 );
    for ( ;; )
    {
        wait 1;
        if ( !isdefined( level.round_number ) || level.round_number == last )
            continue;
        last = level.round_number;
        round_record( "round " + last );
    }
}

// One per-round record: same consent gate as the other lanes (dev/god already gated at
// thread start); SKIPS - never waits - when the record lane is mid-flight, because the
// next round re-records and a skipped tick loses nothing (unlike the end_game/leave
// lanes, which must wait: they are the LAST chance to store).
function round_record( why )
{
    if ( !IS_TRUE( level.acc_lb_consent ) )
        return;
    if ( isdefined( level.acc_lb_rec_lane_until ) && GetTime() < level.acc_lb_rec_lane_until )
        return;

    recorder = pick_recorder();
    if ( !isdefined( recorder ) )
        return;

    lb_log( "per-round record (" + why + "): round_number=" + level.round_number );
    publish_and_open_rec( recorder );
}

// ---------------------------------------------------------------------------
// PER-PLAYER STATS (user 2026-07-14): kills / downs / revives for every player in
// the recorded game. Unlike the ANONYMOUS gun telemetry (_acc_weapon_usage), these
// are NAMED - they ride the same posture as the games table, which already stores
// gamertags, so per-player attribution is intended.
//
// SOURCE = the STOCK scoreboard fields player.kills / .downs / .revives, maintained
// by the engine's own pipeline (verified vs stock ref: _zm_spawner.gsc:2286
// `attacker.kills++`; _zm_laststand.gsc:149 `self.downs++`; :1383/:1442
// `reviver.revives++`). Because the stock game already counts these, we need NO new
// death/down/revive callback or per-player thread - we just READ the three fields at
// end_game. Lowest-risk possible integration (zero new hooks).
//
// TRANSPORT: the SAME host-local dvar hand-off as the gun blob (acc_lb_guns) - read by
// the rec LUI chunk. Format: "name:kills:downs:revives,name:kills:downs:revives,...".
// The gamertag is delimiter-scrubbed (StrTok drops our reserved chars) so it can never
// break the record/field split or the rec chunk's ([^:,]+):(%d+):(%d+):(%d+) parse.
// dev/god never reach here (record_at_end_game gates above) - assisted runs store nothing.
// ---------------------------------------------------------------------------
function serialize_stats()
{
    out = "";
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) )
            continue;
        name = stats_clean_name( p.name );
        if ( name == "" )
            continue;   // no scrubbable gamertag -> skip (never emit an empty record)
        kills   = ( isdefined( p.kills )   ? p.kills   : 0 );
        downs   = ( isdefined( p.downs )   ? p.downs   : 0 );
        revives = ( isdefined( p.revives ) ? p.revives : 0 );
        if ( out != "" )
            out += ",";
        out += name + ":" + kills + ":" + downs + ":" + revives;
    }
    return out;
}

// Strip the transport-reserved chars from a gamertag so it can't break the
// "name:k:d:r,..." format or the rec chunk's JSON. GSC has no regex/replace, but StrTok
// splits on ANY char in its delimiter SET and DROPS the delimiters (+ empty tokens), so
// tokenizing on the reserved set and rejoining the tokens yields a delimiter-free name
// (mirrors the LUI clean() + Worker cleanName()). Length is NOT capped here - the LUI
// clean() and Worker cleanName() both slice to NAME_MAX (24) downstream.
function stats_clean_name( raw )
{
    if ( !isdefined( raw ) )
        return "";
    toks = StrTok( "" + raw, ":,;|\"'\\" );
    out = "";
    for ( i = 0; i < toks.size; i++ )
        out += toks[ i ];
    return out;
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
    acc_interact_glow::glow_on( m );

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

        // debounce: don't stack cards / re-enter while one is showing (covers the
        // ~12s card). On a cache hit the render is instant; the network path takes
        // the same window, so one debounce value fits both.
        if ( GetTime() < level.acc_lb_cooldown_until )
            continue;
        level.acc_lb_cooldown_until = GetTime() + 13000;
        acc_interact_glow::glow_off( m );   // board actually opened = successful use (user 2026-07-17)

        player thread show_board( t );
    }
}

// self = the interacting player. THE VISIBLE BOARD IS NOW THE LUI PANEL (board UI
// 2026-07-15, user "update the leaderboard UI to contain kills/revives/downs"): the
// acc_lb_board menu shell renders a centered panel with per-game rank/round rows and
// nested per-player KILLS/REVIVES/DOWNS columns, client-side from the fetch chunk's
// structured rows - so a co-op peer gets the full board even though its Exec->dvar
// push never reaches the server. GSC owns the menu lifetime (walk-away/12s close),
// the hint, the per-session cache key, and a LEGACY-CARD FALLBACK: if the shell does
// not confirm the render on dvar acc_lb_lui ("ok:N"), the old acc_ui card renders
// from the still-pushed acc_lb_r* dvars, so the station can never show nothing.
//
// ONE network fetch PER SESSION per lobby size (user 2026-07-12): the result FILE on
// disk is the cache now - on a cache hit GSC sets acc_lb_use_cache 1 and the chunk
// skips the curl, re-serving the file instantly. A fetch that only reached the
// offline/empty fallback is NOT cached, so a later trigger retries the network.
function show_board( t )
{
    self endon( "disconnect" );
    level endon( "end_game" );

    // CO-OP PEER LANE (2026-07-16, user: "non host players cant see the UI for the
    // Leaderboards"): the whole fetch pipeline below is host-machine-only (agent, records
    // file, Exec->dvar handshake), so a peer's shell used to sit silent for 8s and then
    // render an EMPTY local fallback. Peers instead get the HOST's fetched rows relayed
    // over the accLbR* controller models (see the #precache block up top) and render the
    // same panel from them - no curl, no dvars, no handshake. IsHost() (the stock
    // util::getHostPlayer predicate) rather than an entity compare: getHostPlayer() can
    // return undefined and `entity != undefined` THROWS in T7 (memory gsc-t7-runtime-traps).
    if ( !( self IsHost() ) )
    {
        self show_board_peer( t );
        return;
    }

    // BOARD LANE LEASE: if a silent lane (auto-fetch / dev probe) is mid-flight, wait
    // it out instead of trading dvar clobbers with it, then own the channel through
    // fetch + render handshake. Released before the 12s display window - the panel is
    // client-side by then and the channel is cold. 12s lease = 10s done-wait + the
    // 0.5s handshake grace + settle, self-expiring if this thread dies mid-fetch.
    lane_wait( 13000 );
    lane_take( 12000 );

    // PER-LOBBY-SIZE ladder - THE REQUIREMENT (user 2026-07-15 round 3: a solo lobby
    // sees the top 10 SOLO rounds; briefly global that same day, reverted). Publish
    // the lobby size (the chunk's dvar fallback; it counts client-side first) and
    // CACHE PER COUNT so a solo board is never re-served to a changed lobby.
    pc = acc_lb_player_count();
    SetDvar( "acc_lb_players", "" + pc );

    cache_hit = ( IS_TRUE( level.acc_lb_have_cache ) && isdefined( level.acc_lb_cache_pc ) && level.acc_lb_cache_pc == pc );

    clear_board_dvars();
    SetDvar( "acc_lb_board_show", "1" );                       // visible panel (silent fetches set 0)
    SetDvar( "acc_lb_use_cache", ( cache_hit ? "1" : "0" ) );  // serve the on-disk result file, no curl
    if ( IS_TRUE( level.acc_dev ) )
        level thread watch_trace_dvar( "acc_lb_board_trace", 10, true );

    if ( isdefined( t ) )
        t SetHintString( ACC_LB_HINT_BUSY );

    wait 0.1;   // let the dvars land client-side before the chunk's createMenu reads them (de-race, 2026-07-17)
    m = self OpenLUIMenu( "acc_lb_board" );

    // the LUI always terminates: done lands by ~8s (agent poll + curl; ~0.5s on a cache
    // hit) or the local fallback fills in. A co-op PEER's Exec->dvar push never reaches
    // the server, so done stays "" there - the peer still renders its panel client-side;
    // this loop just times out and the display window below keeps the menu open.
    done = "";
    end_ms = GetTime() + 10000;
    while ( GetTime() < end_ms )
    {
        done = GetDvarString( "acc_lb_done", "" );
        if ( done != "" )
            break;
        if ( Distance2D( self.origin, ACC_LB_STATION_ORIGIN ) > 120 )   // walked off mid-fetch
            break;
        wait 0.1;
    }

    // hint BLANK while the board is up - the idle cursor hint was bleeding through
    // the panel (user screenshot 2026-07-15). Restored to idle on every exit path
    // below; a mid-display disconnect can leave it blank until the next use, which
    // self-heals on that use's BUSY -> IDLE cycle (accepted cosmetic edge).
    if ( isdefined( t ) )
        t SetHintString( "" );

    lines = board_lines();

    src = "";
    if ( done == "" )
        src = " ^1(no link)";
    else if ( IsSubStr( done, "loc" ) )
        src = " ^3(offline)";

    // CACHE ONLY a real network result (done starts "net:") - so an offline/empty
    // fallback doesn't get frozen in for the session; the next trigger retries.
    if ( IsSubStr( done, "net" ) )
    {
        level.acc_lb_have_cache = true;
        level.acc_lb_cache_pc = pc;   // per-count cache key
    }

    // walked away during the fetch? close quietly + release the debounce
    if ( Distance2D( self.origin, ACC_LB_STATION_ORIGIN ) > 120 )
    {
        lane_free();
        if ( isdefined( m ) )
            self CloseLUIMenu( m );
        if ( isdefined( t ) )
            t SetHintString( ACC_LB_HINT_IDLE );
        level.acc_lb_cooldown_until = GetTime() + 1000;
        return;
    }

    // LUI panel handshake: done != "" proves the Exec->dvar bridge works for this
    // player (solo/host), so a missing "ok" there means the panel really failed ->
    // legacy card. A peer (done == "") renders client-side and can't report - no
    // fallback for them (a server card would stack over their live panel).
    lui = GetDvarString( "acc_lb_lui", "" );
    if ( lui == "" && done != "" )
    {
        wait 0.5;   // render + Exec land right after done - give the shell a beat
        lui = GetDvarString( "acc_lb_lui", "" );
    }
    if ( done != "" && !IsSubStr( lui, "ok" ) )
    {
        lane_free();   // handshake decided - the card below reads no channel dvars (lines snapshotted)
        if ( isdefined( m ) )
            self CloseLUIMenu( m );
        lb_log( "board panel fallback: lui='" + lui + "' done='" + done + "' -> legacy card" );
        self render_board_card( lines, src );   // blocks for its own display window
        if ( isdefined( t ) )
            t SetHintString( ACC_LB_HINT_IDLE );
        return;
    }

    // handshake confirmed - release the channel; the display window below only
    // proximity-polls and the panel lives client-side now
    lane_free();

    // panel display window: up to 12s, closed EARLY the moment the player walks away
    // (user 2026-07-12 rule - same proximity contract the old card used)
    end_ms = GetTime() + 12000;
    while ( GetTime() < end_ms )
    {
        wait 0.25;
        if ( !isdefined( self ) )
            break;
        if ( Distance2D( self.origin, ACC_LB_STATION_ORIGIN ) > 120 )
            break;
    }

    if ( isdefined( m ) && isdefined( self ) )
        self CloseLUIMenu( m );
    if ( isdefined( t ) )
        t SetHintString( ACC_LB_HINT_IDLE );
    level.acc_lb_cooldown_until = GetTime() + 1000;   // release the debounce for quick re-use
}

// self = a NON-HOST player at the Plaza station (the co-op peer lane, 2026-07-16).
// Relay the server-side board rows - landed in acc_lb_r*/acc_lb_st*/acc_lb_tot by the
// HOST chunk's Engine.Exec during auto_fetch_board / a host station use - to THIS
// player's client over per-player controller UI models, then open the same menu shell:
// its "feed" mode rebuilds the panel from the models. EVERY model is written each open
// (empty string included) so a stale relay from an earlier open can never linger. No
// acc_lb_done wait on this lane: a peer's Exec->dvar push never reaches the server, so
// that handshake can't move - the panel needs no server confirmation to render, and the
// legacy-card fallback would stack OVER the peer's live panel (the reason show_board
// already skipped it for peers).
function show_board_peer( t )
{
    self endon( "disconnect" );
    level endon( "end_game" );

    // BOARD LANE LEASE: don't relay while a silent lane is mid-flight (its
    // clear_board_dvars would hand this peer a half-wiped row set). The read->push
    // block below has no waits, so once the channel is quiet it can't be interleaved;
    // no lease taken - the peer's panel renders from its own controller models and
    // its client never sees server dvars anyway.
    lane_wait( 13000 );

    done = GetDvarString( "acc_lb_done", "" );
    n_rows = 0;
    for ( i = 1; i <= 10; i++ )
    {
        r = GetDvarString( "acc_lb_r" + i, "" );
        row = "";
        if ( r != "" )
        {
            // same "round|names|stats" v2 row text the chunk's parse_rows already eats
            row = r + "|" + GetDvarString( "acc_lb_st" + i, "" );
            n_rows++;
        }
        self SetControllerUIModelValue( "accLbR" + i, row );
    }
    self SetControllerUIModelValue( "accLbTot", GetDvarString( "acc_lb_tot", "" ) );
    self SetControllerUIModelValue( "accLbSrc", ( IsSubStr( done, "net" ) ? "net" : "loc" ) );
    lb_log( "board peer relay: " + n_rows + " rows (done='" + done + "') -> " + self.name );

    // straight to the panel - no fetch window, so no BUSY hint; blank while it shows
    // (the idle hint bled through the panel, user screenshot 2026-07-15)
    if ( isdefined( t ) )
        t SetHintString( "" );

    m = self OpenLUIMenu( "acc_lb_board" );

    // panel display window: same contract as the host lane - up to 12s, closed EARLY
    // the moment the player walks away
    end_ms = GetTime() + 12000;
    while ( GetTime() < end_ms )
    {
        wait 0.25;
        if ( !isdefined( self ) )
            break;
        if ( Distance2D( self.origin, ACC_LB_STATION_ORIGIN ) > 120 )
            break;
    }

    if ( isdefined( m ) && isdefined( self ) )
        self CloseLUIMenu( m );
    if ( isdefined( t ) )
        t SetHintString( ACC_LB_HINT_IDLE );
    level.acc_lb_cooldown_until = GetTime() + 1000;   // release the debounce for quick re-use
}

// self = player. Render (or empty-state) the leaderboard card: up to ~12s, but HIDE
// EARLY the moment the player WALKS AWAY from the station (user 2026-07-12: "I walked
// away and it stayed"). Proximity poll vs the station origin (2D so height doesn't
// matter); the use-trigger radius is 64, so 120 = a couple of steps back. On hide -
// early or natural - the interaction cooldown is released so the station can be used
// again right away instead of eating the rest of the 13s debounce.
function render_board_card( lines, src )
{
    self endon( "disconnect" );
    level endon( "end_game" );

    if ( !isdefined( lines ) )
        lines = [];
    if ( !isdefined( src ) )
        src = "";

    if ( lines.size == 0 )
    {
        lines[ 0 ] = "^7No runs on the board yet.";
        lines[ 1 ] = "^5- ^7Finish a match to claim a slot.";
    }

    // already left during the fetch? don't even flash the card
    if ( Distance2D( self.origin, ACC_LB_STATION_ORIGIN ) > 120 )
    {
        level.acc_lb_cooldown_until = GetTime() + 1000;
        return;
    }

    self acc_ui::card_show( acc_lb_count_label( acc_lb_player_count() ) + " LEADERBOARDS" + src, ( 0.4, 0.9, 1.0 ), undefined, lines );

    end_ms = GetTime() + 12000;
    while ( GetTime() < end_ms )
    {
        wait 0.25;
        if ( !isdefined( self ) )
            return;
        // walked away (or went down and got dragged off) -> clean up immediately
        if ( Distance2D( self.origin, ACC_LB_STATION_ORIGIN ) > 120 )
            break;
    }

    self acc_ui::card_hide();
    level.acc_lb_cooldown_until = GetTime() + 1000;   // release the debounce for quick re-use
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
    SetDvar( "acc_lb_lui", "" );   // panel-render handshake (board UI 2026-07-15)
    SetDvar( "acc_lb_tot", "" );   // totals footer (peer relay, 2026-07-16)
    for ( i = 1; i <= 10; i++ )
    {
        SetDvar( "acc_lb_r" + i, "" );
        SetDvar( "acc_lb_st" + i, "" );   // per-row stats blob (peer relay, 2026-07-16)
    }
}

// ---------------------------------------------------------------------------
// BOARD LANE LEASE (2026-07-17 "I saw the old leaderboard UI" fix). The
// acc_lb_board menu + its dvars (acc_lb_board_show / acc_lb_use_cache /
// acc_lb_done / acc_lb_lui / acc_lb_r*/st*/tot) are ONE shared channel, and the
// silent lanes (auto_fetch_board, dev_fetch_probe) used to drive it with no
// regard for a visible session: live capture had the player open the station at
// t=64.9s, the dev probe fire at t=65.1s - its clear_board_dvars() wiped the
// in-flight handshake and its acc_lb_board_show "0" made the shell's serve()
// take the silent-fetch early-return, so no acc_lb_lui "ok" ever landed and the
// GSC handshake (correctly) drew the legacy card over a healthy panel. Only one
// lane may drive the channel at a time: visible lanes WAIT then take the lease,
// silent lanes SKIP when it is held (a visible fetch populates the same cache
// the pre-warm would). A TIMED lease, not a boolean: show_board can die
// mid-lease (endon disconnect / end_game), and a stranded boolean would jam the
// station for the rest of the match - a lease just expires.
// ---------------------------------------------------------------------------

function lane_take( ms )
{
    level.acc_lb_lane_until = GetTime() + ms;
}

function lane_free()
{
    level.acc_lb_lane_until = 0;
}

function lane_busy()
{
    return ( isdefined( level.acc_lb_lane_until ) && GetTime() < level.acc_lb_lane_until );
}

// Bounded wait for the channel (visible lanes): worst case one stale lease's
// remainder, then proceed anyway - the station can never brick on this.
function lane_wait( max_ms )
{
    end_ms = GetTime() + max_ms;
    while ( lane_busy() && GetTime() < end_ms )
        wait 0.1;
}

// Current lobby size, clamped to the 1..4 board buckets (user 2026-07-13: separate
// solo/duo/trio/quad ladders). Read by the board chunk (?players=N) via acc_lb_players
// and by the card title label below.
function acc_lb_player_count()
{
    n = GetPlayers().size;
    if ( n < 1 ) n = 1;
    if ( n > 4 ) n = 4;
    return n;
}

// 1..4 -> the board title prefix.
function acc_lb_count_label( pc )
{
    if ( pc <= 1 ) return "SOLO";
    if ( pc == 2 ) return "DUO";
    if ( pc == 3 ) return "TRIO";
    return "QUADS";
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

    // BOARD LANE LEASE (the exact live collision 2026-07-17: probe fired 200ms after a
    // station open and its dvar wipe pushed the healthy panel onto the legacy card).
    // The probe is log-only - skipping loses nothing when a real fetch is running.
    if ( lane_busy() )
    {
        lb_log( "DEV PROBE: skipped - board lane busy (visible session or auto-fetch mid-flight)" );
        return;
    }
    lane_take( 11000 );   // 9s done-wait + settle, self-expiring

    clear_board_dvars();
    SetDvar( "acc_lb_players", "" + acc_lb_player_count() );   // per-count board (user 2026-07-13)
    SetDvar( "acc_lb_board_show", "0" );   // probe is log-only: never render the panel
    SetDvar( "acc_lb_use_cache", "0" );
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
    lane_free();
    lb_log( "DEV PROBE COMPLETE (" + rows.size + " rows)" );
}

// ---------------------------------------------------------------------------
// SHARED PLUMBING
// ---------------------------------------------------------------------------

// Mirror one line to the durable oracles: IPrintLnBold -> console_mp.log
// "[ SCRIPTER]" lines (docs/17), acc_utility::log -> dev-block println.
// ON-SCREEN MIRROR IS DEBUG-ONLY (user 2026-07-12: "debug UI showing when you die even on
// non dev mode. It in the published version" - the recorder runs at end_game, so every death
// splashed ^5[LB]^7 lines on shipped builds). Per the debug-banner rule (memory
// debug-banners-gated-by-acc-dev-only, re-confirmed 2026-07-16: debug rides the ONE acc_dev flag;
// the acc_lb_debug dvar was removed): a dev build restores the on-screen/console_mp.log oracle
// for LB test sessions; the silent dev-block log below always runs.
function lb_log( line )
{
    if ( IS_TRUE( level.acc_dev ) )
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
