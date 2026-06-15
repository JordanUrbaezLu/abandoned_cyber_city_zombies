# =============================================================================
# deploy_perk_shaders.ps1 - deploy the custom perk-icon GDT + source images into
# the BO3 Mod Tools install, then refresh the GDT DB so the linker can find them.
#
# The main sync (sync_to_modtools.ps1) mirrors the USERMAP tree only; GDT assets
# live at the Mod Tools ROOT (source_data/), so they deploy via their own tool -
# same pattern as tools/apply_recoil_overhaul.js for the weapon-variant GDT.
#
# Deploys:
#   repo\source_data\acc_perk_shaders.gdt        -> <tools>\source_data\
#   repo\source_data\acc_perk_shaders\_images\*  -> <tools>\source_data\acc_perk_shaders\_images\
# then runs <tools>\gdtdb\gdtdb.exe /update.
#
# Usage (PowerShell, Windows):
#   .\tools\deploy_perk_shaders.ps1                       # auto-detect install
#   .\tools\deploy_perk_shaders.ps1 -ModToolsRoot "D:\...\Black Ops III 455130"
#   .\tools\deploy_perk_shaders.ps1 -SkipGdtDb            # copy only, no gdtdb
#
# Run this BEFORE the linker build. The linker does NOT update the GDT DB - skip
# gdtdb and you get "unable to locate asset in gdtdb for 'i_acc_perk_jugg_*'".
# =============================================================================

[CmdletBinding()]
param(
    [string]$ModToolsRoot = "",
    [switch]$SkipGdtDb
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[deploy-perk-shaders] $msg" }

function Resolve-ModToolsRoot {
    if ($ModToolsRoot -ne "") { return $ModToolsRoot }
    # Require bin\modlauncher.exe as proof of the tools root (the game folder
    # alone passes Test-Path but is NOT the tools root) - same as sync_to_modtools.
    $libRoots = @(
        "C:\Program Files (x86)\Steam\steamapps\common",
        "D:\Steam\steamapps\common",
        "E:\Steam\steamapps\common",
        "C:\Steam\steamapps\common"
    )
    foreach ($lib in $libRoots) {
        if (-not (Test-Path $lib)) { continue }
        $dirs = Get-ChildItem $lib -Directory -Filter "Call of Duty Black Ops III*" -ErrorAction SilentlyContinue
        foreach ($d in $dirs) {
            if (Test-Path (Join-Path $d.FullName "bin\modlauncher.exe")) { return $d.FullName }
        }
    }
    throw "Could not auto-detect the Mod Tools root (no folder with bin\modlauncher.exe). Pass -ModToolsRoot explicitly."
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ModTools = Resolve-ModToolsRoot

$srcGdt    = Join-Path $RepoRoot "source_data\acc_perk_shaders.gdt"
$srcImages = Join-Path $RepoRoot "source_data\acc_perk_shaders"
$dstSrcData = Join-Path $ModTools "source_data"
$dstGdt    = Join-Path $dstSrcData "acc_perk_shaders.gdt"
$dstImages = Join-Path $dstSrcData "acc_perk_shaders"

Write-Info "repo     = $RepoRoot"
Write-Info "modtools = $ModTools"

if (-not (Test-Path $srcGdt)) { throw "missing $srcGdt" }

# GDT
Copy-Item -Path $srcGdt -Destination $dstGdt -Force
Write-Info "gdt:    $srcGdt -> $dstGdt"

# source images (acc_perk_shaders\_images\*). Robocopy /E (no /MIR - never delete).
$rc = Start-Process robocopy -NoNewWindow -Wait -PassThru -ArgumentList @(
    "`"$srcImages`"", "`"$dstImages`"", "/E",
    "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/R:2", "/W:1"
)
if ($rc.ExitCode -ge 8) { throw "robocopy failed (images) with exit code $($rc.ExitCode)" }
Write-Info "images: $srcImages\_images\* -> $dstImages\_images\*"

# Refresh the GDT DB so the linker indexes the new image assets.
if ($SkipGdtDb) {
    Write-Info "SkipGdtDb set - remember to run gdtdb /update before linking."
} else {
    $gdtdb = Join-Path $ModTools "gdtdb\gdtdb.exe"
    if (Test-Path $gdtdb) {
        Write-Info "running gdtdb /update ..."
        Push-Location (Split-Path $gdtdb -Parent)
        try { & $gdtdb /update } finally { Pop-Location }
        Write-Info "gdt.db updated - safe to link now."
    } else {
        Write-Info "NOTE: gdtdb.exe not found at $gdtdb - run it manually before linking."
    }
}

Write-Info "done. Next: .\tools\sync_to_modtools.ps1 then build the .ff (Launcher or linker_modtools.exe)."
