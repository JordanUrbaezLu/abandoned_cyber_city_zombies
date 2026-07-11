@echo off
REM ===========================================================================
REM  AVOGADRO deep-test launcher (user 2026-07-04). Same as PLAY_TEST_MAP.bat but
REM  adds `+set acc_avo_debug 1` so every Avogadro step ([AVO] ...) routes to
REM  console_mp.log (spawn, seek heartbeat with his position, hacks, restores,
REM  drops). Double-click, then just stand there ~60s (he auto-spawns in the LAB
REM  ~8s into round 1 and starts hacking on his own - no need to go find him).
REM  Optionally walk north to the Lab to watch him move / stun you / knife him.
REM  Then close the game and tell the session so it can read + analyze the log.
REM  console_mp.log = <game>\console_mp.log (game install, not the tools root).
REM ===========================================================================
start "" "steam://run/311210//+set fs_game zm_abandoned_cyber_city +set_gametype zclassic +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1 +set g_log games_mp.log +set g_logSync 1 +set acc_dev 1 +set acc_avo_debug 1"
