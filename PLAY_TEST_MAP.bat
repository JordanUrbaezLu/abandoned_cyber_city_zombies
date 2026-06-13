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
start "" "steam://run/311210//+set fs_game zm_abandoned_cyber_city +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1 +set acc_test_boss 1 +set acc_dev 1"
