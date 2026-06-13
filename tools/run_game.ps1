# =============================================================================
# run_game.ps1 - launch the already-built map straight into the game.
#
# Why this exists: the Mod Tools Launcher's "Run" launches BlackOps3.exe
# DIRECTLY, which trips BO3's Steam DRM ("Steam must be running to play this
# game" popup, then exits) even with Steam running + steam_appid.txt present.
# Launching THROUGH Steam (steam://run/311210) gives the proper DRM context,
# so the game opens and loads the dev map. VERIFIED working 2026-06-12.
#
# Usage:  .\tools\run_game.ps1            (test boss on)
#         .\tools\run_game.ps1 -NoBoss    (no test boss)
# Build first (Launcher: Compile/Light/Link, or just Compile Scripts for GSC).
# Steam must be running and logged in.
# =============================================================================

param([switch]$NoBoss, [switch]$NoDev)

# acc_dev 1   = unlimited money, perk cap 18, buyable-door markers (the test sandbox)
# acc_test_boss 1 = Juggernaut Host from round 2, drops 10 Mega Bottles on death
$boss = if ($NoBoss) { "" } else { " +set acc_test_boss 1" }
$dev  = if ($NoDev)  { "" } else { " +set acc_dev 1" }
# IMPORTANT: BO3's Steam LAUNCH OPTIONS must be EMPTY, or Steam appends them to
# these args -> a doubled command line that corrupts the gametype (boots TDM ->
# tries scripts/zm/gametypes/tdm.gsc -> fatal Com_ERROR -> black screen). With a
# clean command line, a zm_* devmap auto-selects the zclassic zombies gametype.
$gameArgs = "+set fs_game zm_abandoned_cyber_city +devmap zm_abandoned_cyber_city +set developer 1 +set logfile 1$boss$dev"

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
