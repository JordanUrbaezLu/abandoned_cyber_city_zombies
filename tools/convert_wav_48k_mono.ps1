# Convert a PCM WAV to 48 kHz / 16-bit / mono (BO3 3D-SFX convention).
# No ffmpeg dependency: parses RIFF chunks, downmixes to mono, linear-resamples to 48k.
# Usage: .\convert_wav_48k_mono.ps1 -In <src.wav> -Out <dst.wav>
param([Parameter(Mandatory=$true)][string]$In, [Parameter(Mandatory=$true)][string]$Out)

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

# Decode interleaved 16-bit samples -> mono float frames.
$bytesPerSample = 2
$frameCount = [int]($dataLen / ($bytesPerSample * $channels))
$mono = New-Object 'double[]' $frameCount
for ($f = 0; $f -lt $frameCount; $f++) {
    $acc = 0.0
    for ($c = 0; $c -lt $channels; $c++) {
        $off = $dataOff + ($f*$channels + $c)*2
        $acc += [BitConverter]::ToInt16($bytes,$off)
    }
    $mono[$f] = $acc / $channels
}

# Linear-resample mono -> 48000 Hz.
$outRate = 48000
$outCount = [int]([math]::Floor($frameCount * $outRate / $rate))
$outShorts = New-Object 'int16[]' $outCount
$ratio = $rate / [double]$outRate
for ($i = 0; $i -lt $outCount; $i++) {
    $src = $i * $ratio
    $i0 = [int][math]::Floor($src)
    $frac = $src - $i0
    $s0 = $mono[$i0]
    $s1 = if ($i0+1 -lt $frameCount) { $mono[$i0+1] } else { $s0 }
    $v = [math]::Round($s0 + ($s1-$s0)*$frac)
    if ($v -gt 32767) { $v = 32767 } elseif ($v -lt -32768) { $v = -32768 }
    $outShorts[$i] = [int16]$v
}

# Write 48k/16-bit/mono WAV.
$dataBytes = $outCount * 2
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([System.Text.Encoding]::ASCII.GetBytes('RIFF'))
$bw.Write([uint32](36 + $dataBytes))
$bw.Write([System.Text.Encoding]::ASCII.GetBytes('WAVE'))
$bw.Write([System.Text.Encoding]::ASCII.GetBytes('fmt '))
$bw.Write([uint32]16)
$bw.Write([uint16]1)              # PCM
$bw.Write([uint16]1)              # mono
$bw.Write([uint32]$outRate)
$bw.Write([uint32]($outRate*2))   # byte rate (mono*16bit)
$bw.Write([uint16]2)              # block align
$bw.Write([uint16]16)             # bits
$bw.Write([System.Text.Encoding]::ASCII.GetBytes('data'))
$bw.Write([uint32]$dataBytes)
foreach ($s in $outShorts) { $bw.Write([int16]$s) }
$bw.Flush()
[System.IO.File]::WriteAllBytes($Out, $ms.ToArray())
Write-Host "out: ${outRate}Hz 1ch 16bit  frames=$outCount  -> $Out"
