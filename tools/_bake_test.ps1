# _bake_test.ps1 <testMap> - deploy a .map, run cod2map + Radiant LED (timeout+kill),
# print BAKED or CRASHED. Used to bisect the LED-crash culprit brush.
param([Parameter(Mandatory=$true)][string]$TestMap, [int]$TimeoutSec = 60)
$ErrorActionPreference = 'Stop'
$Tools = "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130"
$Bin = Join-Path $Tools 'bin'; $Cod2 = Join-Path $Bin 'cod2map64.exe'; $Radiant = Join-Path $Bin 'Radiant_modtools.exe'
$MapSrc = Join-Path $Tools 'map_source\zm\zm_abandoned_cyber_city.map'
$Bsp = Join-Path $Tools 'share\raw\maps\zm\zm_abandoned_cyber_city.d3dbsp'
$Led = Join-Path $Tools 'share\raw\maps\zm\zm_abandoned_cyber_city.led'
Copy-Item $TestMap $MapSrc -Force
$codOut = New-TemporaryFile
$cod = Start-Process -FilePath $Cod2 -ArgumentList @('-platform','pc','-navmesh','-navvolume','-loadFrom',"`"$MapSrc`"","`"$Bsp`"") -WorkingDirectory $Bin -NoNewWindow -Wait -PassThru -RedirectStandardOutput $codOut.FullName
$bMt = if (Test-Path $Led) { (Get-Item $Led).LastWriteTime } else { 'none' }
$sw=[Diagnostics.Stopwatch]::StartNew()
$proc = Start-Process -FilePath $Radiant -ArgumentList @('-ledSilent','+medium','+forceclean','+recompute',"`"$MapSrc`"") -WorkingDirectory $Bin -NoNewWindow -PassThru
$ok = $proc.WaitForExit($TimeoutSec * 1000)
if (-not $ok) { Stop-Process -Id $proc.Id -Force -EA SilentlyContinue; Get-Process Radiant_modtools -EA SilentlyContinue|Stop-Process -Force -EA SilentlyContinue }
Start-Sleep -Milliseconds 600
$aMt = if (Test-Path $Led) { (Get-Item $Led).LastWriteTime } else { 'none' }
$secs = [math]::Round($sw.Elapsed.TotalSeconds,1)
if ($ok -and ($aMt -ne $bMt)) { Write-Host "RESULT: BAKED  (LED $secs s, .led refreshed)" -ForegroundColor Green }
else { Write-Host "RESULT: CRASHED  (LED hung/killed at $secs s, .led unchanged)" -ForegroundColor Yellow }