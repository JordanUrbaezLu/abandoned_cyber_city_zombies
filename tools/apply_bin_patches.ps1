# =============================================================================
# apply_bin_patches.ps1 - idempotent applier/checker for the small install-side
# patches under <Mod Tools>\bin\ that NO pack zip carries and NO other script
# applied (found by the 2026-07-10 asset-portability audit).
#
# Patches handled:
#   1. bin\converter_gdt_dirs_0.txt must contain a '_custom' line (first line).
#      The Leviathan Axe GDT lives at _custom\wetegg\leviathanaxe\ and the
#      converter only scans dirs listed in this file - without the line the axe
#      weapons silently drop from every build. A Mod Tools update/verify resets
#      the file. APPLIED automatically (pure text prepend, idempotent).
#   2. bin\libtiff64r.dll must be the L3akMod v1.0.4 overwrite (stock file =
#      441,856 bytes; L3akMod = 432,640 bytes). Without it the linker errors
#      'Lua not supported' on every rawfile,*.lua (our whole custom HUD).
#      CHECK ONLY - L3akMod is third-party (dtzxporter.com/tools/l3akmod) and
#      must not be redistributed from this repo. Back up the stock DLL as
#      bin\libtiff64r.dll.acc-orig-backup before overwriting.
#
# (The stock source_data\zbarriers.gdt PaP-model patch has its own idempotent
#  script: tools\apply_pap_zbarrier_swap.ps1 - run that separately/via
#  restore_machine.ps1.)
#
# Usage:
#   .\tools\apply_bin_patches.ps1                 # apply text patches, check DLL
#   .\tools\apply_bin_patches.ps1 -CheckOnly      # report, change nothing
# =============================================================================

[CmdletBinding()]
param(
    [string]$ModToolsRoot = "",
    [switch]$CheckOnly
)

$ErrorActionPreference = "Stop"

function Write-Info($msg) { Write-Host "[bin-patches] $msg" }

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

$ModTools = Resolve-ModToolsRoot
Write-Info "modtools = $ModTools"
$fail = 0

# --- 1. converter_gdt_dirs_0.txt: ensure '_custom' line ---------------------
$gdtDirs = Join-Path $ModTools "bin\converter_gdt_dirs_0.txt"
if (-not (Test-Path $gdtDirs)) {
    Write-Info "WARN: $gdtDirs missing (Mod Tools install incomplete?) - cannot patch"
    $fail++
} else {
    $lines = Get-Content $gdtDirs
    if ($lines -contains "_custom") {
        Write-Info "ok: converter_gdt_dirs_0.txt already lists _custom"
    } elseif ($CheckOnly) {
        Write-Info "WOULD PATCH: prepend '_custom' to converter_gdt_dirs_0.txt (Leviathan Axe GDT dir)"
        $fail++
    } else {
        Set-Content -Path $gdtDirs -Value (@("_custom") + $lines) -Encoding Ascii
        Write-Info "PATCHED: prepended '_custom' to converter_gdt_dirs_0.txt"
    }
}

# --- 2. libtiff64r.dll: L3akMod check (never auto-applied) ------------------
$dll = Join-Path $ModTools "bin\libtiff64r.dll"
$stockSize = 441856
if (-not (Test-Path $dll)) {
    Write-Info "WARN: $dll missing entirely - broken Mod Tools install"
    $fail++
} else {
    $size = (Get-Item $dll).Length
    if ($size -eq $stockSize) {
        Write-Info "FAIL: bin\libtiff64r.dll is the STOCK DLL ($stockSize bytes) - custom LUI will not link ('Lua not supported')."
        Write-Info "      Install L3akMod v1.0.4: https://dtzxporter.com/tools/l3akmod (overwrite the DLL; back up the"
        Write-Info "      original as bin\libtiff64r.dll.acc-orig-backup first). Needs VS2013+VS2015 x64 runtimes."
        $fail++
    } else {
        Write-Info "ok: bin\libtiff64r.dll is not stock ($size bytes) - L3akMod assumed installed"
    }
}

if ($fail -gt 0) {
    Write-Info "$fail item(s) need attention"
    exit 1
}
Write-Info "all bin patches in place"
exit 0
