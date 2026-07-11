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

# Deep path test (red-team 2026-07-10): the Marker alone proved too weak — a
# dangling wildcard or a single missing file (e.g. one of two music wavs) passed
# the gate while pack/build still broke. Same wildcard semantics as
# pack_external_assets.ps1's Stage-Path.
function Test-PackPath($relPattern) {
    if ($relPattern -match '[\*\?]') {
        $parentRel = Split-Path $relPattern -Parent
        $leaf      = Split-Path $relPattern -Leaf
        $srcParent = Join-Path $ModTools $parentRel
        if (-not (Test-Path $srcParent)) { return $false }
        return (@(Get-ChildItem -LiteralPath $srcParent -Filter $leaf -ErrorAction SilentlyContinue).Count -gt 0)
    }
    return (Test-Path (Join-Path $ModTools $relPattern))
}

$fails = 0; $warns = 0
foreach ($pack in $ExternalAssetPacks) {
    $ok = Test-Path (Join-Path $ModTools $pack.Marker)
    $deadPaths = @()
    if ($ok) {
        foreach ($p in $pack.Paths) {
            if (-not (Test-PackPath $p)) { $deadPaths += $p }
        }
    }
    if ($ok -and $deadPaths.Count -eq 0) {
        Write-Host "[PASS] $($pack.Name)" -ForegroundColor Green
    } elseif ($ok) {
        # Marker present but some Paths resolve to nothing: incomplete install OR a
        # stale manifest entry - either way the next pack/unpack silently drops them.
        if ($pack.Required) { $fails++ } else { $warns++ }
        $tag = if ($pack.Required) { '[FAIL]' } else { '[WARN]' }
        $col = if ($pack.Required) { 'Red' } else { 'Yellow' }
        Write-Host "$tag $($pack.Name) - marker ok but $($deadPaths.Count) Paths entr$(if ($deadPaths.Count -eq 1) {'y'} else {'ies'}) match NOTHING:" -ForegroundColor $col
        $deadPaths | ForEach-Object { Write-Host "       -> $_" -ForegroundColor $col }
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
