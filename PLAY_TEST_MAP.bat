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
REM         acc_dev 1       = THE SINGLE DEV SWITCH (user 2026-06-22). Turns on the WHOLE hardcoded
REM           dev sandbox: unlimited money, 25 starting Data Shards, Mega Bottles, OPEN MAP (every door +
REM           PaP blockers, decon off), ALL test bosses (Brutus/Glitch/Phantom), all perk slots, and the
REM           dev HUDs + teleport/round-skip console cmds. NO god mode and NO auto power-on - you take
REM           regular damage and flip the Bus Station power switch yourself. No other dev flag is needed -
REM           the entry script's acc_resolve_dev_flags() drives the rest off this one flag.
REM           acc_dev 0 (or omit it) = clean normal play.
REM         acc_glitch_test 1 = spawn the "Glitch Stalker" mini-boss (mobile teleport-blink boss,
REM           x2/round) from ROUND 3. It moves ~15%% faster than normal zombies, blinks 2x more
REM           often (~1-1.67s), deals -50%% melee damage (user 2026-06-15), uses the STOCK zombie
REM           body (vs the charred horde), and has NO health bar / NO over-head marker.
REM           acc_glitch_debug 1 prints [glitch] lines.
REM           (Glitch r3 / Brutus r4 are the in-code DEFAULTS now - they apply even without flags.)
REM         acc_variants_debug 1 = print each weapon-variant swap on-screen
REM           ("[variants] X -> Y") so you can SEE Deadshot/Mega change the gun
REM           (recoil is invisible). acc_weapon_variants is ON by default already.
REM         acc_lockdown_on 1 = per-round "DEFCON" room lockdown (docs/37 §11): red flashing
REM           alarm lights inside the room (+ optional door seal). ENABLED below, pinned to the
REM           Vault (acc_lockdown_force_zone vault_zone) for testing. Doors are set to NOT
REM           seal (acc_lockdown_lock_doors 0) so you can WALK IN and see the red light + the new
REM           vault ceiling - in the ~ console type acc_lockdown_lock_doors 1 to test the door seal
REM           (locks players IN, no escape window) on the next round. Tune live: acc_lockdown_use_glow
REM           1 (softer glow), acc_lockdown_fx_z 180 (light height), acc_lockdown_emitters 6.
REM         acc_amb_on 1    = play the looping ambient city bed. (The main theme
REM           "The Surreal Truth" plays ONCE at game start + stock ZM music is OFF by
REM           default; Brutus boss music "Juhani Junkala - Epic Boss Battle" loops while
REM           Brutus is alive and slow-fades on death - all automatic, no flags needed
REM           (acc_test_boss below makes Brutus spawn so the boss track is exercised).
REM           Remove acc_amb_on to mute just the city bed.)
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
REM  ===========================================================================
REM  ONE DEV FLAG (user 2026-06-22). `+set acc_dev 1` is the ENTIRE dev switch -
REM  it turns on unlimited money, 25 starting Data Shards, open map, all test
REM  bosses, all perk slots, power, and the dev HUDs (regular gameplay damage -
REM  NO god mode). The entry script's
REM  acc_resolve_dev_flags() drives everything else off this one flag. (The engine
REM  args before it - fs_game / set_gametype / devmap / developer / logfile - are
REM  required to load the map, not dev toggles.) For a clean normal game: acc_dev 0.
REM  ===========================================================================
REM  g_log/g_logSync: engine GAME log (games_mp.log) - the [ACCDIAG] 30s diagnostics census
REM  (_acc_diag.gsc LogPrint, file-only) lands there; logfile 1 covers console_mp.log separately.
start "" "steam://run/311210//+set fs_game zm_abandoned_cyber_city +set_gametype zclassic +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1 +set g_log games_mp.log +set g_logSync 1 +set acc_dev 1"
