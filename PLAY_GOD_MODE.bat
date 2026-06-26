@echo off
REM ===========================================================================
REM  PLAY_GOD_MODE.bat - double-click to launch Abandoned Cyber City in
REM  REGULAR play + GOD MODE (you canNOT die), THROUGH Steam.
REM
REM  This is NOT dev mode. It is a clean, normal game - real perks, real Data
REM  Shard economy, real progression, CLOSED map (you flip the Bus Station power
REM  switch + buy doors yourself) - EXCEPT every player is invulnerable, so you
REM  can playtest normal balance/flow as long as you like without dying.
REM
REM    +set acc_dev 0  = NOT dev mode (no unlimited money / open map / test bosses)
REM    +set acc_god 1  = GOD MODE only (EnableInvulnerability on every player)
REM
REM  acc_god is INDEPENDENT of acc_dev (entry script acc_resolve_dev_flags()); it
REM  changes nothing else. For the full dev sandbox use PLAY_TEST_MAP.bat instead;
REM  for a clean game with real damage, a no-flag launch.
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
start "" "steam://run/311210//+set fs_game zm_abandoned_cyber_city +set_gametype zclassic +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1 +set acc_dev 0 +set acc_god 1"
