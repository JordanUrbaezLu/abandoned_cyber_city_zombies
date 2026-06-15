# =============================================================================
# run_game.ps1 - launch the already-built map straight into the game.
#
# Why this exists: the Mod Tools Launcher's "Run" launches BlackOps3.exe
# DIRECTLY, which trips BO3's Steam DRM ("Steam must be running to play this
# game" popup, then exits) even with Steam running + steam_appid.txt present.
# Launching THROUGH Steam (steam://run/311210) gives the proper DRM context,
# so the game opens and loads the dev map. VERIFIED working 2026-06-12.
#
# Usage:  .\tools\run_game.ps1              (full test sandbox: dev + open map + boss)
#         .\tools\run_game.ps1 -NoBoss      (sandbox, no test boss)
#         .\tools\run_game.ps1 -ClosedMap   (dev sandbox but map starts CLOSED + decon live)
#         .\tools\run_game.ps1 -NoDev       (clean consumer game: no sandbox, closed map)
# Build first (Launcher: Compile/Light/Link, or just Compile Scripts for GSC).
# Steam must be running and logged in.
# =============================================================================

param([switch]$NoBoss, [switch]$NoDev, [switch]$NoVarDebug, [switch]$ClosedMap, [switch]$NoAmbient)

# All flags below are OFF by default in the game -> a no-flag launch is a clean
# consumer game. Full reference: docs/34_flags_reference.md.
# acc_dev 1      = unlimited money + Data Shards + Mega Bottles, auto-power, perk cap 18,
#                  dev HUDs + teleport/round-skip console cmds (the test sandbox).
# acc_open_map 1 = open every door + both PaP blockers on spawn, disable decon hazard.
# acc_test_boss 1 = test boss (Brutus) every round (the real Brutus now first spawns ROUND 4).
# acc_glitch_test 1 = spawn the "Glitch Stalker" mini-boss (mobile teleport-blink boss, x2/round)
#   from ROUND 3; it now moves ~15% faster than normal zombies, blinks 3x as often, uses the
#   STOCK zombie body (vs the charred horde), has a purple over-head box and NO health bar.
#   acc_glitch_debug 1 prints [glitch] lines. -NoBoss disables ALL test-boss spawns.
#   (Glitch r3 / Brutus r4 are the in-code DEFAULTS now, so they apply even without these flags.)
# acc_variants_debug 1 = print each weapon-variant SWAP on-screen ("[variants] X -> Y")
#   so you can SEE Deadshot/Mega change the gun (recoil is otherwise invisible).
#   (acc_weapon_variants itself is ON by default - no flag needed to enable it.)
$boss = if ($NoBoss) { "" } else { " +set acc_test_boss 1 +set acc_glitch_test 1 +set acc_glitch_debug 1" }
$dev  = if ($NoDev)  { "" } else { " +set acc_dev 1" }
# Open map follows the dev sandbox, but -ClosedMap keeps the sandbox while leaving
# the map closed + the decon hazard live (to test door buys / decontamination).
$openmap = if ($NoDev -or $ClosedMap) { "" } else { " +set acc_open_map 1" }
$vdbg = if ($NoVarDebug) { "" } else { " +set acc_variants_debug 1" }

# Audio: the MAIN THEME "The Surreal Truth" plays once at game start and stock ZM
# music is OFF by default (no flag); Brutus boss music "Juhani Junkala - Epic Boss
# Battle" loops while Brutus is alive and slow-fades on death (automatic - acc_test_boss
# makes Brutus spawn so it's exercised). acc_amb_on 1 additionally plays the looping
# ambient city bed - ON for the play-test so all audio is exercised. -NoAmbient mutes
# just the bed.
$audio = if ($NoAmbient) { "" } else { " +set acc_amb_on 1" }

# -----------------------------------------------------------------------------
# ZOMBIE SPEED CURVE knobs (docs/34 "D" + _acc_zombie_speed.gsc). Natural-gait
# ramp: a jog that speeds up the early rounds, breaks into a full sprint at
# $ZSpeedSprintRound, then a faster sprint after. EDIT THE NUMBERS to tune; the
# values below are the in-code DEFAULTS (so leaving them as-is = no change).
# 100 = the gait's natural speed, higher = faster; values can't go below 100
# in-game (that would look like slow-motion, so the code floors them at 100).
$ZSpeedSprintRound    = 10   # round zombies break from a jog into a full SPRINT (lower = sprint sooner)
$ZSpeedJogStartPct    = 100  # round-1 jog playback %, 100 = natural jog
$ZSpeedJogStepPct     = 2    # + jog speed % per round during the jog phase (higher = ramps up faster)
$ZSpeedSprintStartPct = 100  # sprint playback % at the sprint round (100 = natural full sprint)
$ZSpeedSprintStepPct  = 1    # + sprint speed % per round AFTER the sprint round (the post-10 creep)
$zspeed = " +set acc_zspeed_sprint_round $ZSpeedSprintRound +set acc_zspeed_jog_start_pct $ZSpeedJogStartPct +set acc_zspeed_jog_step_pct $ZSpeedJogStepPct +set acc_zspeed_sprint_start_pct $ZSpeedSprintStartPct +set acc_zspeed_sprint_step_pct $ZSpeedSprintStepPct"

# THE GAMETYPE FIX (verified 2026-06-13): you MUST pass the engine command
# `+set_gametype zclassic`, NOT `+set g_gametype zclassic`. The g_gametype dvar
# is immediately reset to the session default by the engine
# (callbacks_shared.gsc), so a plain +set never survives -> the launch falls
# back to the MP default "tdm" -> scripts/zm/gametypes/tdm.gsc is missing ->
# fatal Com_ERROR -> black screen. `set_gametype` is the command the Mod Tools
# Launcher itself uses, and it sticks.
# Also keep BO3's Steam LAUNCH OPTIONS EMPTY (Steam appends them -> doubled
# command line -> the same tdm corruption).
#
# NOTE: custom LUI (ui/uieditor/menus/hud/acc_hud.lua) runs on Steam BO3 with NO
# special flag - verified 2026-06-13 (our menu executed in-game; a Lua bug in it
# threw "UI Error 43408", which proves it was NOT sandbox-blocked). The community
# "-unsafe-lua" arg is a BOIII-client flag, not a Steam BO3 one - on Steam it logs
# "Unknown command" and does nothing, so it is intentionally NOT passed here.
# (L3akMod is still required in the MOD TOOLS bin to BUILD the .lua. docs/28.)
$gameArgs = "+set fs_game zm_abandoned_cyber_city +set_gametype zclassic +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1$dev$openmap$boss$vdbg$audio$zspeed"

Write-Host "launching BO3 through Steam (DRM-safe): steam://run/311210"
Write-Host "args: $gameArgs"
Start-Process "steam://run/311210//$gameArgs"

# Wait for the game to come up (asset load takes ~30-60s; RAM climbs to ~5 GB).
for ($i = 0; $i -lt 18; $i++) {
    Start-Sleep -Seconds 5
    $p = Get-Process BlackOps3 -ErrorAction SilentlyContinue
    if ($p) {
        $gb = [math]::Round($p.WorkingSet64 / 1GB, 1)
        Write-Host ("  +{0,3}s  PID {1}  {2} GB  responding={3}" -f (($i + 1) * 5), $p.Id, $gb, $p.Responding)
        if ($gb -ge 4) { Write-Host "loaded - you should be in zm_abandoned_cyber_city. Press ~ for the [acc] console."; break }
    } else {
        Write-Host ("  +{0,3}s  not up yet" -f (($i + 1) * 5))
    }
}
