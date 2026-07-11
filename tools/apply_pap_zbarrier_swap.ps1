# apply_pap_zbarrier_swap.ps1 - re-apply the CW/BO6 Pack-a-Punch machine model swap to the
# INSTALL-SIDE zbarriers.gdt (source_data is un-tracked + not touched by sync_to_modtools, so a
# Mod Tools reinstall silently reverts this edit - exactly what the 2026-07-03 new-box setup did
# to the original 2026-07-02 edit; rediscovered 2026-07-09 "lab still has the old PaP model").
#
# The edit (verbatim the 2026-07-02 "3rd attempt, asset level" fix - runtime SetModel and
# per-entity zbarrierboardModelN were both proven inert on the PaP zbarrier):
#   zbarriers.gdt "zmcore_packapunch":
#     boardModel1  p7_zm_vending_packapunch     -> p9_fxanim_zm_gp_pap_xmodel_off  (power OFF machine)
#     boardModel2  p7_zm_vending_packapunch_on  -> p9_fxanim_zm_gp_pap_xmodel      (power ON machine)
#     boardModel5  p7_zm_vending_packapunch_on  -> p9_fxanim_zm_gp_pap_xmodel      (working loop board)
#     boardAnim1/2/5 -> "" (the p9 statics can't play the o_zombie_base_packapunch anims)
#   (boards 3/4 - the DER2 sign + the weapon-display board - stay stock, as the original edit had it.)
#
# Both p9 xmodels ship with the ALXS pack (check_external_assets.ps1 gates it) and are zone-listed
# (zone_source lines xmodel,p9_fxanim_zm_gp_pap_xmodel[_off]) - the Paradise custom PaP vendor
# SetModels the same p9 model directly and is the in-game proof it renders.
#
# Idempotent: exits 0 with no change when the edit is already present. On a real edit it deletes
# gdtDB\gdt.db and runs gdtdb.exe (full rebuild - the RELIABLE pattern; gdtdb change-detection has
# twice returned 0-GDTs on real edits, CHANGELOG 2026-07-02). Then run a build (-GscOnly is enough:
# the linker repacks the zbarrier asset from the fresh db; no geometry change).

[CmdletBinding()]
param(
    [string]$ModToolsRoot = ""
)

$ErrorActionPreference = "Stop"

# Tools root resolution order (red-team fix 2026-07-10 — restore_machine.ps1 passes
# -ModToolsRoot; before this the script silently fell to a hardcoded C:\ path on any
# non-default install): explicit param -> TA_TOOLS_PATH -> known fallback.
$tools = ""
if ($ModToolsRoot -ne "" -and (Test-Path (Join-Path $ModToolsRoot "bin\modlauncher.exe"))) {
    $tools = $ModToolsRoot
}
if ($tools -eq "") {
    $tools = $env:TA_TOOLS_PATH
    if (-not $tools -or -not (Test-Path (Join-Path $tools "bin\modlauncher.exe"))) {
        $tools = "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130"
    }
}
if (-not (Test-Path (Join-Path $tools "bin\modlauncher.exe"))) {
    throw "Mod Tools root not found (no -ModToolsRoot, TA_TOOLS_PATH unset, fallback missing modlauncher.exe)"
}

$gdt = Join-Path $tools "source_data\zbarriers.gdt"
if (-not (Test-Path $gdt)) { throw "missing $gdt" }

$raw = Get-Content $gdt -Raw
if ($raw -match "p9_fxanim_zm_gp_pap_xmodel") {
    Write-Host "[pap-swap] already applied (p9 refs present in zbarriers.gdt) - nothing to do"
    exit 0
}

# Backup once (never clobber an existing stock backup).
$bak = "$gdt.acc-orig"
if (-not (Test-Path $bak)) {
    Copy-Item $gdt $bak
    Write-Host "[pap-swap] backup written: $bak"
}

$lines = Get-Content $gdt
$si = -1
for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '"zmcore_packapunch"') { $si = $i; break }
}
if ($si -lt 0) { throw "zmcore_packapunch block not found in zbarriers.gdt" }
$ei = -1
for ($i = $si + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^\s*\}\s*$') { $ei = $i; break }
}
if ($ei -lt 0) { throw "zmcore_packapunch block end not found" }

$edits = 0
for ($i = $si; $i -le $ei; $i++) {
    $l = $lines[$i]
    $new = $l
    if     ($l -match '^\s*"boardModel1"') { $new = $l -replace '("boardModel1"\s+)"[^"]*"', '$1"p9_fxanim_zm_gp_pap_xmodel_off"' }
    elseif ($l -match '^\s*"boardModel2"') { $new = $l -replace '("boardModel2"\s+)"[^"]*"', '$1"p9_fxanim_zm_gp_pap_xmodel"' }
    elseif ($l -match '^\s*"boardModel5"') { $new = $l -replace '("boardModel5"\s+)"[^"]*"', '$1"p9_fxanim_zm_gp_pap_xmodel"' }
    elseif ($l -match '^\s*"boardAnim1"')  { $new = $l -replace '("boardAnim1"\s+)"[^"]*"',  '$1""' }
    elseif ($l -match '^\s*"boardAnim2"')  { $new = $l -replace '("boardAnim2"\s+)"[^"]*"',  '$1""' }
    elseif ($l -match '^\s*"boardAnim5"')  { $new = $l -replace '("boardAnim5"\s+)"[^"]*"',  '$1""' }
    if ($new -ne $l) {
        $lines[$i] = $new
        $edits++
        Write-Host ("[pap-swap] " + $l.Trim() + "  ->  " + $new.Trim())
    }
}
if ($edits -ne 6) { throw "expected 6 line edits in the zmcore_packapunch block, made $edits - GDT layout changed, review by hand" }

Set-Content -Path $gdt -Value $lines -Encoding Ascii
Write-Host "[pap-swap] zbarriers.gdt updated ($edits lines)"

# Full gdt.db rebuild - the reliable pattern (delete + gdtdb regenerate).
$db = Join-Path $tools "gdtDB\gdt.db"
if (Test-Path $db) {
    Remove-Item $db -Force
    Write-Host "[pap-swap] deleted $db (forcing full rebuild)"
}
Push-Location $tools
try {
    & (Join-Path $tools "gdtdb\gdtdb.exe") /update
    if ($LASTEXITCODE -ne 0) { throw "gdtdb.exe /update exited $LASTEXITCODE" }
}
finally { Pop-Location }
Write-Host "[pap-swap] gdt.db rebuilt - now run .\tools\build_map.ps1 -GscOnly and verify in game (dev probe prints the live PaP machine model)"
