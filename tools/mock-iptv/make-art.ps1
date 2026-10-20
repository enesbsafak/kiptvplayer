# Generates placeholder artwork for the mock provider into tools/mock-iptv/media:
# 12 channel logos, 24 posters (2:3) and 4 backdrops (16:9). Plainly labelled
# test art: flat colour and a caption, never imitating real brands or films.
$ErrorActionPreference = 'Continue'
$media = Join-Path $PSScriptRoot 'media'
New-Item -ItemType Directory -Force -Path "$media\logos", "$media\posters", "$media\backdrops" | Out-Null

$font = "fontfile='C\:/Windows/Fonts/segoeuib.ttf'"
$colors = @('2b3a55', '3d2b55', '553a2b', '2b5546', '55502b', '552b3a', '2b4a55', '4a552b', '3a2b55', '552b2b', '2b5530', '35353f')
$common = @('-y', '-hide_banner', '-loglevel', 'error')

for ($i = 0; $i -lt 12; $i++) {
  $c = $colors[$i]
  ffmpeg @common -f lavfi -i "color=c=0x${c}:s=128x128" -frames:v 1 `
    -vf "drawtext=${font}:text='K$($i + 1)':fontsize=44:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2" "$media\logos\$i.png"
  if ($LASTEXITCODE -ne 0) { throw "logo $i" }
}

for ($i = 0; $i -lt 24; $i++) {
  $c = $colors[$i % 12]
  ffmpeg @common -f lavfi -i "color=c=0x${c}:s=300x450" -frames:v 1 `
    -vf "drawtext=${font}:text='Poster $($i + 1)':fontsize=34:fontcolor=white@0.9:x=(w-text_w)/2:y=h*0.72,drawtext=${font}:text='TEST':fontsize=18:fontcolor=white@0.5:x=(w-text_w)/2:y=h*0.72+48" `
    -q:v 4 "$media\posters\$i.jpg"
  if ($LASTEXITCODE -ne 0) { throw "poster $i" }
}

for ($i = 0; $i -lt 4; $i++) {
  ffmpeg @common -f lavfi -i "gradients=s=1280x720:c0=0x$($colors[$i]):c1=0x0b0b10:x0=0:y0=0:x1=1280:y1=720" -frames:v 1 `
    -q:v 4 "$media\backdrops\$i.jpg"
  if ($LASTEXITCODE -ne 0) { throw "backdrop $i" }
}

"art: 12 logos, 24 posters, 4 backdrops"
