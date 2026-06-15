# =============================================================================
# check_external_assets.ps1 - pre-build gate: is every external (game-rip) asset
# pack present in the Mod Tools install?
#
# preflight_windows.ps1 checks the ENVIRONMENT (Mod Tools, L3akMod, sync); it does
# NOT check these packs. Without them the linker aborts with
# "ERROR: no file for filespec ..." (Brutus / Skye / Charred). Run this before a
# build to catch that early and get told exactly what's missing + where to get it.
#
# Usage (PowerShell, Windows):
#   .\tools\check_external_assets.ps1
#   .\tools\check_external_assets.ps1 -ModToolsRoot "D:\...\Black Ops III 455130"
#
# Exit 0 = all REQUIRED packs present (optional may warn). Exit 1 = a required
# pack is missing -> fix before building.
# =============================================================================

[CmdletBinding()]
param(
    [string]$ModToolsRoot = ''
)

$ErrorActionPreference = 'Continue'

. (Join-Path $PSScriptRoot 'external_assets_manifest.ps1')

try {
    $ModTools = Resolve-ModToolsRoot $ModToolsRoot
} catch {
    Write-Host "[FAIL] $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
Write-Host "modtools = $ModTools`n"

$fails = 0; $warns = 0
foreach ($pack in $ExternalAssetPacks) {
    $ok = Test-Path (Join-Path $ModTools $pack.Marker)
    if ($ok) {
        Write-Host "[PASS] $($pack.Name)" -ForegroundColor Green
    } elseif ($pack.Required) {
        $fails++
        Write-Host "[FAIL] $($pack.Name) - missing: $($pack.Marker)" -ForegroundColor Red
        Write-Host "       -> get it: $($pack.Link)" -ForegroundColor Red
        Write-Host "       -> or apply a teammate's zip: .\tools\unpack_external_assets.ps1 -ZipFile <zip>" -ForegroundColor Red
    } else {
        $warns++
        Write-Host "[WARN] $($pack.Name) (optional) - missing: $($pack.Marker)" -ForegroundColor Yellow
    }
}

Write-Host ''
if ($fails -gt 0) {
    Write-Host "$fails required pack(s) missing - the linker will throw 'no file for filespec'. Fix before building." -ForegroundColor Red
    exit 1
} elseif ($warns -gt 0) {
    Write-Host "All required packs present ($warns optional missing) - safe to build." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host 'All external asset packs present - safe to build.' -ForegroundColor Green
    exit 0
}
