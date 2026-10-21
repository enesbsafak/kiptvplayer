# Captures every screen of the release build without touching the desktop:
# the window is created off-screen, never activated, with no audio device.
# Requires tools/mock-iptv running (cargo run -p mock-iptv --release -- 8089).
#
#   tools\shots.ps1 [-Out <dir>] [-Mock http://127.0.0.1:8089] [-Phone 390x844]
param(
  [string]$Out = (Join-Path $env:TEMP 'karadelik-shots'),
  [string]$Mock = 'http://127.0.0.1:8089',
  # Release or Profile; Profile is handy while a Release build is open.
  [string]$Build = 'Release',
  # tr or en: the UI language of the captures.
  [string]$Language = 'tr',
  # The compact (phone) layout at this size, e.g. 390x844.
  [string]$Phone,
  # Pixels per layout pixel: -Phone 360x640 -Scale 3 gives 1080x1920.
  [double]$Scale = 1
)
$ErrorActionPreference = 'Stop'
Add-Type @'
using System; using System.Runtime.InteropServices;
public class KpForeground {
  [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint p);
  public static uint ForegroundProcess() { uint p; GetWindowThreadProcessId(GetForegroundWindow(), out p); return p; }
}
'@

$exeDir = Join-Path $PSScriptRoot "..\apps\player\build\windows\x64\runner\$Build" | Resolve-Path
$data = Join-Path $Out 'appdata'
Remove-Item -Recurse -Force $Out -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force $Out | Out-Null

# TMDB answers come from the mock too (its /3 and /t/p routes).
$env:KP_TMDB_BASE = $Mock
# OpenSubtitles too (/os routes): captures never reach the real service.
$env:KP_OPENSUBS_BASE = "$Mock/os/api/v1"

$p = Start-Process (Join-Path $exeDir 'karadelik_player.exe') -WorkingDirectory $exeDir -WindowStyle Hidden -PassThru `
  -ArgumentList (@('--kp-offscreen', "--kp-data-dir=$data", "--kp-add-mock=$Mock", "--kp-shot=$Out", '--kp-tmdb-key=kp-mock-tmdb-key', "--kp-language=$Language") +
    $(if ($Phone) { @("--kp-phone=$Phone") } else { @() }) + @("--kp-shot-scale=$Scale"))
$stoleFocus = $false
$sw = [Diagnostics.Stopwatch]::StartNew()
while (-not $p.HasExited -and $sw.Elapsed.TotalSeconds -lt 180) {
  # Only the app itself taking the foreground counts: the user may well be
  # switching windows meanwhile.
  if ([KpForeground]::ForegroundProcess() -eq $p.Id) { $stoleFocus = $true }
  Start-Sleep -Milliseconds 50
}
if (-not $p.HasExited) { $p.Kill(); throw 'timed out' }
"done in $([int]$sw.Elapsed.TotalSeconds) s; app took focus: $stoleFocus; shots in $Out"
Get-ChildItem $Out -Filter *.png | ForEach-Object { $_.Name }
