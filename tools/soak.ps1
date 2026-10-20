# Long-run leak check: the app plays live TV off-screen and silently,
# changing channel every minute, while this script samples its memory.
# Flat memory after warm-up = no leak. Requires tools/mock-iptv running.
#
#   tools\soak.ps1 [-Minutes 240] [-Build Profile|Release] [-Out <dir>]
param(
  [int]$Minutes = 240,
  [string]$Build = 'Release',
  [string]$Mock = 'http://127.0.0.1:8089',
  [string]$Out = (Join-Path $env:TEMP 'karadelik-soak')
)
$ErrorActionPreference = 'Stop'
$exeDir = Join-Path $PSScriptRoot "..\apps\desktop\build\windows\x64\runner\$Build" | Resolve-Path
New-Item -ItemType Directory -Force $Out | Out-Null
$data = Join-Path $Out 'appdata'
Remove-Item -Recurse -Force $data -ErrorAction SilentlyContinue
$csv = Join-Path $Out 'memory.csv'
'minute,private_mb,working_set_mb,handles' | Set-Content $csv

$p = Start-Process (Join-Path $exeDir 'karadelik_player.exe') -WorkingDirectory $exeDir -WindowStyle Hidden -PassThru `
  -ArgumentList '--kp-offscreen', "--kp-data-dir=$data", "--kp-add-mock=$Mock", "--kp-soak=$Minutes"
$sw = [Diagnostics.Stopwatch]::StartNew()
while (-not $p.HasExited) {
  Start-Sleep -Seconds 30
  try {
    $p.Refresh()
    # Invariant culture: a Turkish locale would write decimal commas into the CSV.
    [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0:F1},{1:F0},{2:F0},{3}',
      $sw.Elapsed.TotalMinutes, ($p.PrivateMemorySize64 / 1MB), ($p.WorkingSet64 / 1MB), $p.HandleCount) | Add-Content $csv
  } catch {}
  if ($sw.Elapsed.TotalMinutes -gt $Minutes + 10) { $p.Kill(); throw 'soak run did not finish' }
}

# Growth after the first 10 minutes (decoders, caches and fonts warm up first).
$rows = Import-Csv $csv | Where-Object { [double]$_.minute -ge 10 }
if ($rows.Count -ge 2) {
  $first = [double]$rows[0].private_mb; $last = [double]$rows[-1].private_mb
  $hours = ([double]$rows[-1].minute - [double]$rows[0].minute) / 60
  "private memory {0:N0} MB -> {1:N0} MB over {2:N1} h after warm-up ({3:N1} MB/h)" -f $first, $last, $hours, (($last - $first) / [math]::Max($hours, 0.01))
  "handles {0} -> {1}" -f $rows[0].handles, $rows[-1].handles
}
"samples: $csv"
