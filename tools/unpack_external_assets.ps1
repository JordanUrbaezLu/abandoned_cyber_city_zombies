# =============================================================================
# unpack_external_assets.ps1 - apply the external-asset zip a teammate sent you
# into THIS machine's Mod Tools install, then refresh the GDT DB.
#
# This is the receiving end of tools/pack_external_assets.ps1. The zip carries
# the packs at their Mod-Tools-root-relative paths, so unpack just extracts and
# merges them into your install (overwrite, never delete), then runs gdtdb so
# the linker can find the imported GDT assets.
#
# Usage (PowerShell, Windows):
#   .\tools\unpack_external_assets.ps1 -ZipFile C:\Downloads\acc_external_assets.zip
#   .\tools\unpack_external_assets.ps1 -ZipFile <zip> -SkipGdtDb          # copy only
#   .\tools\unpack_external_assets.ps1 -ZipFile <zip> -ModToolsRoot "D:\...\Black Ops III 455130"
#
# After this: .\tools\check_external_assets.ps1  ->  .\tools\sync_to_modtools.ps1  ->  build.
# =============================================================================

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ZipFile,
    [string]$ModToolsRoot = '',
    [switch]$SkipGdtDb
)

$ErrorActionPreference = 'Stop'
function Write-Info($msg) { Write-Host "[unpack-ext] $msg" }

. (Join-Path $PSScriptRoot 'external_assets_manifest.ps1')

if (-not (Test-Path $ZipFile)) { throw "zip not found: $ZipFile" }
$ZipFile  = (Resolve-Path $ZipFile).Path
$ModTools = Resolve-ModToolsRoot $ModToolsRoot

Write-Info "modtools = $ModTools"
Write-Info "zip      = $ZipFile"

Add-Type -AssemblyName System.IO.Compression.FileSystem
$tmp = Join-Path $env:TEMP "acc_ext_assets_unzip_$PID"
if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }

Write-Info 'extracting ...'
[System.IO.Compression.ZipFile]::ExtractToDirectory($ZipFile, $tmp)

# Zip freshness gate (red-team 2026-07-10): an OUTDATED zip silently ROLLS BACK
# newer install-side-patched files (robocopy /E copies Older-class files too) -
# e.g. the hand-patched Apex GDTs whose only carrier is this zip flow. The stamp
# is written by pack_external_assets.ps1; a pre-stamp zip just warns generically.
$stamp = Join-Path $tmp 'acc_zip_manifest.txt'
if (Test-Path $stamp) {
    Write-Info '--- zip stamp ---'
    Get-Content $stamp | ForEach-Object { Write-Info "  $_" }
    $stampHash = (Get-Content $stamp | Where-Object { $_ -like 'manifest_sha256=*' }) -replace '^manifest_sha256=', ''
    $curHash = (Get-FileHash (Join-Path $PSScriptRoot 'external_assets_manifest.ps1') -Algorithm SHA256).Hash
    if ($stampHash -and $stampHash -ne $curHash) {
        Write-Info 'WARN: this zip was packed against a DIFFERENT manifest version than yours.'
        Write-Info '      If the zip is OLDER, unpacking can roll back newer install-side patched'
        Write-Info '      files (Apex GDTs etc.). Consider re-packing on the up-to-date machine.'
    }
    Remove-Item $stamp -Force  # never merge the stamp into the Mod Tools root
} else {
    Write-Info 'NOTE: zip has no acc_zip_manifest.txt stamp (packed before 2026-07-10).'
    Write-Info '      It predates the Apex/music/FX-library manifest entries - re-pack when possible.'
}

# Merge into the Mod Tools root. /E = copy subtree, NO /MIR, so nothing already
# installed (stock or other packs) is ever deleted - only overwritten/added.
Write-Info 'merging into Mod Tools (overwrite, never delete) ...'
$rc = Start-Process robocopy -NoNewWindow -Wait -PassThru -ArgumentList @(
    "`"$tmp`"", "`"$ModTools`"", '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:2', '/W:1')
if ($rc.ExitCode -ge 8) { throw "robocopy merge failed (exit $($rc.ExitCode))" }
Remove-Item $tmp -Recurse -Force
Write-Info "assets merged into $ModTools"

# The linker does NOT update the GDT DB - skip this and imported models/images
# error "unable to locate asset in gdtdb for ...".
if ($SkipGdtDb) {
    Write-Info 'SkipGdtDb set - remember to run gdtdb /update before linking.'
} else {
    $gdtdb = Join-Path $ModTools 'gdtdb\gdtdb.exe'
    if (Test-Path $gdtdb) {
        Write-Info 'running gdtdb /update ...'
        Push-Location (Split-Path $gdtdb -Parent)
        try { & $gdtdb /update } finally { Pop-Location }
        Write-Info 'gdt.db updated.'
    } else {
        Write-Info "NOTE: gdtdb.exe not found at $gdtdb - run it manually before linking."
    }
}

Write-Host ''
Write-Info 'done. Next:'
Write-Info '  .\tools\check_external_assets.ps1     # confirm every pack is present'
Write-Info '  .\tools\sync_to_modtools.ps1          # deploy the repo'
Write-Info '  then Launcher Compile (map + scripts), Run unchecked, PLAY_TEST_MAP.bat'
