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
REM  Flags (ALL off by default -> a no-flag launch is a clean consumer game;
REM  full reference: docs\34_flags_reference.md):
REM         acc_dev 1       = unlimited money + Data Shards + Mega Bottles, auto-power,
REM                           perk cap 18, dev HUDs + teleport/round-skip console cmds.
REM         acc_open_map 1  = open every door + both PaP blockers on spawn, disable decon.
REM         acc_test_boss 1 = test boss from round 2, drops 10 Mega Bottles on death.
REM         acc_variants_debug 1 = print each weapon-variant swap on-screen
REM           ("[variants] X -> Y") so you can SEE Deadshot/Mega change the gun
REM           (recoil is invisible). acc_weapon_variants is ON by default already.
REM ===========================================================================
REM  THE GAMETYPE FIX (verified 2026-06-13): pass the ENGINE COMMAND
REM  "+set_gametype zclassic", NOT "+set g_gametype zclassic". The g_gametype
REM  dvar is reset to the session default by the engine, so a plain +set never
REM  sticks -> launch falls back to "tdm" -> scripts/zm/gametypes/tdm.gsc missing
REM  -> fatal error -> black screen. set_gametype is what the Mod Tools Launcher
REM  uses, and it sticks.
REM  Also keep BO3's Steam LAUNCH OPTIONS EMPTY (Steam appends them -> doubled
REM  command line -> the same tdm corruption).
REM  Custom LUI (acc_hud.lua) runs on Steam BO3 with NO special flag (verified
REM  2026-06-13). "-unsafe-lua" is a BOIII-client arg, not Steam BO3 - on Steam it
REM  is "Unknown command", so it is intentionally NOT passed. (L3akMod is still
REM  needed in the MOD TOOLS bin to BUILD the .lua - docs/28_lui_pipeline.md.)
start "" "steam://run/311210//+set fs_game zm_abandoned_cyber_city +set_gametype zclassic +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1 +set acc_dev 1 +set acc_open_map 1 +set acc_test_boss 1 +set acc_variants_debug 1"
