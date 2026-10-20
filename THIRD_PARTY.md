# Third-party software

Karadelik IPTV Player ships with the components below. The in-app page
(Ayarlar › Hakkında › Açık kaynak lisansları) lists them too, together with
every Flutter package and Rust crate.

## Native playback (Windows)

| Component | Files | License | Source |
|---|---|---|---|
| mpv, LGPL configuration (`-Dgpl=false`) | `libmpv-2.dll` | LGPL-2.1-or-later | https://github.com/mpv-player/mpv @ `e471496c56`; build scripts https://github.com/zhongfly/mpv-winbuild |
| FFmpeg (no `--enable-gpl`, no `--enable-nonfree`), inside `libmpv-2.dll` | | LGPL-2.1-or-later | https://git.ffmpeg.org/ffmpeg.git |
| ANGLE | `libEGL.dll`, `libGLESv2.dll` | BSD-3-Clause | https://chromium.googlesource.com/angle/angle |

The exact archives, with SHA-256 checksums, are pinned in
`packages/karadelik_mpv_libs/manifest.json`; the build refuses any other file.

### LGPL obligations

- libmpv is linked dynamically: users can replace `libmpv-2.dll` in the
  install folder with their own compatible build.
- The corresponding source is named above and in the app. Before a public
  release the pinned archive is mirrored to this project's own GitHub
  release (upstream keeps builds for 30 days), with the build recipe.
- The app makes no attempt to prevent replacing or reverse-engineering
  these libraries for debugging such modifications.

## Rust crates

`tools/gen-licenses.py` lists every crate linked into the core in
`apps/desktop/assets/licenses/rust.json`. All are permissive (MIT,
Apache-2.0, BSD, Zlib, Unicode-3.0, Unlicense); SQLite is public domain.

## Data sources

Film and series information optionally comes from TMDB with the user's own
API key. This product uses the TMDB API but is not endorsed or certified by
TMDB.
