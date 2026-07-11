# =============================================================================
# deploy_source_data.ps1 - deploy the REPO-OWNED source_data GDTs into the BO3
# Mod Tools install (and snapshot them back before commits).
#
# Added by the 2026-07-10 asset-portability audit. sync_to_modtools.ps1 mirrors
# the USERMAP tree only; GDT assets live at the Mod Tools ROOT (source_data\),
# so - like deploy_perk_shaders.ps1 - they need their own deploy. Without this,
# a fresh machine has a tracked .map/.zone referencing GDT assets that exist
# nowhere (acc_ssi_night_dim80 = the map's entire sky/sun lighting!).
#
# Repo-owned GDTs handled here (hand-authored text, git-tracked):
#   source_data\acc_ssi.gdt              (night-sky SSI the .map references 5x)
#   source_data\acc_weapon_variants.gdt  (PaP/OC/twin weapon variants)
# (acc_perk_shaders.gdt + _images ride tools\deploy_perk_shaders.ps1 - one
#  owner per asset; add new repo-owned GDTs to $RepoOwnedGdts below.)
#
# DIRECTION SAFETY (learned 2026-07-10, the hard way): during balance passes
# the INSTALL copy is edited directly (gdtdb workflow) and becomes the
# authoritative, NEWER file - repo copies rot (acc_weapon_variants.gdt was 2 MB
# stale with 49 zone-required blocks missing). So the FORWARD deploy never
# clobbers a differing install copy unless -Force; -Reverse snapshots
# install -> repo so the divergence can be committed.
#
# Usage:
#   .\tools\deploy_source_data.ps1              # fresh machine: copy repo->install where missing/identical
#   .\tools\deploy_source_data.ps1 -Force       # repo wins (overwrite differing install copies)
#   .\tools\deploy_source_data.ps1 -Reverse     # install wins: snapshot install->repo (run BEFORE committing GDT work)
#   .\tools\deploy_source_data.ps1 -SkipGdtDb   # copy only, no gdtdb /update
# =============================================================================

[CmdletBinding()]
param(
    [string]$ModToolsRoot = "",
    [switch]$Force,
    [switch]$Reverse,
    [switch]$SkipGdtDb
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[deploy-source-data] $msg" }

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

# Repo-owned, git-tracked GDTs (repo is the durable home; install may run ahead
# between -Reverse snapshots).
$RepoOwnedGdts = @(
    "acc_ssi.gdt",
    "acc_weapon_variants.gdt"
)

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ModTools = Resolve-ModToolsRoot

Write-Info "repo     = $RepoRoot"
Write-Info "modtools = $ModTools"
Write-Info "mode     = $(if ($Reverse) {'REVERSE (install -> repo snapshot)'} else {'FORWARD (repo -> install)'})"

$copied = 0
foreach ($name in $RepoOwnedGdts) {
    $repoFile = Join-Path $RepoRoot ("source_data\" + $name)
    $instFile = Join-Path $ModTools ("source_data\" + $name)

    if ($Reverse) {
        if (-not (Test-Path $instFile)) { Write-Info "skip ($name): no install copy"; continue }
        Copy-Item $instFile $repoFile -Force
        Write-Info "snapshot: $instFile -> $repoFile"
        # Pull the .acc-*-orig backups too - they document install-side patches.
        Get-ChildItem (Join-Path $ModTools "source_data") -Filter ($name + ".acc-*") -ErrorAction SilentlyContinue | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $RepoRoot ("source_data\" + $_.Name)) -Force
            Write-Info "snapshot: $($_.Name)"
        }
        $copied++
        continue
    }

    if (-not (Test-Path $repoFile)) { Write-Info "skip ($name): no repo copy (git pull?)"; continue }

    if (-not (Test-Path $instFile)) {
        Copy-Item $repoFile $instFile -Force
        Write-Info "deploy (new): $repoFile -> $instFile"
        $copied++
        continue
    }

    $repoHash = (Get-FileHash $repoFile -Algorithm MD5).Hash
    $instHash = (Get-FileHash $instFile -Algorithm MD5).Hash
    if ($repoHash -eq $instHash) {
        Write-Info "ok ($name): repo == install"
        continue
    }

    $r = Get-Item $repoFile; $i = Get-Item $instFile
    if ($Force) {
        Copy-Item $repoFile $instFile -Force
        Write-Info "deploy (FORCED over differing install copy): $name"
        $copied++
    } else {
        Write-Info "WARN ($name): repo and install DIFFER - NOT copying."
        Write-Info ("       repo    $($r.Length) bytes  $($r.LastWriteTime)")
        Write-Info ("       install $($i.Length) bytes  $($i.LastWriteTime)")
        Write-Info "       install newer/authoritative? run -Reverse to snapshot it into the repo."
        Write-Info "       repo is the truth? re-run with -Force."
    }
}

if (-not $Reverse -and $copied -gt 0) {
    if ($SkipGdtDb) {
        Write-Info "SkipGdtDb set - remember to run gdtdb /update before linking."
    } else {
        $gdtdb = Join-Path $ModTools "gdtdb\gdtdb.exe"
        if (Test-Path $gdtdb) {
            Write-Info "running gdtdb /update ..."
            Push-Location (Split-Path $gdtdb -Parent)
            try { & $gdtdb /update } finally { Pop-Location }
            if ($LASTEXITCODE -ne 0) { Write-Info "WARN: gdtdb exited $LASTEXITCODE - db may be stale (SAC? TA_* vars?)" }
            else { Write-Info "gdt.db updated." }
        } else {
            Write-Info "NOTE: gdtdb.exe not found at $gdtdb - run it manually before linking."
        }
    }
}

if ($Reverse -and $copied -gt 0) {
    Write-Info "snapshot done - review with 'git diff source_data' and commit."
}
Write-Info "done"
