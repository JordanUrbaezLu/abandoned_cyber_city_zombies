# =============================================================================
# build_map.ps1 - ONE-COMMAND headless build of zm_abandoned_cyber_city.
#
# Why this exists: agents (and people) kept punting "compile the geometry" back
# to the user. The whole pipeline is CLI-scriptable on this box, so this script
# does it end to end - the user's only job is to launch + test the result.
#
#   .\tools\build_map.ps1            FULL geometry build (any .map / brush /
#                                    entity / material / sky change):
#                                    asset-gate -> sync -> cod2map64 (BSP+navmesh,
#                                    cwd=bin) -> Radiant LED -> linker -> verify .ff
#   .\tools\build_map.ps1 -GscOnly   FAST path for GSC/CSC/.zone/.csv-only changes:
#                                    asset-gate -> sync -> linker (reuses the last
#                                    cod2map64 BSP+navmesh). ~seconds, NOT valid if
#                                    any brush/entity/material moved.
#   .\tools\build_map.ps1 -Run       build, then launch run_game.ps1 on success.
#
# Other switches: -SkipSync (deployed copy already current), -SkipLED (geometry
# moved but lighting unchanged - LED is cheap insurance, usually leave it),
# -SkipAssetCheck, -Preflight (run the heavy preflight lints first), -DryRun,
# -ModToolsRoot <path> (override auto-detect).
#
# Exit 0 = a fresh .ff was written. Exit 1 = a stage failed (the failing stage's
# error lines are printed). Pipeline + gotchas verified against docs/36, docs/23,
# docs/BO3_MAPMAKING_KB.md, CLAUDE.md (the cwd=bin navmesh trap is handled here).
# =============================================================================

[CmdletBinding()]
param(
    [string]$ModToolsRoot = '',
    [switch]$GscOnly,
    [switch]$SkipSync,
    [switch]$SkipLED,
    [switch]$SkipAssetCheck,
    [switch]$Preflight,
    [switch]$Run,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$MapName  = 'zm_abandoned_cyber_city'
$RepoRoot = Split-Path $PSScriptRoot -Parent

# Known NON-FATAL linker 'ERROR:' substrings: assets the linker can't find but
# substitutes a default for, then still packs a valid .ff. These are user-waived
# and pre-existing (docs/32, docs/33). Match = report as info, NOT a build failure.
# The real success oracle is "a fresh .ff was written" (see the linker stage).
# NOTE (2026-06-15): the AE4 'iw7_efx_plasma_muz_flash' muzzle FX + the Ripper shell-
# eject FX were FIXED install-side (docs/33 "FIX APPLIED - AE4 + Ripper FX"), so they
# are intentionally NOT waived here - if either recurs it should surface as UNEXPECTED.
$WaivedLinkerErrors = @(
    'mtl_origins_camo_alt'       # BO2-Origins Five-Seven PaP camo, unbundled (docs/32)
)

# Reuse the shared bin\modlauncher.exe-based root detection (never folder name).
. (Join-Path $PSScriptRoot 'external_assets_manifest.ps1')

function Info($m) { Write-Host "[build] $m" -ForegroundColor Cyan }
function Step($m) { Write-Host ""; Write-Host "[build] === $m ===" -ForegroundColor White }
function Warn($m) { Write-Host "[build] WARN: $m" -ForegroundColor Yellow }
function Die($m)  { Write-Host ""; Write-Host "[build] FAIL: $m" -ForegroundColor Red; exit 1 }

# --- resolve tools root + exe paths ----------------------------------------
try { $Tools = Resolve-ModToolsRoot $ModToolsRoot } catch { Die $_.Exception.Message }
$Bin     = Join-Path $Tools 'bin'
$Cod2    = Join-Path $Bin 'cod2map64.exe'
$Radiant = Join-Path $Bin 'Radiant_modtools.exe'
$Linker  = Join-Path $Bin 'linker_modtools.exe'
$MapSrc  = Join-Path $Tools ("map_source\zm\{0}.map"        -f $MapName)
$Bsp     = Join-Path $Tools ("share\raw\maps\zm\{0}.d3dbsp" -f $MapName)
$NavHkt  = Join-Path $Tools ("share\raw\maps\zm\{0}_navmesh.hkt" -f $MapName)
$FfDir   = Join-Path $Tools ("usermaps\{0}\zone" -f $MapName)
$RepoMap = Join-Path $RepoRoot ("map_source\zm\{0}.map" -f $MapName)

Info "mod tools root = $Tools"
Info ("mode = {0}{1}" -f $(if ($GscOnly) { 'GSC-ONLY (linker only)' } else { 'FULL geometry (cod2map64 + LED + linker)' }), $(if ($DryRun) { '  [DRY RUN]' } else { '' }))
foreach ($e in @($Cod2, $Radiant, $Linker)) {
    if (-not (Test-Path $e)) { Die "missing compiler exe: $e" }
}

# --- native-exe runner: capture stdout/stderr to temp files (avoids the PS 5.1
#     NativeCommandError wrapping that happens with 2>&1 on a native exe) ------
function Invoke-BuildExe($exe, [string[]]$argList, $label, $workDir) {
    Info ("{0}: {1} {2}" -f $label, (Split-Path $exe -Leaf), ($argList -join ' '))
    if ($DryRun) { Info "  DRY: not executed"; return [pscustomobject]@{ Code = 0; Out = ''; Err = '' } }
    $o  = New-TemporaryFile
    $er = New-TemporaryFile
    try {
        $p = Start-Process -FilePath $exe -ArgumentList $argList -WorkingDirectory $workDir `
                 -NoNewWindow -Wait -PassThru -RedirectStandardOutput $o.FullName -RedirectStandardError $er.FullName
        $out = Get-Content $o.FullName -Raw -ErrorAction SilentlyContinue
        $err = Get-Content $er.FullName -Raw -ErrorAction SilentlyContinue
    } finally {
        Remove-Item $o.FullName, $er.FullName -ErrorAction SilentlyContinue
    }
    return [pscustomobject]@{ Code = $p.ExitCode; Out = [string]$out; Err = [string]$err }
}

# Quote a path arg for Start-Process ArgumentList (it joins items with spaces).
function Q($p) { '"' + $p + '"' }

# ===========================================================================
# 0. preflight (opt-in; the documented step-0 lint gate, but heavy)
# ===========================================================================
if ($Preflight) {
    Step "preflight lints"
    & (Join-Path $PSScriptRoot 'preflight_windows.ps1')
    if ($LASTEXITCODE -ne 0) { Die "preflight reported failures (exit $LASTEXITCODE) - fix before building, or skip with no -Preflight" }
}

# ===========================================================================
# 1. external-asset gate (the linker throws 'no file for filespec' without them)
# ===========================================================================
if (-not $SkipAssetCheck) {
    Step "external-asset gate"
    & (Join-Path $PSScriptRoot 'check_external_assets.ps1') -ModToolsRoot $Tools
    if ($LASTEXITCODE -ne 0) { Die "a required external asset pack is missing (see above) - the linker would fail 'no file for filespec'" }
}

# ===========================================================================
# 2. sync repo -> Mod Tools (linker builds the DEPLOYED copy; cod2map64 reads
#    the deployed map_source copy - skipping this silently builds STALE code)
# ===========================================================================
if (-not $SkipSync) {
    Step "sync repo -> Mod Tools"
    if ($DryRun) {
        & (Join-Path $PSScriptRoot 'sync_to_modtools.ps1') -ModToolsRoot $Tools -DryRun
    } else {
        & (Join-Path $PSScriptRoot 'sync_to_modtools.ps1') -ModToolsRoot $Tools
        # Confirm the deployed .map actually picked up the repo edit (the hours-lost trap).
        if ((Test-Path $RepoMap) -and (Test-Path $MapSrc)) {
            $rh = (Get-FileHash $RepoMap).Hash
            $dh = (Get-FileHash $MapSrc).Hash
            if ($rh -eq $dh) { Info "deployed .map hash matches repo (sync OK)" }
            else { Die "deployed map_source .map does NOT match repo after sync (repo=$rh deployed=$dh) - aborting before a stale build" }
        }
    }
} else {
    Warn "-SkipSync: building whatever is already deployed (not re-copying the repo)"
}

# ===========================================================================
# 3. cod2map64 - BSP + navmesh (FULL builds only). MUST run with cwd = bin or
#    navmesh gen aborts while still writing the .d3dbsp (silent stale-navmesh).
# ===========================================================================
if (-not $GscOnly) {
    Step "cod2map64 (BSP + navmesh + navvolume)  [cwd = bin]"
    $bspDir = Split-Path $Bsp -Parent
    if (-not (Test-Path $bspDir) -and -not $DryRun) { New-Item -ItemType Directory -Path $bspDir -Force | Out-Null }

    $cod2Args = @('-platform', 'pc', '-navmesh', '-navvolume', '-loadFrom', (Q $MapSrc), (Q $Bsp))
    $r = Invoke-BuildExe $Cod2 $cod2Args 'cod2map64' $Bin

    if (-not $DryRun) {
        # THE load-bearing check: this string means navmesh did NOT regenerate
        # (zombies would path the OLD footprint). The .d3dbsp still writes, so an
        # exit-code-only check would miss it. Treat as fatal.
        if ($r.Out -match 'Unable to load navigation mesh generation settings' -or $r.Err -match 'Unable to load navigation mesh generation settings') {
            Write-Host $r.Out
            Die "cod2map64 could not load navmesh settings (cwd was not bin?) - navmesh is STALE; refusing to continue"
        }
        if ($r.Code -ne 0) { Write-Host $r.Out; Write-Host $r.Err; Die "cod2map64 exited $($r.Code)" }
        if (-not (Test-Path $Bsp)) { Die "cod2map64 produced no .d3dbsp at $Bsp" }
        Info ("BSP written: {0:N1} MB @ {1}" -f ((Get-Item $Bsp).Length / 1MB), (Get-Item $Bsp).LastWriteTime)
        if (Test-Path $NavHkt) { Info ("navmesh.hkt updated @ {0}" -f (Get-Item $NavHkt).LastWriteTime) }
        else { Warn "no _navmesh.hkt found at $NavHkt (ground zombies may not path)" }
        # 'NavVolume generation is skipped' / 0-byte navvolume.hkt is HARMLESS (ground-only map).
    }

    # =======================================================================
    # 4. Radiant LED lighting recompute (geometry/light changes)
    # =======================================================================
    if (-not $SkipLED) {
        Step "Radiant LED (lighting recompute)"
        # ⚠️ LED is a DEAD END for the current enclosed-vault geometry on this install.
        # Verified exhaustively 2026-06-15: Radiant's lightmapper SANITY CHECK FAILUREs
        # (brush.cpp:1860 -> Device.cpp:395 pDevice -> ProbeInst/GfxFrustumRegister cascade)
        # in the GUI Launcher AND headless, with +localprobes ON and OFF, with BO3 running
        # and closed. Same lightmapper limitation that shelved the lab ceilings (docs/36/38).
        # => BUILD THIS MAP WITH -SkipLED. Darkness is delivered by a per-player vision tint
        # in-zone (docs/37 §11), NOT a baked lightmap. Fixes already applied so LED can be
        # retried IF the vault ceiling/seals are ever removed: +localprobes dropped (fragile
        # GPU pass) and the 7 reflection_probe boxes' inverted Y (size_min>size_max) corrected.
        $radArgs = @('-ledSilent', '+medium', '+forceclean', '+recompute', (Q $MapSrc))
        $r = Invoke-BuildExe $Radiant $radArgs 'Radiant LED' $Bin
        if (-not $DryRun -and $r.Code -ne 0) { Write-Host $r.Out; Warn "Radiant LED exited $($r.Code) (continuing - lighting may be stale, geometry/scripts are unaffected)" }
    } else {
        Warn "-SkipLED: lighting not recomputed"
    }
} else {
    Warn "-GscOnly: skipping cod2map64 + LED (reusing the last BSP + navmesh). Invalid if any brush/entity/material moved."
}

# ===========================================================================
# 5. linker - compile GSC + pack the .ff (reuses the fresh BSP/navmesh)
# ===========================================================================
Step "linker (compile GSC + pack .ff)"
$ffBefore = $null
if (Test-Path $FfDir) { $ffBefore = Get-ChildItem $FfDir -Filter "$MapName.ff" -ErrorAction SilentlyContinue | Select-Object -First 1 }

$linkArgs = @('-language', 'english', '-modsource', $MapName)
$r = Invoke-BuildExe $Linker $linkArgs 'linker' $Bin

if (-not $DryRun) {
    # Collect real error lines (strip ^1/^3 color codes). The wall of "Could not
    # find material/fx ..." is NORMAL usermap noise; only ERROR: / filespec /
    # unresolved lines matter here.
    $allOut   = "$($r.Out)`n$($r.Err)"
    $errLines = @($allOut -split "\r?\n" |
        ForEach-Object { ($_ -replace '\^\d', '').Trim() } |
        Where-Object { $_ -match 'ERROR:' -or $_ -match 'no file for filespec' -or $_ -match 'Unresolved external' })

    # SUCCESS ORACLE = a FRESH .ff was written. The linker emits ERROR: for
    # missing-but-substituted assets (the waived camo/FX materials), exits
    # nonzero, yet still packs a valid .ff. A truly fatal error (unresolved GSC,
    # missing required model) aborts BEFORE the .ff is packed, so its timestamp
    # does NOT advance. Exit code alone is unreliable - trust the fastfile.
    $ffAfter = $null
    if (Test-Path $FfDir) {
        $ffAfter = Get-ChildItem $FfDir -Filter "$MapName.ff" -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $ffAfter) { $ffAfter = Get-ChildItem $FfDir -Filter '*.ff' | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
    }
    $freshFf = $ffAfter -and ( (-not $ffBefore) -or ($ffAfter.LastWriteTime -gt $ffBefore.LastWriteTime) )

    if (-not $freshFf) {
        # Genuine failure: no fresh fastfile was produced.
        if ($errLines.Count -gt 0) {
            Write-Host "[build] linker errors (aborted before packing the .ff):" -ForegroundColor Red
            $errLines | Select-Object -First 25 | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        } else {
            ($allOut -split "\r?\n" | Select-Object -Last 20) | ForEach-Object { Write-Host "  $_" }
        }
        Die "linker did not produce a fresh .ff (exit $($r.Code))"
    }

    # Fresh .ff exists -> usable build. Split known-waived asset errors (info) from
    # NEW/unexpected ones (warn loudly - a genuinely missing asset to look at).
    $unexpected = @($errLines | Where-Object { $l = $_; -not ($WaivedLinkerErrors | Where-Object { $l -match [regex]::Escape($_) }) })
    $waived     = @($errLines | Where-Object { $l = $_;     ($WaivedLinkerErrors | Where-Object { $l -match [regex]::Escape($_) }) })

    if ($waived.Count -gt 0) {
        Info "$($waived.Count) known-waived asset warning(s) (non-fatal, default-substituted):"
        $waived | Sort-Object -Unique | ForEach-Object { Write-Host "    - $_" -ForegroundColor DarkGray }
    }
    if ($unexpected.Count -gt 0) {
        Warn "$($unexpected.Count) UNEXPECTED linker error(s) - a .ff WAS produced, but verify (asset may be missing in-game):"
        $unexpected | Select-Object -First 25 | ForEach-Object { Write-Host "    ! $_" -ForegroundColor Yellow }
    }

    Step "BUILD OK"
    Info ("fastfile: {0}" -f $ffAfter.FullName)
    Info ("size:     {0:N2} MB" -f ($ffAfter.Length / 1MB))
    Info ("written:  {0}" -f $ffAfter.LastWriteTime)
    Write-Host ""
    Write-Host "[build] READY TO TEST -> .\tools\run_game.ps1   (test boss spawns from round 2; real Brutus round 4)" -ForegroundColor Green
}

# ===========================================================================
# 6. optional launch
# ===========================================================================
if ($Run -and -not $DryRun) {
    Step "launching game (run_game.ps1)"
    & (Join-Path $PSScriptRoot 'run_game.ps1')
}

exit 0
