# Captures every screen of the release build without touching the desktop:
# the window is created off-screen, never activated, with no audio device.
# Requires tools/mock-iptv running (cargo run -p mock-iptv --release -- 8089).
#
#   tools\shots.ps1 [-Out <dir>] [-Mock http://127.0.0.1:8089]
param(
  [string]$Out = (Join-Path $env:TEMP 'karadelik-shots'),
  [string]$Mock = 'http://127.0.0.1:8089',
  # Release or Profile; Profile is handy while a Release build is open.
  [string]$Build = 'Release'
)
$ErrorActionPreference = 'Stop'
Add-Type @'
using System; using System.Runtime.InteropServices;
public class KpForeground { [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); }
'@

$exeDir = Join-Path $PSScriptRoot "..\apps\desktop\build\windows\x64\runner\$Build" | Resolve-Path
$data = Join-Path $Out 'appdata'
Remove-Item -Recurse -Force $Out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $Out | Out-Null

$before = [KpForeground]::GetForegroundWindow()
$p = Start-Process (Join-Path $exeDir 'karadelik_player.exe') -WorkingDirectory $exeDir -WindowStyle Hidden -PassThru `
  -ArgumentList '--kp-offscreen', "--kp-data-dir=$data", "--kp-add-mock=$Mock", "--kp-shot=$Out"
$stoleFocus = $false
$sw = [Diagnostics.Stopwatch]::StartNew()
while (-not $p.HasExited -and $sw.Elapsed.TotalSeconds -lt 180) {
  if ([KpForeground]::GetForegroundWindow() -ne $before) { $stoleFocus = $true }
  Start-Sleep -Milliseconds 50
}
if (-not $p.HasExited) { $p.Kill(); throw 'timed out' }
"done in $([int]$sw.Elapsed.TotalSeconds) s; focus changed: $stoleFocus; shots in $Out"
Get-ChildItem $Out -Filter *.png | ForEach-Object { $_.Name }
