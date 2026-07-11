# =============================================================================
# restore_machine.ps1 - ONE command to make a fresh machine (or a fresh clone on
# an existing machine) build-ready. Created by the 2026-07-10 asset-portability
# audit: previously the restore knowledge was scattered across ONBOARDING.md,
# SETUP_WINDOWS.md, manifest Link notes and agent memory - and several steps
# existed nowhere at all.
#
# Prereqs it does NOT install for you (see SETUP_WINDOWS.md / ONBOARDING.md):
#   - BO3 + Mod Tools installed via Steam (bin\modlauncher.exe present)
#   - Node.js on PATH
#   - L3akMod v1.0.4 DLL overwrite (checked below; manual download)
#   - Smart App Control OFF (checked below; blocks gdtdb.exe -> NOTHING builds)
#   - The private external-assets zip from a teammate (pass -ZipFile on first run)
#
# Order matters: the external-asset unpack seeds install-side pack content
# (incl. the Ronan perk-shader rip art) BEFORE the repo-side deploys overlay
# our tracked GDTs/images on top.
#
# Usage:
#   .\tools\restore_machine.ps1 -ZipFile C:\path\acc_external_assets.zip   # first run on a new machine
#   .\tools\restore_machine.ps1                                            # re-run anytime (idempotent)
# =============================================================================

[CmdletBinding()]
param(
    [string]$ModToolsRoot = "",
    [string]$ZipFile = ""
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) { Write-Host ""; Write-Host "=== [restore] $msg ===" -ForegroundColor Cyan }
function Write-Info($msg) { Write-Host "[restore] $msg" }

function Resolve-ModToolsRoot {
    if ($ModToolsRoot -ne "") { return $ModToolsRoot }
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
$warnings = @()

Write-Info "repo     = $RepoRoot"
Write-Info "modtools = $ModTools"

# --- 0. Windows environment gates (new-box lessons, 2026-07) ----------------
Write-Step "environment gates (TA_* env vars, Smart App Control)"

# The Treyarch tools 0xC0000005-crash with NO message unless TA_TOOLS_PATH /
# TA_GAME_PATH user env vars are set (trailing backslash is how the tools
# themselves write them). BOTH point at the TOOLS root — verified against the
# proven-working box's live registry 2026-07-10 (gdtdb resolves deffiles via
# TA_GAME_PATH, and deffiles exists only under the tools root; a game-folder
# value breaks it). Compare path-normalized (trim trailing '\', case-
# insensitive) so an existing correct value is never churned. Set BOTH the
# durable User scope AND the current process (red-team fix: User scope alone
# left the gdtdb runs later in THIS run without the vars on a fresh box).
foreach ($pair in @(
    @{ Name = "TA_TOOLS_PATH"; Value = ($ModTools + "\") },
    @{ Name = "TA_GAME_PATH";  Value = ($ModTools + "\") }
)) {
    $cur = [Environment]::GetEnvironmentVariable($pair.Name, "User")
    $curNorm = if ($null -eq $cur) { "" } else { $cur.TrimEnd("\").ToLowerInvariant() }
    $wantNorm = $pair.Value.TrimEnd("\").ToLowerInvariant()
    if ($curNorm -eq $wantNorm) {
        Write-Info "ok: $($pair.Name) already set"
    } else {
        [Environment]::SetEnvironmentVariable($pair.Name, $pair.Value, "User")
        Write-Info "SET $($pair.Name) = $($pair.Value) (was: '$cur')"
    }
    # Current process too, so this run's own gdtdb/tool children see them.
    Set-Item -Path ("Env:" + $pair.Name) -Value $pair.Value
}

# Smart App Control blocks gdtdb.exe -> cod2map/Radiant/linker all assert on a
# missing gdtDB\gdt.db and NOTHING builds. 0 = off, 1 = enforce, 2 = evaluation.
try {
    $sac = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" -ErrorAction Stop).VerifiedAndReputablePolicyState
    if ($null -ne $sac -and $sac -ne 0) {
        $warnings += "Smart App Control is ON (state=$sac) - it blocks gdtdb.exe so NOTHING builds. Turn it off: Windows Security > App & browser control > Smart App Control."
        Write-Info "WARN: Smart App Control state=$sac (must be 0/off)"
    } else {
        Write-Info "ok: Smart App Control off"
    }
} catch { Write-Info "note: could not read Smart App Control state (key absent = older Windows, fine)" }

# --- 1. External asset packs (licensed rips - NOT in git) -------------------
if ($ZipFile -ne "") {
    Write-Step "unpack external asset packs from $ZipFile"
    & (Join-Path $PSScriptRoot "unpack_external_assets.ps1") -ZipFile $ZipFile -ModToolsRoot $ModTools
} else {
    Write-Info "no -ZipFile given - skipping unpack (fine on an already-provisioned machine)"
}

Write-Step "check external asset packs (tools\check_external_assets.ps1)"
& (Join-Path $PSScriptRoot "check_external_assets.ps1") -ModToolsRoot $ModTools
if ($LASTEXITCODE -ne 0) {
    $warnings += "check_external_assets reported missing packs - builds will fail until they are installed (get the teammate zip; links in tools\external_assets_manifest.ps1 / ONBOARDING.md)."
}

# --- 2. Install-side patches no zip carries ---------------------------------
Write-Step "bin patches (converter_gdt_dirs _custom line, L3akMod check)"
& (Join-Path $PSScriptRoot "apply_bin_patches.ps1") -ModToolsRoot $ModTools
if ($LASTEXITCODE -ne 0) { $warnings += "apply_bin_patches found unresolved items (see above - likely the manual L3akMod DLL)." }

Write-Step "stock zbarriers.gdt PaP-model patch (tools\apply_pap_zbarrier_swap.ps1)"
$zb = Join-Path $PSScriptRoot "apply_pap_zbarrier_swap.ps1"
if (Test-Path $zb) {
    # try/catch: a throw in the child (layout drift, locked file) must become a
    # warning, not abort the whole restore (red-team fix).
    try {
        & $zb -ModToolsRoot $ModTools
        if ($LASTEXITCODE -ne 0) { $warnings += "apply_pap_zbarrier_swap failed - PaP machines will show the stock model." }
    } catch {
        $warnings += "apply_pap_zbarrier_swap threw: $($_.Exception.Message) - PaP machines may show the stock model."
    }
} else {
    Write-Info "skip: apply_pap_zbarrier_swap.ps1 not found"
}

# --- 3. Repo-owned content -> install ----------------------------------------
# try/catch on each deploy: a throw (locked file, robocopy >=8) becomes a warning
# so the restore still reaches the summary (red-team fix).
Write-Step "repo-owned source_data GDTs (tools\deploy_source_data.ps1)"
try {
    & (Join-Path $PSScriptRoot "deploy_source_data.ps1") -ModToolsRoot $ModTools -SkipGdtDb
} catch { $warnings += "deploy_source_data threw: $($_.Exception.Message)" }

Write-Step "perk-shader GDT + custom HUD art (tools\deploy_perk_shaders.ps1)"
$perkGdt = Join-Path $RepoRoot "source_data\acc_perk_shaders.gdt"
if (Test-Path $perkGdt) {
    # SkipGdtDb here; one combined gdtdb /update runs below.
    try {
        & (Join-Path $PSScriptRoot "deploy_perk_shaders.ps1") -ModToolsRoot $ModTools -SkipGdtDb
    } catch { $warnings += "deploy_perk_shaders threw: $($_.Exception.Message)" }
} else {
    Write-Info "skip: repo acc_perk_shaders.gdt missing (pre-2026-07-10 clone? git pull)"
}

# --- 4. Generated build inputs ----------------------------------------------
Write-Step "perk-glow FX (regenerate any missing share\raw\fx\acc\light\*.efx)"
$zone = Join-Path $RepoRoot "zone_source\zm_abandoned_cyber_city.zone"
$fxMissing = $false
if (Test-Path $zone) {
    Select-String -Path $zone -Pattern '^\s*fx,acc/light/(fx_perk_glow_[a-z0-9_]+)' | ForEach-Object {
        $name = $_.Matches[0].Groups[1].Value
        if (-not (Test-Path (Join-Path $ModTools ("share\raw\fx\acc\light\" + $name + ".efx")))) { $fxMissing = $true }
    }
}
if ($fxMissing) {
    $nodeCmd = Get-Command node -ErrorAction SilentlyContinue
    if ($null -eq $nodeCmd) {
        $warnings += "Node.js not on PATH - install it, then run: node tools\gen_perk_glow_fx.js (perk-glow .efx are missing)."
        Write-Info "WARN: node not found; perk-glow .efx still missing"
    } else {
        Write-Info "missing perk-glow .efx detected - running node tools\gen_perk_glow_fx.js"
        # Pass the resolved tools root (red-team fix: without the arg the JS falls
        # back to ITS OWN hardcoded default root, which can differ from $ModTools).
        Push-Location $RepoRoot
        try { node (Join-Path $PSScriptRoot "gen_perk_glow_fx.js") $ModTools } finally { Pop-Location }
        if ($LASTEXITCODE -ne 0) { $warnings += "gen_perk_glow_fx.js failed - zone fx,acc/light lines will not link." }
        # Re-run the missing check rather than trusting the exit code.
        $stillMissing = $false
        Select-String -Path $zone -Pattern '^\s*fx,acc/light/(fx_perk_glow_[a-z0-9_]+)' | ForEach-Object {
            $n = $_.Matches[0].Groups[1].Value
            if (-not (Test-Path (Join-Path $ModTools ("share\raw\fx\acc\light\" + $n + ".efx")))) { $stillMissing = $true }
        }
        if ($stillMissing) { $warnings += "perk-glow .efx STILL missing after regen - check node output above." }
    }
} else {
    Write-Info "ok: all zone-referenced perk-glow .efx present"
}

# --- 5. Main repo -> usermap sync + gdtdb ------------------------------------
Write-Step "repo -> Mod Tools sync (tools\sync_to_modtools.ps1)"
try {
    & (Join-Path $PSScriptRoot "sync_to_modtools.ps1") -ModToolsRoot $ModTools
} catch { $warnings += "sync_to_modtools threw: $($_.Exception.Message) - usermap may be stale (BO3 running / locked files?)" }

Write-Step "gdtdb /update"
$gdtdb = Join-Path $ModTools "gdtdb\gdtdb.exe"
if (Test-Path $gdtdb) {
    Push-Location (Split-Path $gdtdb -Parent)
    try { & $gdtdb /update } finally { Pop-Location }
    if ($LASTEXITCODE -ne 0) {
        $warnings += "gdtdb /update exited $LASTEXITCODE - db may be stale (SAC on? TA_* vars? see preflight)."
    } else {
        Write-Info "gdt.db updated"
    }
} else {
    $warnings += "gdtdb.exe not found - run <tools>\gdtdb\gdtdb.exe /update manually before building."
}

# --- summary -----------------------------------------------------------------
Write-Step "summary"
if ($warnings.Count -gt 0) {
    Write-Info "$($warnings.Count) item(s) still need attention:"
    $warnings | ForEach-Object { Write-Host "  ! $_" -ForegroundColor Yellow }
} else {
    Write-Info "machine restored - no outstanding items."
}
Write-Info "next: .\tools\build_map.ps1   (full build incl. LED bake)  then PLAY_TEST_MAP.bat"
if ($warnings.Count -gt 0) { exit 1 }
exit 0
