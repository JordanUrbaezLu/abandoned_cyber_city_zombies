# =============================================================================
# sync_to_modtools.ps1 - Mirror the repo's authoring trees into the BO3
# Mod Tools usermap install.
#
# Usage (PowerShell, Windows):
#
#   # Default (auto-detects Steam install):
#   .\tools\sync_to_modtools.ps1
#
#   # Custom Steam install path:
#   .\tools\sync_to_modtools.ps1 -ModToolsRoot "D:\Steam\steamapps\common\Call of Duty Black Ops III"
#
#   # Dry run (prints what it would do, changes nothing):
#   .\tools\sync_to_modtools.ps1 -DryRun
#
#   # Verbose logging:
#   .\tools\sync_to_modtools.ps1 -Verbose
#
#   # Reverse sync (pull changes from Mod Tools back into the repo):
#   .\tools\sync_to_modtools.ps1 -Reverse
#
# What it does:
#   repo\maps\zm\*              -> usermaps\zm_abandoned_cyber_city\maps\zm\
#   repo\scripts\zm\zm_acc\*    -> usermaps\zm_abandoned_cyber_city\scripts\zm\zm_abandoned_cyber_city\
#   repo\zone_source\*          -> usermaps\zm_abandoned_cyber_city\zone_source\
#   repo\ui\*         (if any)  -> usermaps\zm_abandoned_cyber_city\ui\
# =============================================================================

[CmdletBinding()]
param(
    [string]$ModToolsRoot = "",
    [switch]$DryRun,
    [switch]$Reverse
)

$ErrorActionPreference = "Stop"

$MapName = "zm_abandoned_cyber_city"

function Write-Info($msg) {
    Write-Host "[sync] $msg"
}

function Resolve-ModToolsRoot {
    if ($ModToolsRoot -ne "") { return $ModToolsRoot }

    $candidates = @(
        "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III",
        "D:\Steam\steamapps\common\Call of Duty Black Ops III",
        "E:\Steam\steamapps\common\Call of Duty Black Ops III",
        "C:\Steam\steamapps\common\Call of Duty Black Ops III"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { return $c }
    }

    throw "Could not auto-detect Mod Tools install. Pass -ModToolsRoot explicitly."
}

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        if ($DryRun) {
            Write-Info "DRY: would mkdir $path"
        } else {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

function Copy-Tree($src, $dst, $label) {
    if (-not (Test-Path $src)) {
        Write-Info "skip ($label): $src does not exist"
        return
    }

    Ensure-Dir (Split-Path $dst -Parent)

    if ($DryRun) {
        Write-Info "DRY: $label: $src -> $dst"
        Get-ChildItem -Recurse $src | ForEach-Object {
            Write-Info "  DRY file: $($_.FullName)"
        }
        return
    }

    Write-Info "$label: $src -> $dst"

    # Use robocopy for speed + reliability. /MIR makes destination mirror source.
    # /NFL /NDL /NJH /NJS /NP suppresses the noisy progress spam (keeps summary).
    $rc = Start-Process robocopy -NoNewWindow -Wait -PassThru -ArgumentList @(
        "`"$src`"", "`"$dst`"",
        "/MIR", "/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/R:2", "/W:1"
    )

    # robocopy exit codes: 0 = no change, 1 = copied, 2 = extras, 3 = both.
    # Anything >= 8 is a failure.
    if ($rc.ExitCode -ge 8) {
        throw "robocopy failed ($label) with exit code $($rc.ExitCode)"
    }
}

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$ModTools = Resolve-ModToolsRoot
$MapRoot  = Join-Path $ModTools "usermaps\$MapName"

Write-Info "repo     = $RepoRoot"
Write-Info "modtools = $ModTools"
Write-Info "target   = $MapRoot"
Write-Info "mode     = $(if ($Reverse) {'REVERSE (modtools -> repo)'} else {'FORWARD (repo -> modtools)'})"
if ($DryRun) { Write-Info "DRY RUN - no files will be written" }

if (-not (Test-Path $MapRoot)) {
    Write-Warning "Target $MapRoot does not exist. Create the map in Launcher first (File -> New Map, template zm, name $MapName)."
    return
}

$mappings = @(
    @{ Label = "maps";         RepoRel = "maps\zm";                 ModRel = "maps\zm" },
    @{ Label = "scripts";      RepoRel = "scripts\zm\$MapName";     ModRel = "scripts\zm\$MapName" },
    @{ Label = "zone_source";  RepoRel = "zone_source";             ModRel = "zone_source" },
    @{ Label = "ui";           RepoRel = "ui";                      ModRel = "ui" }
)

foreach ($m in $mappings) {
    $repoPath = Join-Path $RepoRoot $m.RepoRel
    $modPath  = Join-Path $MapRoot  $m.ModRel

    if ($Reverse) {
        Copy-Tree $modPath $repoPath $m.Label
    } else {
        Copy-Tree $repoPath $modPath $m.Label
    }
}

Write-Info "done"
