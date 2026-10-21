# Long-run leak check: the app plays live TV off-screen and silently,
# changing channel every minute, while this script samples its memory.
# Flat memory after warm-up = no leak. Requires tools/mock-iptv running.
#
#   tools\soak.ps1 [-Minutes 240] [-Every 60] [-Build Profile|Release] [-Out <dir>]
#                  [-Channels 40] [-Mpv "hwdec=no;vid=no"]
#
# -Channels and -Mpv narrow down where memory goes: fewer distinct channels,
# or mpv properties set after the app's own.
param(
  [int]$Minutes = 240,
  # Seconds between channel changes (fewer = harsher).
  [int]$Every = 60,
  [string]$Build = 'Release',
  [string]$Mock = 'http://127.0.0.1:8089',
  [string]$Out = (Join-Path $env:TEMP 'karadelik-soak'),
  [int]$Channels = 40,
  [string]$Mpv = ''
)
$ErrorActionPreference = 'Stop'
$exeDir = Join-Path $PSScriptRoot "..\apps\desktop\build\windows\x64\runner\$Build" | Resolve-Path
New-Item -ItemType Directory -Force $Out | Out-Null
$data = Join-Path $Out 'appdata'
Remove-Item -Recurse -Force $data -ErrorAction SilentlyContinue
$csv = Join-Path $Out 'memory.csv'
'minute,private_mb,working_set_mb,handles' | Set-Content $csv

$env:KP_MPV_EXTRA = $Mpv
$p = Start-Process (Join-Path $exeDir 'karadelik_player.exe') -WorkingDirectory $exeDir -WindowStyle Hidden -PassThru `
  -ArgumentList '--kp-offscreen', "--kp-data-dir=$data", "--kp-add-mock=$Mock", "--kp-soak=$Minutes", "--kp-soak-every=$Every", "--kp-soak-channels=$Channels"
$sw = [Diagnostics.Stopwatch]::StartNew()
while (-not $p.HasExited) {
  Start-Sleep -Seconds ([math]::Min(30, [math]::Max(2, [math]::Floor($Every / 2))))
  try {
    $p.Refresh()
    if ($p.HasExited) { break }
    # Invariant culture: a Turkish locale would write decimal commas into the CSV.
    [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:F1},{1:F0},{2:F0},{3}',
      $sw.Elapsed.TotalMinutes, ($p.PrivateMemorySize64 / 1MB), ($p.WorkingSet64 / 1MB), $p.HandleCount) | Add-Content $csv
  } catch {}
  if ($sw.Elapsed.TotalMinutes -gt $Minutes + 10) { $p.Kill(); throw 'soak run did not finish' }
}

# Memory swings with the channel playing (a 4K stream holds ~200 MB more
# decoder and cache buffers than 720p), so single samples mislead. Compare
# the lowest reading in each fifth of the run after warm-up (decoders, caches
# and fonts warm up first): a leak raises the floor, a big stream does not.
$warm = [math]::Min(10, $Minutes / 3)
# Rows taken after the app exited read 0: left out.
$rows = @(Import-Csv $csv | Where-Object { [double]$_.minute -ge $warm -and [double]$_.private_mb -gt 0 })
if ($rows.Count -ge 5) {
  $t0 = [double]$rows[0].minute; $span = [double]$rows[-1].minute - $t0
  $floors = foreach ($k in 0..4) {
    $lo = $t0 + $span * $k / 5; $hi = $t0 + $span * ($k + 1) / 5
    ($rows | Where-Object { [double]$_.minute -ge $lo -and [double]$_.minute -le $hi } | ForEach-Object { [double]$_.private_mb } | Measure-Object -Minimum).Minimum
  }
  $hours = $span / 60
  "private memory floor by fifth: {0} MB" -f ($floors -join ' / ')
  "floor change {0:N0} MB over {1:N1} h after warm-up ({2:N1} MB/h)" -f ($floors[-1] - $floors[0]), $hours, (($floors[-1] - $floors[0]) / [math]::Max($hours, 0.01))
  "handles {0} -> {1}" -f $rows[0].handles, $rows[-1].handles
}
"samples: $csv"
