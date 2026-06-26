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
#         .\tools\run_game.ps1 -NoLockdown  (sandbox, but no per-round red-alarm room lockdown)
# Build first (Launcher: Compile/Light/Link, or just Compile Scripts for GSC).
# Steam must be running and logged in.
# =============================================================================

param([switch]$NoBoss, [switch]$NoDev, [switch]$NoVarDebug, [switch]$ClosedMap, [switch]$NoAmbient, [switch]$NoLockdown)

# DEV: ONE flag (user 2026-06-22). +set acc_dev 1 turns on the WHOLE hardcoded dev sandbox - regular
# gameplay damage (NO god mode, NO auto power-on - flip the switch yourself), unlimited money, 25 starting
# Data Shards, Mega Bottles, OPEN MAP, ALL test bosses (Brutus/
# Glitch/Phantom), all perk slots, the weapon-variant debug readout, and the dev HUDs. The entry script's
# acc_resolve_dev_flags() drives every old sub-dvar off this one flag, so there are NO other dev flags to
# pass. -NoDev = clean normal play. Gameplay (audio / DEFCON lockdown / zombie-speed curve) runs on its
# in-code defaults now - not launch flags. (-NoBoss/-ClosedMap/-NoVarDebug/-NoAmbient/-NoLockdown remain in
# the param block for call compatibility but no longer affect the launch - dev is all-or-nothing by design.)
$dev = if ($NoDev) { "" } else { " +set acc_dev 1" }

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
# ONE dev flag: only $dev (+set acc_dev 1) is passed. acc_dev drives the whole sandbox (open map / bosses /
# god / perks / power / variant-debug) via acc_resolve_dev_flags(); gameplay (audio / lockdown / zombie-speed)
# runs on its in-code defaults. ($vdbg/$audio/$lockdown/$zspeed above are unused now - kept only so the
# -NoAmbient/-NoLockdown/-NoVarDebug params don't error; they no longer affect the launch.)
$gameArgs = "+set fs_game zm_abandoned_cyber_city +set_gametype zclassic +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1$dev"

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
