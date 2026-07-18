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
#   4c. publish-folder hygiene (no orphan '*~lk' build-lock temp files in the upload
#                              folder - the Launcher ships the WHOLE zone dir, so a stale
#                              multi-GB .xpak~lk would upload; + total upload-size sanity)
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
# 0. ship-safe flag gate - the dev/god hardcodes MUST be flipped back to
#    `false` before ANY publish (review fix 2026-07-08: a shipped
#    `level.acc_dev = true` / `level.acc_god = true` is an invulnerable
#    full-dev build). TIGHTENED 2026-07-16 (user: "even the dev flag is not
#    used as a launch flag - we hardcode on and rebuild"): the SHIP state is
#    now `level.acc_dev = false;` / `level.acc_god = false;` - the old
#    getdvarint() ship resolution was REMOVED because it let any subscriber
#    arm the dev sandbox with `+set acc_dev 1`. This gate now also FAILS if
#    a dvar read of acc_dev/acc_god ever reappears in the entry script.
# ===========================================================================
Step "ship-safe flags (acc_dev / acc_god hardcoded false, no dvar path)"
$entryGsc = Join-Path $RepoRoot "scripts\zm\$MapName.gsc"
if (-not (Test-Path $entryGsc)) {
    Record 'ship-safe flags' 'WARN' 'any' "entry script not found at $entryGsc - cannot verify"
} else {
    $entrySrc = Get-Content $entryGsc -Raw
    # an ACTIVE (uncommented) hardcode of either flag to a truthy literal
    $hardcoded = @([regex]::Matches($entrySrc, '(?m)^\s*level\.acc_(dev|god)\s*=\s*(true|1)\s*;') | ForEach-Object { $_.Groups[1].Value })
    # any launch-flag/dvar resolution path for either flag (forbidden since 2026-07-16);
    # (?!\s*//) skips comment lines - a backtrackable char-class negation would false-positive on them
    $dvarRead  = @([regex]::Matches($entrySrc, '(?im)^(?!\s*//).*getdvar\w*\(\s*"acc_(dev|god)"') | ForEach-Object { $_.Groups[1].Value })
    if ($hardcoded.Count -gt 0) {
        Record 'ship-safe flags' 'FAIL' 'any' ('HARDCODED ON in acc_resolve_dev_flags(): {0} - restore the hardcoded-false ship line(s) before publishing' -f (($hardcoded | Sort-Object -Unique) -join ', '))
    } elseif ($dvarRead.Count -gt 0) {
        Record 'ship-safe flags' 'FAIL' 'any' ('acc_resolve_dev_flags() reads the acc_{0} dvar - the launch-flag path is forbidden (user 2026-07-16); ship state is a hardcoded false' -f (($dvarRead | Sort-Object -Unique) -join ', '))
    } else {
        Record 'ship-safe flags' 'PASS' 'any' 'acc_dev / acc_god hardcoded false (no dvar/launch-flag arming path)'
    }
}

# ===========================================================================
# 0b. party-mock gate (added 2026-07-15). ACC_MOCK_PARTY in AetheriumHud.lua is
#     the ONE test-force that is NOT acc_dev-gated - Lua cannot read level.acc_dev,
#     so a `true` here ships to every subscriber and MASKS real teammates' party
#     slots with fake players. It was found ON during this publish prep while
#     gate 0 (dev/god) passed, which is exactly why it needs its own check.
# ===========================================================================
Step "ship-safe flags (party mocks off)"
$hudLua = Join-Path $RepoRoot "ui\uieditor\menus\hud\AetheriumHud.lua"
if (-not (Test-Path $hudLua)) {
    Record 'party mocks' 'WARN' 'any' "AetheriumHud.lua not found at $hudLua - cannot verify"
} else {
    $hudSrc = Get-Content $hudLua -Raw
    # an ACTIVE (non-comment) assignment of the mock flag to true; Lua comments start with --
    if ([regex]::IsMatch($hudSrc, '(?m)^\s*(?!--)\s*local\s+ACC_MOCK_PARTY\s*=\s*true\b')) {
        Record 'party mocks' 'FAIL' 'any' 'ACC_MOCK_PARTY = true in AetheriumHud.lua - fake party members would REPLACE real teammates for every player. Set it false before publishing.'
    } else {
        Record 'party mocks' 'PASS' 'any' 'ACC_MOCK_PARTY off (real co-op party slots)'
    }
}

# ===========================================================================
# 0c. no-per-feature-lever gate (TIGHTENED 2026-07-16; was "debug channels
#     default OFF", added 2026-07-15). The doctrine is now stronger: per-feature
#     debug/test dvar gates must not EXIST at all (user: only acc_dev / acc_god /
#     ACC_MOCK_PARTY). All ~26 acc_*_debug/_dbg/_test levers were removed
#     2026-07-16 - debug rides IS_TRUE(level.acc_dev). This gate fails if any
#     such dvar gate reappears in live code, regardless of its default - the
#     old default-0 form was exactly how the lever plague grew back last time.
#     (Live-balance dvars are unaffected: the pattern only matches names ending
#     in debug/dbg/test, not _enable/_mult/_round etc.)
# ===========================================================================
Step "no per-feature debug/test dvar levers (only acc_dev/acc_god/mock exist)"
$levers = @()
$scriptDir = Join-Path $RepoRoot 'scripts'
if (-not (Test-Path $scriptDir)) {
    Record 'no debug/test levers' 'WARN' 'any' "script tree not found at $scriptDir - cannot verify"
} else {
    foreach ($f in (Get-ChildItem -Path $scriptDir -Recurse -Include '*.gsc', '*.csc')) {
        # the stash under tools/ is not compiled; scripts/ only
        $ln = 0
        foreach ($line in (Get-Content $f.FullName)) {
            $ln++
            # skip commented-out code - only an ACTIVE gate is a lever
            if ($line -match '^\s*//') { continue }
            $m = [regex]::Match($line, 'getdvar\w*\(\s*"([a-z0-9_]*(?:debug|dbg|test))"')
            if ($m.Success) {
                $levers += ("{0} ({1}:{2})" -f $m.Groups[1].Value, $f.Name, $ln)
            }
        }
    }
    if ($levers.Count -gt 0) {
        Record 'no debug/test levers' 'FAIL' 'any' ("per-feature debug/test dvar gate(s) found - the doctrine allows ONLY acc_dev/acc_god/ACC_MOCK_PARTY; gate the behavior on IS_TRUE(level.acc_dev) or delete it: {0}" -f (($levers | Sort-Object -Unique) -join '; '))
    } else {
        Record 'no debug/test levers' 'PASS' 'any' 'no per-feature debug/test dvar gates in live code (debug rides acc_dev)'
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
# 4c. publish-folder hygiene - the Launcher uploads the WHOLE usermaps\<map>\zone
#     folder with NO filter, so orphaned build LOCK-temp files ('*~lk') would ship
#     into the Workshop item. The linker/sound build streams to '.xpak~lk'/'.sabl~lk'
#     then renames on its OWN success; an interrupted/superseded build leaves a
#     MULTI-GB orphan nothing auto-cleans (the 2026-07-16 "4.1->7.1 GB" scare was a
#     3.04 GB zm_....xpak~lk left in the folder). build_map.ps1 (gate 3) now sweeps
#     these before every link, so a normal full-build prep run is already clean here -
#     this gate is the belt-and-suspenders for the -NoBuild / Launcher-GUI-build paths.
#     A healthy upload folder is ~3.7 GB (.ff ~120MB + .xpak ~3.2GB streamed textures
#     + snd ~0.24GB). Read-only, per this script's contract - it reports the fix, never
#     deletes. Track 'any': a stale multi-GB orphan should block EVEN a private publish.
# ===========================================================================
Step "publish-folder hygiene (no orphan *~lk; upload size sane)"
if (-not (Test-Path $FfDir)) {
    Record 'publish-folder hygiene' 'WARN' 'any' "zone output folder not found at $FfDir - run a build first"
} else {
    $orphans  = @(Get-ChildItem -Path $FfDir -Recurse -File -ErrorAction SilentlyContinue |
                  Where-Object { $_.Name.EndsWith('~lk') })
    $folderGB = ((Get-ChildItem -Path $FfDir -Recurse -File -ErrorAction SilentlyContinue |
                  Measure-Object -Property Length -Sum).Sum / 1GB)
    if ($orphans.Count -gt 0) {
        $oMb   = ($orphans | Measure-Object -Property Length -Sum).Sum / 1MB
        $names = ($orphans | ForEach-Object { "{0} ({1:N0} MB)" -f $_.Name, ($_.Length / 1MB) }) -join ', '
        Record 'publish-folder hygiene' 'FAIL' 'any' ("orphan build-lock temp file(s) totalling {0:N0} MB WOULD SHIP into the Workshop item (whole-folder upload): {1}. Fix - re-run a full build (auto-sweeps) OR delete manually: Get-ChildItem `"{2}`" -Recurse -File | ? {{ `$_.Name.EndsWith('~lk') }} | Remove-Item -Force" -f $oMb, $names, $FfDir)
    } elseif ($folderGB -gt 5) {
        Record 'publish-folder hygiene' 'WARN' 'public' ("no orphan *~lk, but the upload folder is {0:N2} GB (healthy ~3.7 GB) - inspect for other stray/duplicate files before uploading" -f $folderGB)
    } else {
        Record 'publish-folder hygiene' 'PASS' 'any' ("no orphan *~lk; upload folder {0:N2} GB" -f $folderGB)
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
# TWO DIFFERENT SURFACES - do not conflate them (2026-07-18):
#   previewimage.png  = the IN-GAME map card (bottom-left of map select). The engine
#                       reads it off disk per-usermap; stock LUI MapNameToMapImage()
#                       falls through to Engine.UpdateModPreviewImage(<ugcName>) for
#                       usermaps. Launcher template spec = 600x340 (ZM + MP templates
#                       both ship exactly that). NOT a fastfile asset - no .zone line.
#   workshopimage.png = the STEAM WORKSHOP web thumbnail, pointed at by the absolute
#                       "Thumbnail" path in workshop.json. Steam wants square/512.
# A single file cannot serve both: 512x512 in the 600x340 card slot renders stretched.
$card = Join-Path $ZoneDir 'previewimage.png'
if (-not (Test-Path $card)) {
    Record 'map card' 'FAIL' 'public' "no zone\previewimage.png (in-game map-select card)"
} else {
    $sz = Get-PngSize $card
    if ($sz -and $sz.W -eq 600 -and $sz.H -eq 340) {
        Record 'map card' 'PASS' 'public' "previewimage.png is 600x340 (Launcher template spec)"
    } elseif ($sz) {
        Record 'map card' 'WARN' 'public' ("previewimage.png is {0}x{1} - in-game card wants 600x340; other ratios render stretched" -f $sz.W, $sz.H)
    } else {
        Record 'map card' 'WARN' 'public' "previewimage.png present (could not read size)"
    }
}

$thumb = Join-Path $ZoneDir 'workshopimage.png'
if (-not (Test-Path $thumb)) {
    Record 'thumbnail' 'FAIL' 'public' "no zone\workshopimage.png (workshop.json Thumbnail points here)"
} else {
    $sz = Get-PngSize $thumb
    if ($sz -and $sz.W -eq 512 -and $sz.H -eq 512) {
        Record 'thumbnail' 'PASS' 'public' "workshopimage.png is 512x512"
    } elseif ($sz) {
        Record 'thumbnail' 'WARN' 'public' ("workshopimage.png is {0}x{1} - Steam recommends 512x512 for a crisp Workshop thumbnail" -f $sz.W, $sz.H)
    } else {
        Record 'thumbnail' 'WARN' 'public' "workshopimage.png present (could not read size)"
    }
}

# The publisher uploads the whole zone\ folder VERBATIM - anything parked here ships to
# subscribers. Caught 2026-07-18: a stale greybox screenshot (previewimage.png.acc-orig-
# landscape, 965 KB) and workshop.json.example were both live in the published item.
$zoneAllowed = @(
    'previewimage.png', 'workshopimage.png', 'loadingimage.png', 'workshop.json'
)
$strays = Get-ChildItem $ZoneDir -File -ErrorAction SilentlyContinue | Where-Object {
    $_.Extension -notin @('.ff', '.xpak') -and $_.Name -notin $zoneAllowed
}
if ($strays.Count -gt 0) {
    Record 'zone strays' 'WARN' 'public' ("zone\ ships verbatim to subscribers - remove: {0}" -f (($strays | ForEach-Object { $_.Name }) -join ', '))
} else {
    Record 'zone strays' 'PASS' 'public' "no stray files in zone\ (only publish artifacts + presentation assets)"
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
