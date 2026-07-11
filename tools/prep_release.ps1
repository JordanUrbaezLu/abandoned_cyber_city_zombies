# =============================================================================
# prep_release.ps1 - ONE-COMMAND Steam Workshop RELEASE-READINESS gate + build.
#
# What it does (in order):
#   1. external-asset gate  (calls check_external_assets.ps1 - hard gate)
#   2. perk-shader deploy   (only with -DeployPerkShaders; idempotent)
#   3. FULL build           (calls build_map.ps1 - cod2map64 + LED + linker)   [skip: -NoBuild]
#   4. fast-file check       (a fresh, non-corrupt .ff exists in the usermap)
#   4b. LED-bake check        (lightmaps fresh: .led NEWER than .d3dbsp - catches the
#                              brush.cpp:1860 bake crash that build_map only WARNs about)
#   5. workshop.json check   (release metadata present + not still "dev build")
#   6. presentation check    (thumbnail 512x512, >=5 screenshots)
#   7. IP / CREDITS check     (the per-asset clearance gate for going PUBLIC)
# then prints a TWO-TRACK verdict + the MANUAL Launcher publish steps.
#
# What it DELIBERATELY does NOT do (by design - "don't break anything"):
#   - It NEVER publishes to Steam. The upload is a manual Launcher action tied to
#     your Steam session (File -> Publish Mod/Map). This script only gets you ready.
#   - It NEVER edits game code, geometry, GDT, or assets. It calls the SAME build
#     pipeline you already run (build_map.ps1) and otherwise only READS files.
#   - It NEVER flips visibility. Private vs Public is chosen in the Launcher dialog.
#
# Usage (PowerShell, Windows):
#   .\tools\prep_release.ps1                 # full check + FULL build, then verdict
#   .\tools\prep_release.ps1 -NoBuild        # readiness report only (no rebuild)
#   .\tools\prep_release.ps1 -Public         # treat PUBLIC-release blockers as FAILURES
#   .\tools\prep_release.ps1 -DeployPerkShaders   # also (re)deploy the perk-icon GDT
#   .\tools\prep_release.ps1 -ModToolsRoot "D:\...\Black Ops III 455130"
#
# Exit 0 = TRACK A (private dev publish) is ready (build OK + metadata sane).
# Exit 1 = a hard blocker failed (or, with -Public, a public-release blocker failed).
# Full procedure + the IP sign-off process: docs/34_release_runbook.md.
# =============================================================================

[CmdletBinding()]
param(
    [string]$ModToolsRoot = '',
    [switch]$NoBuild,
    [switch]$Public,
    [switch]$DeployPerkShaders,
    [switch]$SkipAssetCheck
)

$ErrorActionPreference = 'Stop'
$MapName  = 'zm_abandoned_cyber_city'
$RepoRoot = Split-Path $PSScriptRoot -Parent

# Reuse the shared bin\modlauncher.exe-based root detection (never folder name)
# + the external-pack manifest (authors feed the IP check below).
. (Join-Path $PSScriptRoot 'external_assets_manifest.ps1')

# --- pretty output ----------------------------------------------------------
function Info($m) { Write-Host "[release] $m" -ForegroundColor Cyan }
function Step($m) { Write-Host ""; Write-Host "[release] === $m ===" -ForegroundColor White }
function Die($m)  { Write-Host ""; Write-Host "[release] FATAL: $m" -ForegroundColor Red; exit 1 }

# --- result ledger ----------------------------------------------------------
# Each gate records a result. Track:
#   'any'    = blocks ANY publish (even a private dev build) -> always fatal
#   'public' = blocks only a PUBLIC v1.0 release -> fatal only with -Public, else WARN
#   'info'   = nice-to-have / informational
$script:Results = @()
function Record($name, $state, $track, $detail) {
    # state: PASS | WARN | FAIL
    $script:Results += [pscustomobject]@{ Name = $name; State = $state; Track = $track; Detail = $detail }
    $color = switch ($state) { 'PASS' { 'Green' } 'WARN' { 'Yellow' } 'FAIL' { 'Red' } default { 'Gray' } }
    Write-Host ("  [{0}] {1}" -f $state, $name) -ForegroundColor $color
    if ($detail) { Write-Host ("        {0}" -f $detail) -ForegroundColor DarkGray }
}

# --- resolve tools root -----------------------------------------------------
try { $Tools = Resolve-ModToolsRoot $ModToolsRoot } catch { Die $_.Exception.Message }
$FfDir = Join-Path $Tools ("usermaps\{0}\zone" -f $MapName)
$BspPath = Join-Path $Tools ("share\raw\maps\zm\{0}.d3dbsp" -f $MapName)
$LedPath = Join-Path $Tools ("share\raw\maps\zm\{0}.led" -f $MapName)
$ZoneDir = Join-Path $RepoRoot 'zone'

Info "mod tools root = $Tools"
Info ("mode = {0}{1}" -f $(if ($NoBuild) { 'CHECK-ONLY (no build)' } else { 'CHECK + FULL BUILD' }), $(if ($Public) { '  [PUBLIC gate: strict]' } else { '' }))

# read a PNG's width/height from its IHDR (no System.Drawing dependency).
function Get-PngSize($path) {
    try {
        $b = [System.IO.File]::ReadAllBytes($path)
        if ($b.Length -lt 24) { return $null }
        # PNG sig = 89 50 4E 47; IHDR width @ 16..19, height @ 20..23 (big-endian)
        if ($b[0] -ne 0x89 -or $b[1] -ne 0x50) { return $null }
        $w = ([int]$b[16] -shl 24) -bor ([int]$b[17] -shl 16) -bor ([int]$b[18] -shl 8) -bor [int]$b[19]
        $h = ([int]$b[20] -shl 24) -bor ([int]$b[21] -shl 16) -bor ([int]$b[22] -shl 8) -bor [int]$b[23]
        return [pscustomobject]@{ W = $w; H = $h }
    } catch { return $null }
}

# ===========================================================================
# 0. ship-safe flag gate - the dev/god hardcode MUST be flipped back to the
#    dvar resolution before ANY publish (review fix 2026-07-08: the temporary
#    `level.acc_dev = true` / `level.acc_god = true` test hardcodes in
#    acc_resolve_dev_flags() ship an invulnerable full-dev build, and nothing
#    else in this script looked at that line).
# ===========================================================================
Step "ship-safe flags (acc_dev / acc_god not hardcoded)"
$entryGsc = Join-Path $RepoRoot "scripts\zm\$MapName.gsc"
if (-not (Test-Path $entryGsc)) {
    Record 'ship-safe flags' 'WARN' 'any' "entry script not found at $entryGsc - cannot verify"
} else {
    $entrySrc = Get-Content $entryGsc -Raw
    # an ACTIVE (uncommented) hardcode of either flag to a truthy literal
    $hardcoded = @([regex]::Matches($entrySrc, '(?m)^\s*level\.acc_(dev|god)\s*=\s*(true|1)\s*;') | ForEach-Object { $_.Groups[1].Value })
    if ($hardcoded.Count -gt 0) {
        Record 'ship-safe flags' 'FAIL' 'any' ("HARDCODED ON in acc_resolve_dev_flags(): {0} - restore the getdvarint() resolution (default 0) before publishing" -f (($hardcoded | Sort-Object -Unique) -join ', '))
    } else {
        Record 'ship-safe flags' 'PASS' 'any' 'acc_dev / acc_god resolve from dvars (ship-safe default 0)'
    }
}

# ===========================================================================
# 1. external-asset gate (linker throws 'no file for filespec' without them)
# ===========================================================================
Step "external-asset gate"
if ($SkipAssetCheck) {
    Record 'external asset packs' 'WARN' 'any' '-SkipAssetCheck: not verified (the build may filespec-fail)'
} else {
    & (Join-Path $PSScriptRoot 'check_external_assets.ps1') -ModToolsRoot $Tools | Out-Host
    if ($LASTEXITCODE -ne 0) {
        Record 'external asset packs' 'FAIL' 'any' 'a required pack is missing - see above; install before building'
    } else {
        Record 'external asset packs' 'PASS' 'any' 'all required game-rip packs installed in the Mod Tools'
    }
}

# ===========================================================================
# 2. perk-shader deploy (opt-in; the marker is already verified by gate 1)
# ===========================================================================
if ($DeployPerkShaders) {
    Step "perk-shader deploy (source_data GDT -> Mod Tools root + gdtdb /update)"
    & (Join-Path $PSScriptRoot 'deploy_perk_shaders.ps1') -ModToolsRoot $Tools | Out-Host
    if ($LASTEXITCODE -ne 0) { Record 'perk-shader deploy' 'WARN' 'info' 'deploy returned nonzero - check above' }
    else { Record 'perk-shader deploy' 'PASS' 'info' 'perk-icon GDT deployed + gdtdb refreshed' }
}

# ===========================================================================
# 3. FULL build (the real correctness gate) - calls build_map.ps1 unchanged
# ===========================================================================
if (-not $NoBuild) {
    Step "FULL build (build_map.ps1: sync -> cod2map64 -> LED bake -> linker)"
    Info "this is the standard pipeline (NO -SkipLED) - close BO3 first if it is running"
    & (Join-Path $PSScriptRoot 'build_map.ps1') -ModToolsRoot $Tools
    if ($LASTEXITCODE -ne 0) {
        Record 'full build' 'FAIL' 'any' 'build_map.ps1 did not produce a fresh .ff (see its output above)'
    } else {
        Record 'full build' 'PASS' 'any' 'build_map.ps1 reported a fresh .ff'
    }
} else {
    Record 'full build' 'WARN' 'any' '-NoBuild: skipped; verifying the EXISTING .ff only (rebuild for a real release)'
}

# ===========================================================================
# 4. fast-file check - a fresh, non-corrupt .ff exists for the Launcher to ship
# ===========================================================================
Step "fast-file (.ff) check"
$ff = $null
if (Test-Path $FfDir) {
    $ff = Get-ChildItem $FfDir -Filter "$MapName.ff" -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $ff) {
    Record 'fast file' 'FAIL' 'any' "no $MapName.ff in $FfDir - run a build first"
} elseif (($ff.Length / 1MB) -lt 1) {
    Record 'fast file' 'FAIL' 'any' ("$($ff.Name) is only {0:N2} MB - likely a corrupt/partial build (build while game running?)" -f ($ff.Length / 1MB))
} else {
    $ageH = ((Get-Date) - $ff.LastWriteTime).TotalHours
    $st = if ($ageH -gt 48) { 'WARN' } else { 'PASS' }
    Record 'fast file' $st 'any' ("{0}  {1:N1} MB  written {2}{3}" -f $ff.Name, ($ff.Length / 1MB), $ff.LastWriteTime, $(if ($ageH -gt 48) { '  (stale >48h - rebuild for release)' } else { '' }))
}

# ===========================================================================
# 4b. LED lightmap bake (freshness) - build_map.ps1 only WARNs if the Radiant LED
#     bake crashes (brush.cpp:1860 / access violation) and still packs a .ff with
#     STALE lightmaps. CLAUDE.md: "never ship a change that fails the bake." Oracle
#     (memory fullbright-ff-stale-led-vs-bsp): the .led must be NEWER than the .d3dbsp.
# ===========================================================================
Step "LED lightmap bake (freshness)"
if (-not (Test-Path $BspPath) -or -not (Test-Path $LedPath)) {
    Record 'LED bake' 'WARN' 'public' "could not find both .led and .d3dbsp under share\raw\maps\zm to compare"
} else {
    $bspT = (Get-Item $BspPath).LastWriteTime
    $ledT = (Get-Item $LedPath).LastWriteTime
    if ($ledT -ge $bspT) {
        Record 'LED bake' 'PASS' 'public' ("lightmaps fresh (.led {0} >= .d3dbsp {1})" -f $ledT, $bspT)
    } else {
        Record 'LED bake' 'FAIL' 'public' ("STALE lightmaps - .led ({0}) is OLDER than .d3dbsp ({1}): the Radiant LED bake did NOT regenerate (brush.cpp:1860 crash). The .ff is fullbright/stale. Per CLAUDE.md, FIX or revert the regressing geometry before shipping." -f $ledT, $bspT)
    }
}

# ===========================================================================
# 5. workshop.json - release metadata present and not still a dev placeholder
# ===========================================================================
Step "workshop.json (publish metadata)"
$wsPath = Join-Path $ZoneDir 'workshop.json'
if (-not (Test-Path $wsPath)) {
    Record 'workshop.json' 'WARN' 'public' "no zone\workshop.json yet (the Launcher creates one on first publish; a prepared template ships in the repo)"
} else {
    $ws = $null
    try { $ws = Get-Content $wsPath -Raw | ConvertFrom-Json } catch { }
    if (-not $ws) {
        Record 'workshop.json' 'FAIL' 'any' "zone\workshop.json is not valid JSON"
    } else {
        $missing = @()
        foreach ($f in @('Title', 'Description', 'FolderName', 'Tags', 'Type')) {
            if (-not $ws.PSObject.Properties.Name.Contains($f) -or [string]::IsNullOrWhiteSpace([string]$ws.$f)) { $missing += $f }
        }
        if ($missing.Count -gt 0) {
            Record 'workshop.json fields' 'FAIL' 'any' ("missing/empty: {0}" -f ($missing -join ', '))
        } else {
            Record 'workshop.json fields' 'PASS' 'any' ("Title='{0}'  Tags='{1}'  Type='{2}'" -f $ws.Title, $ws.Tags, $ws.Type)
        }
        # FolderName + Type sanity
        if ($ws.FolderName -ne $MapName) { Record 'workshop.json FolderName' 'WARN' 'any' ("FolderName='{0}' (expected '{1}')" -f $ws.FolderName, $MapName) }
        if ($ws.Tags -notmatch 'Zombies') { Record 'workshop.json Tags' 'WARN' 'public' "Tags should include 'Zombies' (recommended: 'Map,Zombies')" }
        # dev-build text must be rewritten before going Public
        $devText = ($ws.Title -match '(?i)dev build') -or ($ws.Description -match '(?i)dev build|not for public')
        if ($devText) {
            Record 'workshop.json copy' 'WARN' 'public' "Title/Description still reads 'dev build / not for public' - rewrite for a Public release"
        } else {
            Record 'workshop.json copy' 'PASS' 'public' 'release-ready Title/Description (no dev-build placeholder text)'
        }
        # PublisherID empty = first publish will create the item (expected, informational)
        if ([string]::IsNullOrWhiteSpace([string]$ws.PublisherID)) {
            Record 'workshop.json PublisherID' 'WARN' 'info' "empty - the FIRST publish creates the item; then run sync_to_modtools.ps1 -Reverse + commit it so future publishes UPDATE the same item"
        } else {
            Record 'workshop.json PublisherID' 'PASS' 'info' ("PublisherID={0} (updates the existing Workshop item)" -f $ws.PublisherID)
        }
    }
}

# ===========================================================================
# 6. presentation assets - thumbnail + screenshots
# ===========================================================================
Step "presentation assets (thumbnail + screenshots)"
$thumb = Join-Path $ZoneDir 'previewimage.png'
if (-not (Test-Path $thumb)) {
    Record 'thumbnail' 'FAIL' 'public' "no zone\previewimage.png"
} else {
    $sz = Get-PngSize $thumb
    if ($sz -and $sz.W -eq 512 -and $sz.H -eq 512) {
        Record 'thumbnail' 'PASS' 'public' "previewimage.png is 512x512"
    } elseif ($sz) {
        Record 'thumbnail' 'WARN' 'public' ("previewimage.png is {0}x{1} - Steam recommends 512x512 for a crisp Workshop thumbnail" -f $sz.W, $sz.H)
    } else {
        Record 'thumbnail' 'WARN' 'public' "previewimage.png present (could not read size)"
    }
}
# screenshots: zone\screenshot_*.png (any case) or a zone\screenshots\ folder
$shots = @()
$shots += Get-ChildItem $ZoneDir -Filter 'screenshot*.png' -ErrorAction SilentlyContinue
$shotDir = Join-Path $ZoneDir 'screenshots'
if (Test-Path $shotDir) { $shots += Get-ChildItem $shotDir -Filter '*.png' -ErrorAction SilentlyContinue }
if ($shots.Count -ge 5) {
    Record 'screenshots' 'PASS' 'public' ("{0} screenshot(s) found" -f $shots.Count)
} else {
    Record 'screenshots' 'WARN' 'public' ("{0} screenshot(s) found - Steam Workshop pages want 5-10 (1920x1080). Capture in-game, save as zone\screenshot_NN_*.png" -f $shots.Count)
}

# ===========================================================================
# 7. IP / CREDITS review - the gate for going PUBLIC (CLAUDE.md hard constraint)
# ===========================================================================
Step "IP / licensing review (CREDITS.md)"
$creditsPath = Join-Path $RepoRoot 'CREDITS.md'
if (-not (Test-Path $creditsPath)) {
    Record 'CREDITS.md' 'FAIL' 'public' 'CREDITS.md not found'
} else {
    $credits = Get-Content $creditsPath -Raw
    # Machine-readable gate marker. Flip 'INCOMPLETE' -> 'COMPLETE' in CREDITS.md
    # once every game-rip asset's author is credited + clearance resolved.
    if ($credits -match '(?i)IP REVIEW STATUS:\s*INCOMPLETE') {
        Record 'IP review status' 'FAIL' 'public' "CREDITS.md says 'IP REVIEW STATUS: INCOMPLETE' - resolve every game-rip clearance + credit, then flip the marker to COMPLETE"
    } elseif ($credits -match '(?i)IP REVIEW STATUS:\s*COMPLETE') {
        Record 'IP review status' 'PASS' 'public' "CREDITS.md marks the IP review COMPLETE"
    } else {
        Record 'IP review status' 'WARN' 'public' "no 'IP REVIEW STATUS:' marker found in CREDITS.md - cannot confirm the review is done"
    }
    # every shipped game-rip author must appear by name in CREDITS.md.
    $requiredCredits = @('NateSmithZombies', 'TheSkyeLord', 'LilRobot', 'Logical', 'Ronan', 'T0nic', 'D3V')
    $missingCredits = @($requiredCredits | Where-Object { $credits -notmatch [regex]::Escape($_) })
    if ($missingCredits.Count -gt 0) {
        Record 'credit lines' 'FAIL' 'public' ("not credited in CREDITS.md: {0}" -f ($missingCredits -join ', '))
    } else {
        Record 'credit lines' 'PASS' 'public' 'all shipped game-rip authors are named in CREDITS.md'
    }
}

# ===========================================================================
# VERDICT
# ===========================================================================
$anyFails    = @($script:Results | Where-Object { $_.State -eq 'FAIL' -and $_.Track -eq 'any' })
$publicFails = @($script:Results | Where-Object { $_.State -eq 'FAIL' -and $_.Track -eq 'public' })
$publicWarns = @($script:Results | Where-Object { $_.State -eq 'WARN' -and $_.Track -eq 'public' })

Step "VERDICT"

# Track A: private dev/test publish
if ($anyFails.Count -eq 0) {
    Write-Host "  TRACK A (Private dev/test publish):  READY" -ForegroundColor Green
} else {
    Write-Host "  TRACK A (Private dev/test publish):  NOT READY" -ForegroundColor Red
    $anyFails | ForEach-Object { Write-Host ("      - {0}: {1}" -f $_.Name, $_.Detail) -ForegroundColor Red }
}

# Track B: public v1.0 release. FAILs = must-fix blockers; WARNs = recommended.
$mustFix = $anyFails.Count -gt 0 -or $publicFails.Count -gt 0
if (-not $mustFix -and $publicWarns.Count -eq 0) {
    Write-Host "  TRACK B (Public v1.0 release):       READY" -ForegroundColor Green
} elseif (-not $mustFix) {
    Write-Host "  TRACK B (Public v1.0 release):       READY (with recommended items)" -ForegroundColor Green
    $publicWarns | ForEach-Object { Write-Host ("      ~ recommended: {0}: {1}" -f $_.Name, $_.Detail) -ForegroundColor Yellow }
} else {
    Write-Host "  TRACK B (Public v1.0 release):       BLOCKED" -ForegroundColor Yellow
    $publicFails | ForEach-Object { Write-Host ("      - must-fix:    {0}: {1}" -f $_.Name, $_.Detail) -ForegroundColor Red }
    if ($anyFails.Count -gt 0) { Write-Host "      - must-fix:    (also blocked by the Track A failures above)" -ForegroundColor Red }
    $publicWarns | ForEach-Object { Write-Host ("      ~ recommended: {0}: {1}" -f $_.Name, $_.Detail) -ForegroundColor Yellow }
}

# ===========================================================================
# MANUAL publish steps (this script never uploads - the click is yours)
# ===========================================================================
Step "NEXT: publish in the Launcher (manual - this script does NOT upload)"
Write-Host @"
  1. Start Steam and log in. Close BO3 if it is running.
  2. Open Launcher (Steam -> Library -> Tools -> BO3 Mod Tools).
  3. Select $MapName -> File -> Publish Mod/Map.
  4. Confirm Title / Description / Tags(Map,Zombies) / Thumbnail(zone\previewimage.png).
  5. Visibility:  PRIVATE for Track A.  PUBLIC only when Track B is READY.
  6. Upload, then copy the Workshop URL.
  7. Pull the PublisherID back into the repo:  .\tools\sync_to_modtools.ps1 -Reverse
     then commit zone\workshop.json (so future publishes UPDATE the same item).
  Full runbook: docs/34_release_runbook.md
"@ -ForegroundColor Gray

# exit code
if ($anyFails.Count -gt 0) { exit 1 }
if ($Public -and $publicFails.Count -gt 0) { exit 1 }
exit 0
