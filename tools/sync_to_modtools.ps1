# =============================================================================
# sync_to_modtools.ps1 - Mirror the repo's authoring trees into the BO3
# Mod Tools install.
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
#   # Reverse sync (pull changes from Mod Tools back into the repo).
#   # Run this after editing the map in Radiant so the repo keeps the
#   # authoritative .map source!
#   .\tools\sync_to_modtools.ps1 -Reverse
#
# Layout facts this script encodes (verified against the stock Launcher zm
# template and shipped community maps):
#
#   repo\scripts\zm\*          -> usermaps\zm_abandoned_cyber_city\scripts\zm\*   (MIRROR)
#       (entry zm_abandoned_cyber_city.gsc/.csc + zm_abandoned_cyber_city\_acc_*.gsc)
#   repo\zone_source\*         -> usermaps\zm_abandoned_cyber_city\zone_source\*  (MIRROR)
#   repo\sound\*               -> usermaps\zm_abandoned_cyber_city\sound\*        (MIRROR)
#   repo\ui\*                  -> usermaps\zm_abandoned_cyber_city\ui\*           (MIRROR)
#   repo\zone\*                -> usermaps\zm_abandoned_cyber_city\zone\*         (COPY, no delete:
#       Launcher writes workshop.json + publish artifacts here; never clobber)
#   repo\map_source\zm\zm_abandoned_cyber_city.map
#                              -> <BO3 root>\map_source\zm\...                    (single file COPY:
#       Radiant map sources live in the game root map_source, NOT usermaps.
#       Never mirror this folder - it contains _prefabs and other maps.)
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

    # The Mod Tools may live in the game folder OR in a separate
    # "...Black Ops III 455130" folder (Steam appends the AppID on name
    # collision - this machine has that layout). The game folder alone
    # passes Test-Path but is NOT the tools root, so require the launcher
    # binary (bin\modlauncher.exe) as proof.
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

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        if ($DryRun) {
            Write-Info "DRY: would mkdir $path"
        } else {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
        }
    }
}

# Mirror = destination becomes an exact copy of source (robocopy /MIR; deletes extras).
# Copy   = overwrite-copy only; files that exist only in the destination survive.
function Copy-Tree($src, $dst, $label, $mirror) {
    if (-not (Test-Path $src)) {
        Write-Info "skip ($label): $src does not exist"
        return
    }

    Ensure-Dir (Split-Path $dst -Parent)

    if ($DryRun) {
        Write-Info "DRY: ${label}: $src -> $dst (mirror=$mirror)"
        Get-ChildItem -Recurse $src | ForEach-Object {
            Write-Info "  DRY file: $($_.FullName)"
        }
        return
    }

    Write-Info "${label}: $src -> $dst (mirror=$mirror)"

    $args = @("`"$src`"", "`"$dst`"")
    if ($mirror) { $args += "/MIR" } else { $args += "/E" }
    $args += @("/NFL", "/NDL", "/NJH", "/NJS", "/NP", "/R:2", "/W:1")

    $rc = Start-Process robocopy -NoNewWindow -Wait -PassThru -ArgumentList $args

    # robocopy exit codes: 0 = no change, 1 = copied, 2 = extras, 3 = both.
    # Anything >= 8 is a failure.
    if ($rc.ExitCode -ge 8) {
        throw "robocopy failed ($label) with exit code $($rc.ExitCode)"
    }
}

function Copy-One($src, $dst, $label) {
    if (-not (Test-Path $src)) {
        Write-Info "skip ($label): $src does not exist"
        return
    }

    Ensure-Dir (Split-Path $dst -Parent)

    if ($DryRun) {
        Write-Info "DRY: ${label}: $src -> $dst"
        return
    }

    Write-Info "${label}: $src -> $dst"
    Copy-Item -Path $src -Destination $dst -Force
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

if (-not $Reverse) {
    Ensure-Dir $MapRoot
}

# Directory trees under the usermap root.
$mappings = @(
    @{ Label = "scripts";      RepoRel = "scripts";      ModRel = "scripts";      Mirror = $true  },
    @{ Label = "zone_source";  RepoRel = "zone_source";  ModRel = "zone_source";  Mirror = $true  },
    @{ Label = "sound";        RepoRel = "sound";        ModRel = "sound";        Mirror = $true  },
    @{ Label = "ui";           RepoRel = "ui";           ModRel = "ui";           Mirror = $true  },
    @{ Label = "zone";         RepoRel = "zone";         ModRel = "zone";         Mirror = $false }
)

foreach ($m in $mappings) {
    $repoPath = Join-Path $RepoRoot $m.RepoRel
    $modPath  = Join-Path $MapRoot  $m.ModRel

    if ($Reverse) {
        # Never mirror on reverse - the repo has files (README etc.) that the
        # mod tools side legitimately lacks.
        Copy-Tree $modPath $repoPath $m.Label $false
    } else {
        Copy-Tree $repoPath $modPath $m.Label $m.Mirror
    }
}

# Radiant map source: single file into the game root's map_source\zm\.
$repoMap = Join-Path $RepoRoot "map_source\zm\$MapName.map"
$modMap  = Join-Path $ModTools "map_source\zm\$MapName.map"

if ($Reverse) {
    Copy-One $modMap $repoMap "map_source"
} else {
    Copy-One $repoMap $modMap "map_source"
}

Write-Info "done"
if (-not $Reverse) {
    Write-Info "next: open Launcher, select $MapName, Compile (map + scripts), Run Game."
}
