# Builds a release: app (with its version baked in), signed if configured,
# the per-user installer, and latest.json for the in-app updater.
#
#   tools\release.ps1 [-Version 0.2.0] [-BaseUrl https://.../releases/download/v{0}]
#                     [-Configuration Release|Profile]
#
# Output in dist\: KaradelikIPTVPlayer-Setup-<version>.exe and latest.json.
#
# Release notes for the update dialog come from UTF-8 files (command-line
# arguments lose Turkish characters in Windows PowerShell):
#   tools\release-notes\<version>.tr.txt and <version>.en.txt
#
# Code signing (optional): set KP_SIGN_CMD to a command that signs the file
# given as {file}, e.g. Azure Trusted Signing:
#   $env:KP_SIGN_CMD = 'signtool sign /v /fd SHA256 /tr http://timestamp.acs.microsoft.com /td SHA256 /dlib "<Azure.CodeSigning.Dlib.dll>" /dmdf "<metadata.json>" "{file}"'
# Without it the build is unsigned and SmartScreen will warn.
param(
  [string]$Version,
  [string]$BaseUrl = 'https://github.com/enesbsafak/kiptvplayer/releases/download/v{0}',
  [string]$Configuration = 'Release'
)
$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '..')
$app = Join-Path $root 'apps\desktop'
$dist = Join-Path $root 'dist'

if (-not $Version) {
  # pubspec "version: 0.2.0+5" -> 0.2.0
  $line = Select-String -Path (Join-Path $app 'pubspec.yaml') -Pattern '^version:\s*([0-9][^+\s]*)' | Select-Object -First 1
  $Version = $line.Matches[0].Groups[1].Value
}
"Version $Version ($Configuration)"

$iscc = @("$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe", "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe", "$env:ProgramFiles\Inno Setup 6\ISCC.exe") |
  Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { throw 'Inno Setup 6 not found (winget install JRSoftware.InnoSetup --scope user)' }

function Invoke-Sign([string]$file) {
  if (-not $env:KP_SIGN_CMD) { return }
  $cmd = $env:KP_SIGN_CMD.Replace('{file}', $file)
  & cmd.exe /c $cmd
  if ($LASTEXITCODE -ne 0) { throw "signing failed: $file" }
}

function Read-Notes([string]$lang) {
  $file = Join-Path $PSScriptRoot "release-notes\$Version.$lang.txt"
  if (Test-Path $file) { return [IO.File]::ReadAllText($file, [Text.Encoding]::UTF8).Trim() }
  return ''
}

# 1. App, with the version the About page and the updater compare against.
Push-Location $app
try {
  $mode = $Configuration.ToLower()
  flutter build windows "--$mode" "--dart-define=KP_VERSION=$Version"
  if ($LASTEXITCODE -ne 0) { throw 'flutter build failed (is a Release build of the app running?)' }
} finally { Pop-Location }
$buildDir = Join-Path $app "build\windows\x64\runner\$Configuration"
Invoke-Sign (Join-Path $buildDir 'karadelik_player.exe')

# 2. Installer.
New-Item -ItemType Directory -Force $dist | Out-Null
$isccArgs = @("/DAppVersion=$Version", "/DBuildDir=$buildDir", '/Q')
if ($env:KP_SIGN_CMD) { $isccArgs += @('/DUseSign', "/Skpsign=$($env:KP_SIGN_CMD.Replace('{file}', '$f'))") }
& $iscc @isccArgs (Join-Path $PSScriptRoot 'installer\karadelik.iss')
if ($LASTEXITCODE -ne 0) { throw 'installer build failed' }
$setup = Join-Path $dist "KaradelikIPTVPlayer-Setup-$Version.exe"

# 3. Update feed.
$sha = (Get-FileHash $setup -Algorithm SHA256).Hash.ToLower()
$feed = [ordered]@{
  version   = $Version
  url       = ($BaseUrl -f $Version) + "/KaradelikIPTVPlayer-Setup-$Version.exe"
  sha256    = $sha
  notes     = [ordered]@{ tr = (Read-Notes 'tr'); en = (Read-Notes 'en') }
  published = (Get-Date -Format 'yyyy-MM-dd')
}
$json = $feed | ConvertTo-Json -Depth 3
[IO.File]::WriteAllText((Join-Path $dist 'latest.json'), $json, [Text.UTF8Encoding]::new($false))

"installer: $setup ($([math]::Round((Get-Item $setup).Length / 1MB, 1)) MB)"
"sha256:    $sha"
"feed:      $(Join-Path $dist 'latest.json')"
if (-not $env:KP_SIGN_CMD) { 'note: unsigned (set KP_SIGN_CMD to sign)' }
