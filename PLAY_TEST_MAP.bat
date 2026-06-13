@echo off
REM ===========================================================================
REM  Double-click to launch Abandoned Cyber City (test sandbox) THROUGH Steam.
REM
REM  Why a .bat: the Mod Tools Launcher's "Run" launches BlackOps3.exe directly,
REM  which BO3's Steam DRM refuses ("Steam must be running" popup, then exits).
REM  Going through Steam (steam://run/311210) gives a valid DRM session so the
REM  map actually loads.
REM
REM  Build FIRST in the Launcher (Link only; Run unchecked), THEN double-click
REM  this. Steam must be running and logged in. Loading takes ~40-60 seconds.
REM
REM  Flags: acc_dev 1 = unlimited money / perk cap 18 / door markers.
REM         acc_test_boss 1 = Juggernaut Host from round 2, drops 10 Mega Bottles.
REM ===========================================================================
REM  THE GAMETYPE FIX (verified 2026-06-13): pass the ENGINE COMMAND
REM  "+set_gametype zclassic", NOT "+set g_gametype zclassic". The g_gametype
REM  dvar is reset to the session default by the engine, so a plain +set never
REM  sticks -> launch falls back to "tdm" -> scripts/zm/gametypes/tdm.gsc missing
REM  -> fatal error -> black screen. set_gametype is what the Mod Tools Launcher
REM  uses, and it sticks.
REM  Also keep BO3's Steam LAUNCH OPTIONS EMPTY (Steam appends them -> doubled
REM  command line -> the same tdm corruption).
REM  -unsafe-lua: REQUIRED for the custom LUI HUD (acc_hud.lua) to run. BO3 blocks
REM  custom "unsafe" Lua by default; this dashed switch allows it. The map also
REM  needs L3akMod installed in bin to BUILD with custom .lua (docs/28_lui_pipeline.md).
start "" "steam://run/311210//-unsafe-lua +set fs_game zm_abandoned_cyber_city +set_gametype zclassic +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1 +set acc_test_boss 1 +set acc_dev 1"
