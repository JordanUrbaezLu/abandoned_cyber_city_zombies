# =============================================================================
# pack_external_assets.ps1 - bundle the external (game-rip) asset packs that a
# fresh clone is MISSING into one zip you can hand to a teammate.
#
# Run this on the box that ALREADY has the packs installed in the Mod Tools.
# It stages every pack listed in external_assets_manifest.ps1 (relative paths
# preserved) and writes acc_external_assets.zip. Your teammate then runs
# tools/unpack_external_assets.ps1 to drop them into their own Mod Tools.
#
# Usage (PowerShell, Windows):
#   .\tools\pack_external_assets.ps1                       # auto-detect install
#   .\tools\pack_external_assets.ps1 -OutFile D:\acc.zip   # custom output path
#   .\tools\pack_external_assets.ps1 -IncludeOptional      # also add Panzer/mechz
#   .\tools\pack_external_assets.ps1 -DryRun               # list, write nothing
#   .\tools\pack_external_assets.ps1 -ModToolsRoot "D:\...\Black Ops III 455130"
#
# WHY a zip and not git: these packs are game-rip with no redistribution licence
# (CREDITS.md). Share the zip PRIVATELY; never commit them to a public repo.
# =============================================================================

[CmdletBinding()]
param(
    [string]$ModToolsRoot = '',
    [string]$OutFile = '',
    [switch]$IncludeOptional,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
function Write-Info($msg) { Write-Host "[pack-ext] $msg" }

. (Join-Path $PSScriptRoot 'external_assets_manifest.ps1')

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$ModTools = Resolve-ModToolsRoot $ModToolsRoot
if ($OutFile -eq '') { $OutFile = Join-Path $RepoRoot 'acc_external_assets.zip' }

$staging = Join-Path $env:TEMP "acc_ext_assets_stage_$PID"
if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }

Write-Info "modtools = $ModTools"
Write-Info "out      = $OutFile"
if ($DryRun) { Write-Info 'DRY RUN - nothing will be written' }

# Copy one source path (file or folder) into the staging tree at $rel so the zip
# preserves the Mod-Tools-root-relative layout (unpack restores it 1:1).
function Copy-Into-Staging($srcFull, $rel, $isDir) {
    if ($DryRun) { Write-Info "  + $rel"; return }
    $dst = Join-Path $staging $rel
    if ($isDir) {
        $rc = Start-Process robocopy -NoNewWindow -Wait -PassThru -ArgumentList @(
            "`"$srcFull`"", "`"$dst`"", '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:2', '/W:1')
        if ($rc.ExitCode -ge 8) { throw "robocopy failed staging $rel (exit $($rc.ExitCode))" }
    } else {
        $parent = Split-Path $dst -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item -LiteralPath $srcFull -Destination $dst -Force
    }
}

# Stage every match for one manifest path entry; return how many items it staged.
function Stage-Path($relPattern) {
    $count = 0
    if ($relPattern -match '[\*\?]') {
        $parentRel = Split-Path $relPattern -Parent
        $leaf      = Split-Path $relPattern -Leaf
        $srcParent = Join-Path $ModTools $parentRel
        if (Test-Path $srcParent) {
            $items = @(Get-ChildItem -LiteralPath $srcParent -Filter $leaf -ErrorAction SilentlyContinue)
            foreach ($it in $items) {
                $rel = if ($parentRel) { Join-Path $parentRel $it.Name } else { $it.Name }
                Copy-Into-Staging $it.FullName $rel $it.PSIsContainer
                $count++
            }
        }
    } else {
        $full = Join-Path $ModTools $relPattern
        if (Test-Path $full) {
            $item = Get-Item -LiteralPath $full
            Copy-Into-Staging $full $relPattern $item.PSIsContainer
            $count++
        }
    }
    return $count
}

$packed = @(); $missing = @()
foreach ($pack in $ExternalAssetPacks) {
    if (-not $pack.Required -and -not $IncludeOptional) {
        Write-Info "skip optional: $($pack.Name)  (add with -IncludeOptional)"
        continue
    }
    $total = 0
    foreach ($p in $pack.Paths) { $total += (Stage-Path $p) }
    if ($total -gt 0) {
        Write-Info "[OK]   $($pack.Name) - staged $total path(s)"
        $packed += $pack.Name
    } else {
        Write-Info "[MISS] $($pack.Name) - NOTHING found in the Mod Tools. Installed here? ($($pack.Link))"
        $missing += $pack.Name
    }
}

if ($DryRun) {
    if (Test-Path $staging) { Remove-Item $staging -Recurse -Force }
    Write-Info 'DRY RUN complete - no zip written.'
    return
}

if (-not (Test-Path $staging)) {
    throw "Nothing staged - no external assets found under $ModTools. Are the packs installed there? (run .\tools\check_external_assets.ps1)"
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
if (Test-Path $OutFile) { Remove-Item $OutFile -Force }
Write-Info 'compressing (this can take a minute for multi-GB packs) ...'
[System.IO.Compression.ZipFile]::CreateFromDirectory(
    $staging, $OutFile, [System.IO.Compression.CompressionLevel]::Optimal, $false)
$sizeMB = [math]::Round((Get-Item $OutFile).Length / 1MB, 1)
Remove-Item $staging -Recurse -Force

Write-Host ''
Write-Info "wrote $OutFile  (${sizeMB} MB)"
Write-Info "packed:     $($packed -join ', ')"
if ($missing.Count) { Write-Info "NOT packed (not installed here): $($missing -join ', ')" }
Write-Info 'Send this zip to your teammate. They run:'
Write-Info "  .\tools\unpack_external_assets.ps1 -ZipFile <path-to>\$(Split-Path $OutFile -Leaf)"
