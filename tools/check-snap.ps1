# Verifies the Snap Layouts wiring without touching the desktop: launches the
# app off-screen and asks the window what sits under the maximize button.
# Windows 11 shows the Snap flyout only where WM_NCHITTEST returns HTMAXBUTTON.
#
#   tools\check-snap.ps1 [-Build Release|Profile]
param([string]$Build = 'Release')
$ErrorActionPreference = 'Stop'
Add-Type @'
using System; using System.Runtime.InteropServices;
public class KpWin {
  [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
  public static IntPtr Point(int x, int y) { return (IntPtr)(((y & 0xFFFF) << 16) | (x & 0xFFFF)); }
}
'@

$exeDir = Join-Path $PSScriptRoot "..\apps\desktop\build\windows\x64\runner\$Build" | Resolve-Path
$data = Join-Path $env:TEMP 'karadelik-snap-check'
$p = Start-Process (Join-Path $exeDir 'karadelik_player.exe') -WorkingDirectory $exeDir -WindowStyle Hidden -PassThru `
  -ArgumentList '--kp-offscreen', "--kp-data-dir=$data"
try {
  $hwnd = [IntPtr]::Zero
  for ($i = 0; $i -lt 100 -and $hwnd -eq [IntPtr]::Zero; $i++) {
    Start-Sleep -Milliseconds 100
    $p.Refresh(); $hwnd = $p.MainWindowHandle
  }
  if ($hwnd -eq [IntPtr]::Zero) { throw 'window not found' }
  Start-Sleep -Seconds 2   # let Flutter lay out and report the button

  $r = New-Object KpWin+RECT
  [void][KpWin]::GetWindowRect($hwnd, [ref]$r)
  $scale = [KpWin]::GetDpiForWindow($hwnd) / 96.0
  $width = $r.Right - $r.Left
  # Window buttons are 44 logical px each: [min][max][close] at the right edge.
  $maxX = $r.Left + [int]($width - 66 * $scale)
  $midY = $r.Top + [int](22 * $scale)
  $titleX = $r.Left + [int](300 * $scale)

  $onMax = [int][KpWin]::SendMessage($hwnd, 0x84, [IntPtr]::Zero, [KpWin]::Point($maxX, $midY))
  $onTitle = [int][KpWin]::SendMessage($hwnd, 0x84, [IntPtr]::Zero, [KpWin]::Point($titleX, $midY))
  "maximize button -> $onMax (want 9 = HTMAXBUTTON)"
  "title area      -> $onTitle (want 1 = HTCLIENT)"
  if ($onMax -ne 9) { throw 'Snap Layouts hit-test failed' }
  'OK'
} finally {
  if (-not $p.HasExited) { $p.Kill() }
}
