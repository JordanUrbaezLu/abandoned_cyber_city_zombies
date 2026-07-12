# =============================================================================
# read_lb_logs.ps1 - harvest a LEADERBOARD run's evidence (docs/40).
# (Replaced read_lb_spike.ps1 when the Stage-0 spike retired, 2026-07-11.)
#
# Run AFTER a test session. Prints every channel the live system writes:
#   1. console_mp.log [LB] lines - the GSC lb_log mirror of the LUI trace dvars
#      (acc_lb_rec_trace / acc_lb_board_trace / rows / dev-probe verdicts)
#   2. players\acc_lb_records.txt      - the machine-local record file (one line
#      per recorded game: session|round|names_csv|ts). Dev/god runs NEVER append.
#   3. players\acc_lb_post.json / acc_lb_post_result.txt - the last POST body +
#      the Worker's response ({"ok":true} = the row landed)
#   4. players\acc_lb_top10.txt       - the last station/probe fetch (rows +
#      ACCEOF_OK/ERR completion marker)
#
# Usage: .\tools\read_lb_logs.ps1 [-GameRoot <path>]
# =============================================================================

param([string]$GameRoot = '')

$ErrorActionPreference = 'Continue'

# --- locate the GAME root (split install: game folder has BlackOps3.exe; the
#     AppID-suffixed sibling is the MOD TOOLS root - docs/17) -----------------
if (-not $GameRoot) {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Steam\steamapps\common\Call of Duty Black Ops III",
        "$env:ProgramFiles\Steam\steamapps\common\Call of Duty Black Ops III"
    )
    foreach ($c in $candidates) {
        if ($c -and (Test-Path (Join-Path $c 'BlackOps3.exe'))) { $GameRoot = $c; break }
    }
}
if (-not $GameRoot -or -not (Test-Path (Join-Path $GameRoot 'BlackOps3.exe'))) {
    Write-Host "[lb] FAIL: game root not found (BlackOps3.exe). Pass -GameRoot <path>." -ForegroundColor Red
    exit 1
}
Write-Host "[lb] game root = $GameRoot"

function Section($title) { Write-Host "`n=== $title ===" -ForegroundColor Cyan }

# --- 1. console_mp.log [LB] lines ---------------------------------------------
Section "1. console_mp.log [LB] lines (GSC mirror of the LUI traces - durable)"
$conLog = Join-Path $GameRoot 'console_mp.log'
if (Test-Path $conLog) {
    $hits = Select-String -Path $conLog -Pattern '\[LB\]' | Select-Object -Last 40
    if ($hits) { $hits | ForEach-Object { "  $($_.Line)" } }
    else { Write-Host "no [LB] lines - module off (acc_lb_on 0?), old .ff, or log rolled." -ForegroundColor Yellow }
    Write-Host "  (log: $((Get-Item $conLog).Length) bytes, last write $((Get-Item $conLog).LastWriteTime))"
} else {
    Write-Host "console_mp.log ABSENT - was the game launched via run_game.ps1 (+set logfile 1)?" -ForegroundColor Yellow
}

# --- 2. the machine-local record file -----------------------------------------
Section "2. players\acc_lb_records.txt (local records - dev/god runs never append)"
$rec = Join-Path $GameRoot 'players\acc_lb_records.txt'
if (Test-Path $rec) {
    $lines = @(Get-Content $rec)
    Write-Host "exists: $($lines.Count) record(s), last write $((Get-Item $rec).LastWriteTime)"
    $lines | Select-Object -Last 10 | ForEach-Object { "  $_" }
} else {
    Write-Host "absent - no non-dev/god game has ended on this machine yet (expected until the first real run)." -ForegroundColor Yellow
}

# --- 3. the last POST ----------------------------------------------------------
Section "3. last cloud POST (players\acc_lb_post.json + acc_lb_post_result.txt)"
foreach ($n in 'acc_lb_post.json', 'acc_lb_post_result.txt') {
    $p = Join-Path $GameRoot "players\$n"
    if (Test-Path $p) {
        $body = (Get-Content $p -Raw)
        if ($body -and $body.Length -gt 300) { $body = $body.Substring(0, 300) + '...' }
        Write-Host "  $n ($((Get-Item $p).LastWriteTime)): $body"
    } else {
        Write-Host "  $n : absent" -ForegroundColor Yellow
    }
}

# --- 4. the last fetch ----------------------------------------------------------
Section "4. last station/probe fetch (players\acc_lb_top10.txt)"
$top = Join-Path $GameRoot 'players\acc_lb_top10.txt'
if (Test-Path $top) {
    Write-Host "exists, last write $((Get-Item $top).LastWriteTime):"
    Get-Content $top | Select-Object -First 14 | ForEach-Object { "  $_" }
} else {
    Write-Host "absent - no fetch has run yet (station never used / dev probe didn't fire)." -ForegroundColor Yellow
}
