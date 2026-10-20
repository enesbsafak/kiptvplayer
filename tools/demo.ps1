# Opens the release build in a normal window against the local mock provider,
# with its own data folder so it never touches a real library.
#
#   tools\demo.ps1
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$mockUrl = 'http://127.0.0.1:8089'

try {
  Invoke-WebRequest "$mockUrl/player_api.php?username=demo&password=demo" -UseBasicParsing -TimeoutSec 2 | Out-Null
} catch {
  $mock = Join-Path $root 'target\release\mock-iptv.exe'
  if (-not (Test-Path $mock)) { cargo build -p mock-iptv --release --manifest-path (Join-Path $root 'Cargo.toml') }
  Start-Process $mock -ArgumentList '8089' -WindowStyle Hidden
  Start-Sleep -Milliseconds 500
}

$exeDir = Join-Path $root 'apps\desktop\build\windows\x64\runner\Release'
$data = Join-Path $env:LOCALAPPDATA 'KaradelikPlayer\demo-data'
Start-Process (Join-Path $exeDir 'karadelik_player.exe') -WorkingDirectory $exeDir `
  -ArgumentList "--kp-data-dir=$data", "--kp-add-mock=$mockUrl"
"Demo açıldı. Mock sağlayıcı: $mockUrl (demo / demo)"
