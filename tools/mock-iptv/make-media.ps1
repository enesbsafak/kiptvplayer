# Generates the spike's test streams into tools/mock-iptv/media (git-ignored).
# Each picture carries a running clock so latency is visible on screen.
# Native tools write progress to stderr; success is judged by exit code.
#
#   make-media.ps1           silent audio (default: tests never make a sound)
#   make-media.ps1 -Audio    a quiet chord, a different pitch per stream, for
#                            trying sound and zapping by hand in the demo
param([switch]$Audio)
$ErrorActionPreference = 'Continue'
$media = Join-Path $PSScriptRoot 'media'
New-Item -ItemType Directory -Force -Path "$media\hls720", "$media\hls1080" | Out-Null

$seconds = 120
$clock = "drawtext=fontfile='C\:/Windows/Fonts/consola.ttf':text='%{pts\:hms}':x=40:y=40:fontsize=64:fontcolor=white:box=1:boxcolor=black@0.6"

# Root and fifth at about -20 dBFS, swelling slowly so it is not a piercing beep.
function Tone([double]$hz) {
  if (-not $Audio) { return 'anullsrc=r=48000:cl=stereo' }
  $fifth = $hz * 1.5
  "aevalsrc='(0.07*sin(2*PI*$hz*t)+0.04*sin(2*PI*$fifth*t))*(0.75+0.25*sin(2*PI*0.25*t))':s=48000:c=stereo"
}

function Source([string]$size, [int]$fps, [double]$hz) {
  @('-f', 'lavfi', '-i', "testsrc2=size=${size}:rate=$fps", '-f', 'lavfi', '-i', (Tone $hz), '-t', "$seconds")
}

$common = @('-y', '-hide_banner', '-loglevel', 'error')

function Check([string]$what) { if ($LASTEXITCODE -ne 0) { throw "ffmpeg failed: $what" } }
$aac = @('-c:a', 'aac', '-b:a', '128k')

ffmpeg @common @(Source '1280x720' 25 220) -vf $clock -c:v libx264 -preset veryfast -g 50 -keyint_min 50 -sc_threshold 0 @aac `
  -f hls -hls_time 2 -hls_playlist_type vod "$media\hls720\index.m3u8"; Check hls720

ffmpeg @common @(Source '1920x1080' 50 262) -vf $clock -c:v libx264 -preset veryfast -g 100 -keyint_min 100 -sc_threshold 0 @aac `
  -f hls -hls_time 2 -hls_playlist_type vod "$media\hls1080\index.m3u8"; Check hls1080

ffmpeg @common @(Source '1920x1080' 50 330) -vf $clock -c:v libx264 -preset veryfast -g 100 @aac `
  -f mpegts "$media\ts1080.ts"; Check ts1080

ffmpeg @common @(Source '3840x2160' 50 392) -vf $clock -c:v libx265 -preset ultrafast -g 100 -x265-params log-level=error @aac `
  -f mpegts "$media\ts2160hevc.ts"; Check ts2160hevc

Get-ChildItem $media -Recurse -File | Measure-Object Length -Sum | ForEach-Object { "media: {0} files, {1:N1} MB" -f $_.Count, ($_.Sum / 1MB) }
