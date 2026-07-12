@echo off
REM ===========================================================================
REM  PLAY_NORMAL.bat - double-click to launch Abandoned Cyber City as a CLEAN,
REM  NORMAL game (what a Workshop player gets), THROUGH Steam.
REM
REM  NO dev sandbox, NO god mode: real perks, real Data Shard economy, real
REM  progression, CLOSED map (flip the Bus Station power switch + buy doors
REM  yourself), and REAL DAMAGE (you can go down + die). This is the honest
REM  playtest of balance + difficulty.
REM
REM    +set acc_dev 0  = NOT dev mode (no unlimited money / open map / test bosses)
REM    +set acc_god 0  = NOT god mode (you take real damage)
REM
REM  The three play scripts:
REM    PLAY_TEST_MAP.bat  = DEV sandbox (acc_dev 1): unlimited money, open map, test bosses, all slots.
REM    PLAY_GOD_MODE.bat  = regular play + GOD (acc_dev 0, acc_god 1): real game, can't die.
REM    PLAY_NORMAL.bat    = regular play, REAL DAMAGE (acc_dev 0, acc_god 0): this file.
REM
REM  Build FIRST (Link only; Run unchecked), THEN double-click this. Steam must be
REM  running + logged in. Loading takes ~40-60 seconds.
REM
REM  Engine args (required to load the map, NOT toggles): fs_game / set_gametype /
REM  devmap / developer / logfile. THE GAMETYPE FIX: pass "+set_gametype zclassic"
REM  (engine command, sticks), NOT "+set g_gametype zclassic" (resets to tdm ->
REM  black screen). Keep BO3's Steam LAUNCH OPTIONS EMPTY (Steam doubles them).
REM  Full reference: docs\34_flags_reference.md, docs\23_launch_runbook.md.
REM ===========================================================================
REM [acc] LEADERBOARD AGENT PRE-SPAWN (docs/40, user 2026-07-12 "do it silently"): spawn the
REM hidden network agent BEFORE the game and pass +set acc_lb_agent 1 so the game skips its own
REM spawn - NO terminal window ever appears. Helper is generated (tools/build_lb_lui.js); if it
REM is missing the launch still works (the game falls back to its own minimized spawn).
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\spawn_lb_agent.ps1"
start "" "steam://run/311210//+set fs_game zm_abandoned_cyber_city +set_gametype zclassic +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1 +set acc_dev 0 +set acc_god 0 +set acc_lb_agent 1"
