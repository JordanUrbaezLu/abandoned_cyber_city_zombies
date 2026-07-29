@echo off
REM ===========================================================================
REM  PLAY_NORMAL.bat - THE play script. Double-click to launch Abandoned Cyber
REM  City THROUGH Steam. This is the ONLY launcher (user 2026-07-15: "remove all
REM  the play scripts except the Normal play script" - PLAY_TEST_MAP.bat /
REM  PLAY_GOD_MODE.bat / tools\run_avo_test.bat deleted the same day).
REM
REM  DEV / GOD MODE DO NOT LIVE HERE (user 2026-07-15: "this is the way we test
REM  in this repo... we don't use launch flags"). They are HARDCODED in the
REM  build: scripts\zm\zm_abandoned_cyber_city.gsc::acc_resolve_dev_flags()
REM  (ship lines are hardcoded "= false;"; flip to "= true;" + rebuild for a test
REM  session, restore "= false;" before publish - prep_release Gate 0 enforces
REM  it). Whatever the current build hardcodes is what this script launches.
REM  Full doctrine: CLAUDE.md "HOW TEST SESSIONS ARE ARMED" +
REM  docs\22_flags_reference.md.
REM
REM  Build FIRST (.\tools\build_map.ps1, or -GscOnly for script-only changes),
REM  THEN double-click this. Steam must be running + logged in. Loading takes
REM  ~40-60 seconds.
REM
REM  Engine args below (required to load the map, NOT toggles): fs_game /
REM  set_gametype / devmap / developer / logfile / g_log. THE GAMETYPE FIX: pass
REM  "+set_gametype zclassic" (engine command, sticks), NOT "+set g_gametype
REM  zclassic" (resets to tdm -> black screen). Keep BO3's Steam LAUNCH OPTIONS
REM  EMPTY (Steam doubles them). g_log/g_logSync = engine game log
REM  (games_mp.log) for the [ACCDIAG] 30s census; logfile 1 = console_mp.log.
REM  Full reference: docs\17_launch_runbook.md.
REM ===========================================================================
REM [acc] LEADERBOARD AGENT PRE-SPAWN (docs/40, user 2026-07-12 "do it silently"): spawn the
REM hidden network agent BEFORE the game and pass +set acc_lb_agent 1 so the game skips its own
REM spawn - NO terminal window ever appears. Helper is generated (tools/build_lb_lui.js); if it
REM is missing the launch still works (the game falls back to its own minimized spawn).

REM [acc] BUILD-IN-PROGRESS GUARD (2026-07-25): launching while the linker/compiler is writing
REM the .ff makes the game load a HALF-WRITTEN fastfile -> torn Lua chunks -> an on-screen
REM "UI Error <code>" box at load (live-hit: launch 3:31:44 vs .ff finished 3:34:07 = UI Error
REM 44429). If any build tool is running, WAIT for it to finish, then double-click this again.
tasklist /FI "IMAGENAME eq linker_modtools.exe" 2>NUL | find /I "linker_modtools.exe" >NUL && goto build_running
tasklist /FI "IMAGENAME eq cod2map64.exe"      2>NUL | find /I "cod2map64.exe"      >NUL && goto build_running
tasklist /FI "IMAGENAME eq radiant_modtools.exe" 2>NUL | find /I "radiant_modtools.exe" >NUL && goto build_running

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\spawn_lb_agent.ps1"
start "" "steam://run/311210//+set fs_game zm_abandoned_cyber_city +set_gametype zclassic +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1 +set g_log games_mp.log +set g_logSync 1 +set acc_lb_agent 1"
goto :eof

:build_running
echo.
echo  [PLAY_NORMAL] A MAP BUILD IS RUNNING - not launching.
echo  Launching now would load a HALF-WRITTEN fastfile (= "UI Error" box / corrupt load).
echo  Wait for the build to finish, then double-click this again.
echo.
pause
exit /b 1
