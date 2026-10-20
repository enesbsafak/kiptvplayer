# Karadelik patches to media_kit_video

Vendored from https://github.com/media-kit/media-kit at
`c533e446755f51cf53c7e57aea873f2aa5355f81` (MIT, see LICENSE). Changes are
marked `[karadelik]` in the source.

Found by `tools/soak.ps1`: zapping between 1080p and 4K streams crashed the
app with 0xC0000409 (fail-fast) inside flutter_windows.dll after a few
minutes, and private memory grew by about one 4K texture per resolution
change.

1. `lib/src/video_controller/native_video_controller/real.dart`: a fixed
   output size (`VideoControllerConfiguration.width/height` or `setSize`)
   is no longer overridden with the stream's size on every `videoParams`
   change. The app sets the screen size, so the texture is created once.
2. `windows/video_output.cc`, texture callbacks: `find` instead of `at()`.
   An exception thrown on the raster thread terminates the process.
3. `windows/video_output.cc`, `Resize`: the new texture id is published only
   after its texture is in the map, under the lock the callbacks take; the
   old id is cleared under that lock before its surface is destroyed.
   Before, the callback could see the new id with no texture behind it.

Upstream these when the project has a public repository.
