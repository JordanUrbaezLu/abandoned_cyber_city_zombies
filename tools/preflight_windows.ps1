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

# GSC directive ordering: #namespace must come AFTER every #using/#insert/
# #define/#precache, or the compiler errors "unexpected TOKEN_USING,
# expecting $end" (first-compile finding 2026-06-12). Cheap static check
# that the plain brace/paren lint misses.
$gscFiles = Get-ChildItem (Join-Path $RepoRoot "scripts\zm\zm_abandoned_cyber_city") -Filter "_acc_*.gsc"
$ordering = @()
foreach ($g in $gscFiles) {
    $lines = Get-Content $g.FullName
    $nsIdx = ($lines | Select-String -Pattern '^#namespace' | Select-Object -First 1).LineNumber
    if ($null -eq $nsIdx) { $ordering += "$($g.Name): no #namespace"; continue }
    $dirIdxs = ($lines | Select-String -Pattern '^(#using|#insert|#define|#precache)' | ForEach-Object { $_.LineNumber })
    $lastDir = ($dirIdxs | Measure-Object -Maximum).Maximum
    if ($lastDir -and $nsIdx -lt $lastDir) { $ordering += "$($g.Name): #namespace(L$nsIdx) before directive(L$lastDir)" }
}
Check "GSC directive ordering (#namespace last) on $($gscFiles.Count) modules" ($ordering.Count -eq 0) ("fix: " + ($ordering -join '; '))

# GSC ternary must be FULLY wrapped: '( cond ? a : b )' (stock-proven form).
# Unwrapped '= ( cond ) ? a : b' or bare '= cond ? a : b' / 'return cond ? a : b'
# fail to compile ("unexpected TOKEN_CONDITIONAL"). Paren-aware scan: for each
# code line containing a ternary '?', strip strings + comments, then walk the
# chars - a '?' at paren-depth 0 is an unwrapped (broken) ternary.
$allGsc = Get-ChildItem (Join-Path $RepoRoot "scripts\zm") -Recurse -Include "*.gsc","*.csc"
$ternBad = @()
foreach ($g in $allGsc) {
    $ln = 0
    foreach ($raw in Get-Content $g.FullName) {
        $ln++
        $code = ($raw -replace '//.*$', '') -replace '"[^"]*"', '""'  # drop line-comment + string literals
        if ($code -notmatch '\?') { continue }
        $depth = 0
        for ($i = 0; $i -lt $code.Length; $i++) {
            $ch = $code[$i]
            if ($ch -eq '(') { $depth++ }
            elseif ($ch -eq ')') { $depth-- }
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
if ($ModToolsRoot -ne "" -and (Test-Path (Join-Path $ModToolsRoot "bin\modlauncher.exe"))) { $tools = $ModToolsRoot }
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
