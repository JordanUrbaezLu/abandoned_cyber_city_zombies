# Convert a PCM WAV to 48 kHz / 16-bit, PRESERVING channel count (stereo stays
# stereo) - the BO3 convention for 2D music/streamed aliases (acc_main_theme).
# Companion to convert_wav_48k_mono.ps1 (which force-downmixes to mono for 3D SFX).
# No ffmpeg dependency: parses RIFF chunks, linear-resamples each channel to 48k.
# Optional -TrimSeconds keeps only the first N seconds (0 / omitted = full length).
# Usage: .\convert_wav_48k_stereo.ps1 -In <src.wav> -Out <dst.wav> [-TrimSeconds 30]
param(
    [Parameter(Mandatory=$true)][string]$In,
    [Parameter(Mandatory=$true)][string]$Out,
    [double]$TrimSeconds = 0
)

$bytes = [System.IO.File]::ReadAllBytes($In)
if ([System.Text.Encoding]::ASCII.GetString($bytes,0,4) -ne 'RIFF' -or
    [System.Text.Encoding]::ASCII.GetString($bytes,8,4) -ne 'WAVE') { throw "not a RIFF/WAVE file" }

# Walk chunks to find fmt + data.
$pos = 12; $channels=0; $rate=0; $bits=0; $dataOff=0; $dataLen=0
while ($pos + 8 -le $bytes.Length) {
    $id = [System.Text.Encoding]::ASCII.GetString($bytes,$pos,4)
    $sz = [BitConverter]::ToUInt32($bytes,$pos+4)
    $body = $pos + 8
    if ($id -eq 'fmt ') {
        $fmt      = [BitConverter]::ToUInt16($bytes,$body)
        $channels = [BitConverter]::ToUInt16($bytes,$body+2)
        $rate     = [BitConverter]::ToUInt32($bytes,$body+4)
        $bits     = [BitConverter]::ToUInt16($bytes,$body+14)
        if ($fmt -ne 1) { throw "only PCM (fmt=1) supported, got $fmt" }
    } elseif ($id -eq 'data') { $dataOff = $body; $dataLen = $sz }
    $pos = $body + $sz + ($sz % 2)   # chunks are word-aligned
}
if ($bits -ne 16) { throw "only 16-bit PCM supported, got $bits" }
Write-Host "in: ${rate}Hz ${channels}ch ${bits}bit  data=$dataLen bytes"

# Decode interleaved 16-bit -> per-channel float arrays.
$frameCount = [int]($dataLen / (2 * $channels))
if ($TrimSeconds -gt 0) {
    $maxFrames = [int]($TrimSeconds * $rate)
    if ($maxFrames -lt $frameCount) { $frameCount = $maxFrames }
}
$ch = New-Object 'double[][]' $channels
for ($c = 0; $c -lt $channels; $c++) { $ch[$c] = New-Object 'double[]' $frameCount }
for ($f = 0; $f -lt $frameCount; $f++) {
    $base = $dataOff + $f*$channels*2
    for ($c = 0; $c -lt $channels; $c++) {
        $ch[$c][$f] = [BitConverter]::ToInt16($bytes, $base + $c*2)
    }
}

# Linear-resample each channel to 48000 Hz.
$outRate = 48000
$outCount = [int]([math]::Floor($frameCount * $outRate / $rate))
$ratio = $rate / [double]$outRate
$outCh = New-Object 'int16[][]' $channels
for ($c = 0; $c -lt $channels; $c++) {
    $arr = New-Object 'int16[]' $outCount
    $src = $ch[$c]
    for ($i = 0; $i -lt $outCount; $i++) {
        $s = $i * $ratio
        $i0 = [int][math]::Floor($s)
        $frac = $s - $i0
        $s0 = $src[$i0]
        $s1 = if ($i0+1 -lt $frameCount) { $src[$i0+1] } else { $s0 }
        $v = [math]::Round($s0 + ($s1-$s0)*$frac)
        if ($v -gt 32767) { $v = 32767 } elseif ($v -lt -32768) { $v = -32768 }
        $arr[$i] = [int16]$v
    }
    $outCh[$c] = $arr
}

# Write 48k/16-bit/<channels> WAV (re-interleave).
$dataBytes = $outCount * $channels * 2
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
$bw.Write([uint32](36 + $dataBytes))
$bw.Write([System.Text.Encoding]::ASCII.GetBytes('WAVE'))
$bw.Write([System.Text.Encoding]::ASCII.GetBytes('fmt '))
$bw.Write([uint32]16)
$bw.Write([uint16]1)                          # PCM
$bw.Write([uint16]$channels)
$bw.Write([uint32]$outRate)
$bw.Write([uint32]($outRate*$channels*2))     # byte rate
$bw.Write([uint16]($channels*2))              # block align
$bw.Write([uint16]16)                         # bits
$bw.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
$bw.Write([uint32]$dataBytes)
for ($i = 0; $i -lt $outCount; $i++) {
    for ($c = 0; $c -lt $channels; $c++) { $bw.Write([int16]$outCh[$c][$i]) }
}
$bw.Flush()
[System.IO.File]::WriteAllBytes($Out, $ms.ToArray())
$dur = [math]::Round($outCount / [double]$outRate, 1)
Write-Host "out: ${outRate}Hz ${channels}ch 16bit  frames=$outCount  dur=${dur}s  -> $Out"
