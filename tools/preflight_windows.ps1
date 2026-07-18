# =============================================================================
# preflight_windows.ps1 - automated readiness check before the first build.
#
# Run from the repo root any time:   .\tools\preflight_windows.ps1
# Exit code 0 = everything green (or only warnings). Each check prints
# [PASS] / [WARN] / [FAIL] with the exact fix for failures.
# =============================================================================

[CmdletBinding()]
param(
    [string]$ModToolsRoot = ""
)

$ErrorActionPreference = "Continue"
$script:fails = 0
$script:warns = 0

function Check($name, $ok, $fixMsg, $warnOnly) {
    if ($ok) {
        Write-Host "[PASS] $name" -ForegroundColor Green
    } elseif ($warnOnly) {
        $script:warns++
        Write-Host "[WARN] $name" -ForegroundColor Yellow
        if ($fixMsg) { Write-Host "       -> $fixMsg" -ForegroundColor Yellow }
    } else {
        $script:fails++
        Write-Host "[FAIL] $name" -ForegroundColor Red
        if ($fixMsg) { Write-Host "       -> $fixMsg" -ForegroundColor Red }
    }
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Write-Host "repo: $RepoRoot`n"

# --- 1. Repo integrity ---------------------------------------------------------
$mapFile = Join-Path $RepoRoot "map_source\zm\zm_abandoned_cyber_city.map"
Check "map source present" (Test-Path $mapFile) "git checkout broke? re-clone."
$entry = Join-Path $RepoRoot "scripts\zm\zm_abandoned_cyber_city.gsc"
Check "entry GSC present" (Test-Path $entry) "git checkout broke? re-clone."
$zoneFile = Join-Path $RepoRoot "zone_source\zm_abandoned_cyber_city.zone"
Check "zone manifest present" (Test-Path $zoneFile) "git checkout broke? re-clone."

# brace balance on the .map (cheap corruption canary)
$mapText = [System.IO.File]::ReadAllText($mapFile)
$open = ($mapText.ToCharArray() | Where-Object { $_ -eq '{' }).Count
$close = ($mapText.ToCharArray() | Where-Object { $_ -eq '}' }).Count
Check ".map brace balance ($open/$close)" ($open -eq $close) "map file corrupted - git checkout -- map_source/"

# every module in the zone manifest exists on disk, and vice versa
$zoneLines = Get-Content $zoneFile | Where-Object { $_ -match '^scriptparsetree,' } |
    ForEach-Object { ($_ -split ',', 2)[1].Trim() -replace '/', '\' }
$missing = @($zoneLines | Where-Object { -not (Test-Path (Join-Path $RepoRoot $_)) })
Check "all $($zoneLines.Count) zone scriptparsetree files exist" ($missing.Count -eq 0) ("missing: " + ($missing -join ', '))
$moduleFiles = Get-ChildItem (Join-Path $RepoRoot "scripts\zm\zm_abandoned_cyber_city") -Filter "_acc_*.gsc" |
    ForEach-Object { "scripts\zm\zm_abandoned_cyber_city\$($_.Name)" }
$unlisted = @($moduleFiles | Where-Object { $zoneLines -notcontains $_ })
Check "all $($moduleFiles.Count) _acc_ modules listed in zone" ($unlisted.Count -eq 0) ("add scriptparsetree lines for: " + ($unlisted -join ', '))

# GSC directive ordering: #namespace must come AFTER every '#using ' / '#insert',
# or the compiler errors "unexpected TOKEN_USING, expecting $end" (first-compile
# finding 2026-06-12). Cheap static check that the plain brace/paren lint misses.
#
# SCOPE CORRECTED 2026-07-15 (audit): '#define' and '#precache' are NOT order-sensitive and
# must NOT be checked here - the old pattern included them and produced 4 FALSE FAILs, which
# forced this whole script to exit 1 on a tree that builds and ships. Evidence (counted over
# the stock mirror tmp/bo3_stock_ref, 699 files carrying a #namespace):
#     #using    ->   0 occurrences after #namespace   (order-sensitive - CHECK)
#     #insert   ->   0 occurrences after #namespace   (order-sensitive - CHECK)
#     #define   -> 684 occurrences after #namespace   (LEGAL - e.g. mp\bots\_bot.gsc:212)
#     #precache -> 363 occurrences after #namespace   (LEGAL - e.g. mp\gametypes\_globallogic.gsc:93)
# Our own shipping tree agrees: 21 #define + 40 #precache sit after #namespace and compile.
#
# The pattern deliberately requires WHITESPACE after '#using' so it does not match
# '#using_animtree( "generic" );', which is a DIFFERENT directive and IS legal after
# #namespace (34 stock occurrences; 2 in our tree - mechz_spiki.gsc:74, _zm_aw_mysterybox.gsc:50).
$gscFiles = Get-ChildItem (Join-Path $RepoRoot "scripts\zm\zm_abandoned_cyber_city") -Filter "_acc_*.gsc"
$ordering = @()
foreach ($g in $gscFiles) {
    $lines = Get-Content $g.FullName
    $nsIdx = ($lines | Select-String -Pattern '^#namespace' | Select-Object -First 1).LineNumber
    if ($null -eq $nsIdx) { $ordering += "$($g.Name): no #namespace"; continue }
    $dirIdxs = ($lines | Select-String -Pattern '^(#using\s|#insert\s)' | ForEach-Object { $_.LineNumber })
    $lastDir = ($dirIdxs | Measure-Object -Maximum).Maximum
    if ($lastDir -and $nsIdx -lt $lastDir) { $ordering += "$($g.Name): #namespace(L$nsIdx) before directive(L$lastDir)" }
}
Check "GSC directive ordering (#namespace last) on $($gscFiles.Count) modules" ($ordering.Count -eq 0) ("fix: " + ($ordering -join '; '))

# GSC ternary must be FULLY wrapped: '( cond ? a : b )' (stock-proven form).
# Unwrapped '= ( cond ) ? a : b' or bare '= cond ? a : b' / 'return cond ? a : b'
# fail to compile ("unexpected TOKEN_CONDITIONAL"). Paren-aware scan: strip strings +
# comments, then walk the chars - a '?' at paren-depth 0 is an unwrapped (broken) ternary.
#
# STATEFUL ACROSS LINES since 2026-07-15 (audit). $depth used to be reset INSIDE the per-line
# loop, which threw away the depth carried in from earlier lines - so any LEGAL multi-line
# ternary whose '?' opens a continuation line false-FAILed and forced this script to exit 1.
# Live example that tripped it (_acc_fury.gsc:152-154) - the '(' is on the PREVIOUS line:
#     delay = ( b_first
#               ? getdvarfloat( "acc_fury_arm_sec", 8 )
#               : getdvarfloat( "acc_fury_interval", ACC_FURY_INTERVAL_DEF ) );
# Depth now persists per FILE (reset once per file, below). A genuine paren imbalance would
# skew it, but the dedicated brace/paren lint already fails that case first.
#
# Block comments are stripped across lines too (the old '//.*$' only caught line comments, so a
# '?' inside a /* */ block was a latent false positive). NOTE: '/# ... #/' dev blocks are NOT
# stripped - that is real code the compiler emits in dev builds, so it must stay in scope.
$allGsc = Get-ChildItem (Join-Path $RepoRoot "scripts\zm") -Recurse -Include "*.gsc","*.csc"
$ternBad = @()
foreach ($g in $allGsc) {
    $ln = 0
    $depth = 0        # per-FILE, not per-line (see note above)
    $inBlock = $false # inside a /* */ block comment
    foreach ($raw in Get-Content $g.FullName) {
        $ln++
        $code = $raw
        # strip /* */ block comments, honouring state carried in from previous lines
        $out = ''
        for ($i = 0; $i -lt $code.Length; $i++) {
            if ($inBlock) {
                if ($i -lt $code.Length - 1 -and $code[$i] -eq '*' -and $code[$i+1] -eq '/') { $inBlock = $false; $i++ }
            } elseif ($i -lt $code.Length - 1 -and $code[$i] -eq '/' -and $code[$i+1] -eq '*') {
                $inBlock = $true; $i++
            } else { $out += $code[$i] }
        }
        $code = ($out -replace '//.*$', '') -replace '"[^"]*"', '""'  # drop line-comment + string literals
        for ($i = 0; $i -lt $code.Length; $i++) {
            $ch = $code[$i]
            if ($ch -eq '(') { $depth++ }
            elseif ($ch -eq ')') { $depth--; if ($depth -lt 0) { $depth = 0 } }
            elseif ($ch -eq '?' -and $depth -le 0) { $ternBad += "$($g.Name):$ln"; break }
        }
    }
}
Check "GSC ternaries fully paren-wrapped" ($ternBad.Count -eq 0) ("unwrapped ternary at: " + ($ternBad -join ', '))

# Reserved GSC keywords used as identifiers (variable/param/foreach). 'class'
# is confirmed reserved (TOKEN_CLASS); add others here as the compiler reveals
# them. Narrow list = zero false positives (e.g. 'type' is NOT reserved - stock
# uses it as a param). Strings + comments stripped first.
$reserved = @('class')
$rwBad = @()
foreach ($g in $allGsc) {
    $ln = 0
    foreach ($raw in Get-Content $g.FullName) {
        $ln++
        $code = ($raw -replace '//.*$', '') -replace '"[^"]*"', '""'
        foreach ($kw in $reserved) {
            if ($code -match "(^|[^\w.])$kw\s*=(?!=)" -or
                $code -match "^\s*function\s+\w+\s*\([^)]*[\(,\s]$kw[\s,\)]" -or
                $code -match "foreach\s*\(\s*$kw\s+in") {
                $rwBad += "$($g.Name):$ln ($kw)"
            }
        }
    }
}
Check "no reserved GSC keywords as identifiers" ($rwBad.Count -eq 0) ("rename: " + ($rwBad -join ', '))

# Cross-reference + dependency lint (node): acc ns::fn resolution, stock
# #using presence, macro #inserts, bare-call namespaces. Catches the
# "Unresolved external" linker class before the build.
$node = Get-Command node -ErrorAction SilentlyContinue
if ($node) {
    $xref = & node (Join-Path $RepoRoot "tools\lint_gsc_xref.js") 2>&1
    $xrefOk = ($LASTEXITCODE -eq 0)
    Check "GSC cross-reference/dependency lint" $xrefOk (($xref | Select-Object -Skip 1) -join ' ')
} else {
    Check "GSC cross-reference/dependency lint" $true "node not found - skipped (install Node.js to enable)" $true
}

# Room-geometry source-of-truth lint (node): asserts the 4 duplicated room
# footprint copies (gen_zone_greybox / gen_map_design / baked .map / gen_rooms
# shells) + the 2 PaP-origin literals all agree with source_data/rooms.json.
# Catches a silent map<->generator desync before a build (docs/36 Stage 0).
if ($node) {
    $rooms = & node (Join-Path $RepoRoot "tools\validate_rooms.js") 2>&1
    $roomsOk = ($LASTEXITCODE -eq 0)
    Check "room-geometry source-of-truth lint" $roomsOk (($rooms | Select-Object -Skip 1) -join ' ')
} else {
    Check "room-geometry source-of-truth lint" $true "node not found - skipped (install Node.js to enable)" $true
}

# line endings: repo policy is LF (see .gitattributes)
$gaPath = Join-Path $RepoRoot ".gitattributes"
Check ".gitattributes present (LF policy pinned)" (Test-Path $gaPath) "restore .gitattributes from git"
$crCount = ([System.IO.File]::ReadAllBytes($mapFile) | Where-Object { $_ -eq 13 }).Count
Check ".map has no CRLF (found $crCount CR bytes)" ($crCount -eq 0) "run: git add --renormalize . ; git checkout -- . (or just commit - .gitattributes normalizes)" $true

# --- 2. Machine state -----------------------------------------------------------
$policy = Get-ExecutionPolicy -Scope CurrentUser
Check "PowerShell execution policy ($policy)" ($policy -in @("RemoteSigned", "Unrestricted", "Bypass")) "Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"

$free = [math]::Round((Get-PSDrive C).Free / 1GB)
Check "disk free on C: (${free} GB)" ($free -ge 130) "Mod Tools = ~25 GB base + ~50 GB Additional Assets DLC + headroom; free up space" ($free -ge 80)

# Officially documented Treyarch requirement: Windows Region decimal symbol
# must be "." or compile/light malfunction (classic EU-locale failure).
$dec = (Get-Culture).NumberFormat.NumberDecimalSeparator
Check "Windows decimal symbol is '.' (found '$dec')" ($dec -eq ".") "Control Panel -> Region -> Additional settings -> Decimal symbol = ."

$ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
Check "RAM (${ramGB} GB)" ($ramGB -ge 16) "16 GB is the documented Mod Tools minimum; linker/light may OOM - increase the pagefile and close Radiant during builds" ($ramGB -ge 12)

# --- 3. BO3 + Mod Tools install --------------------------------------------------
# Tools may live in the game folder OR a separate "...Black Ops III 455130"
# folder (Steam AppID-suffix on name collision - this machine's layout).
# Proof of the tools root = bin\modlauncher.exe, never just the folder name.
$libRoots = @(
    "C:\Program Files (x86)\Steam\steamapps\common",
    "D:\Steam\steamapps\common",
    "E:\Steam\steamapps\common",
    "C:\Steam\steamapps\common"
)
$gameFound = $false
$tools = $null
if ($ModToolsRoot -ne "") {
    if (Test-Path (Join-Path $ModToolsRoot "bin\modlauncher.exe")) { $tools = $ModToolsRoot }
    else { Check "-ModToolsRoot override valid" $false "no bin\modlauncher.exe under '$ModToolsRoot' - override IGNORED, falling back to auto-detection" $true }
}
foreach ($lib in $libRoots) {
    if (-not (Test-Path $lib)) { continue }
    $dirs = Get-ChildItem $lib -Directory -Filter "Call of Duty Black Ops III*" -ErrorAction SilentlyContinue
    foreach ($d in $dirs) {
        if (Test-Path (Join-Path $d.FullName "BlackOps3.exe")) { $gameFound = $true }
        if (($null -eq $tools) -and (Test-Path (Join-Path $d.FullName "bin\modlauncher.exe"))) { $tools = $d.FullName }
    }
}

Check "BO3 game install found" $gameFound "install Call of Duty: Black Ops III via Steam"
Check "Mod Tools root found ($tools)" ($null -ne $tools) "Steam Library -> filter: Tools -> 'Call of Duty: Black Ops III - Mod Tools' -> Install (plus the Additional Assets DLC), or pass -ModToolsRoot"
if ($tools) {
    Check "stock prefabs present (map_source\_prefabs\zm)" (Test-Path (Join-Path $tools "map_source\_prefabs\zm")) "verify integrity of the Mod Tools in Steam"
    Check "zm template present (rex\templates\ZM Mod Level)" (Test-Path (Join-Path $tools "rex\templates\ZM Mod Level")) "enable the 'BO3 Mod Tools - Additional Assets' DLC (right-click tools -> Properties -> DLC)" $true
    $um = Join-Path $tools "usermaps\zm_abandoned_cyber_city"
    Check "usermap synced ($um)" (Test-Path (Join-Path $um "zone_source\zm_abandoned_cyber_city.zone")) "run .\tools\sync_to_modtools.ps1" $true
    Check "map source synced to tools root" (Test-Path (Join-Path $tools "map_source\zm\zm_abandoned_cyber_city.map")) "run .\tools\sync_to_modtools.ps1" $true
    # Split-install: game loads usermaps from the GAME folder, not the tools
    # folder. The sync script junctions game\usermaps -> tools\usermaps so the
    # built .ff is loadable. Only relevant when tools != game folder.
    $gameRoot = $tools -replace ' 455130$', ''
    if ($gameRoot -ne $tools -and (Test-Path (Join-Path $gameRoot "BlackOps3.exe"))) {
        Check "game usermaps junction (split install)" (Test-Path (Join-Path $gameRoot "usermaps\zm_abandoned_cyber_city\zone")) "run .\tools\sync_to_modtools.ps1 (creates the junction) - else the game can't load the build" $true
        # Steam DRM: direct BlackOps3.exe launch needs steam_appid.txt or it
        # exits silently (Launcher Run opens nothing).
        Check "steam_appid.txt present (Launcher Run works)" (Test-Path (Join-Path $gameRoot "steam_appid.txt")) "run .\tools\sync_to_modtools.ps1 (writes steam_appid.txt=311210) - else the game exe quits on launch" $true
    }

    # New-box hard requirements (2026-07 lessons; see restore_machine.ps1 which
    # can fix all three). Without TA_TOOLS_PATH/TA_GAME_PATH the Treyarch tools
    # 0xC0000005-crash with NO error message. Compare path-normalized: the live
    # values carry a trailing backslash.
    $taTools = [Environment]::GetEnvironmentVariable("TA_TOOLS_PATH", "User")
    $taOk = ($null -ne $taTools) -and ($taTools.TrimEnd("\").ToLowerInvariant() -eq $tools.TrimEnd("\").ToLowerInvariant())
    Check "TA_TOOLS_PATH env var set + matches tools root" $taOk "run .\tools\restore_machine.ps1 (sets TA_TOOLS_PATH/TA_GAME_PATH) - without them the tools crash 0xC0000005 with no message"
    $taGame = [Environment]::GetEnvironmentVariable("TA_GAME_PATH", "User")
    Check "TA_GAME_PATH env var set" ($null -ne $taGame -and $taGame -ne "") "run .\tools\restore_machine.ps1"

    # Smart App Control blocks gdtdb.exe -> cod2map/Radiant/linker all assert
    # on the missing gdtDB\gdt.db and NOTHING builds. 0 = off.
    $sacState = $null
    try { $sacState = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\CI\Policy" -ErrorAction Stop).VerifiedAndReputablePolicyState } catch {}
    if ($null -ne $sacState) {
        Check "Smart App Control off (state=$sacState)" ($sacState -eq 0) "Windows Security -> App & browser control -> Smart App Control -> Off (it blocks gdtdb.exe; NOTHING builds while on)"
    }

    # L3akMod DLL overwrite: without it the linker errors 'Lua not supported'
    # on every rawfile,*.lua = the whole custom HUD. Stock DLL = 441,856 bytes.
    $tiffDll = Join-Path $tools "bin\libtiff64r.dll"
    if (Test-Path $tiffDll) {
        Check "L3akMod installed (bin\libtiff64r.dll not stock)" ((Get-Item $tiffDll).Length -ne 441856) "install L3akMod v1.0.4 (dtzxporter.com/tools/l3akmod): back up bin\libtiff64r.dll as .acc-orig-backup, overwrite with the L3akMod DLL - custom LUI cannot link without it"
    }
}

# --- 4. Optional niceties ---------------------------------------------------------
Check "git available" ($null -ne (Get-Command git -ErrorAction SilentlyContinue)) "install Git for Windows" $true
Check "node available (map design/regen tooling)" ($null -ne (Get-Command node -ErrorAction SilentlyContinue)) "install Node.js (only needed for tools/gen_map_design.js)" $true

# --- summary ----------------------------------------------------------------------
Write-Host ""
if ($script:fails -gt 0) {
    Write-Host "$($script:fails) FAIL / $($script:warns) WARN - fix the FAILs above, then re-run." -ForegroundColor Red
    exit 1
} elseif ($script:warns -gt 0) {
    Write-Host "0 FAIL / $($script:warns) WARN - good to proceed; warnings are next steps, not blockers." -ForegroundColor Yellow
    exit 0
} else {
    Write-Host "ALL GREEN - open the Launcher and build (SETUP_WINDOWS.md step 4)." -ForegroundColor Green
    exit 0
}
