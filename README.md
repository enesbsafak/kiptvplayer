# Karadelik IPTV Player

A fast, native-feeling IPTV player built with Flutter, a Rust data core and libmpv.
It brings no content: you add your own authorized source (Xtream Codes, M3U playlist or Stalker portal).

[Download](https://github.com/enesbsafak/kiptvplayer/releases/latest) · [License: MPL-2.0](LICENSE) · English and Turkish UI

| Platform | Status |
|---|---|
| Windows 10/11 (x64) | Available: installer with built-in updates |
| Android, iOS | In preparation: built and started on an emulator / simulator in CI, not yet in the stores ([docs/mobile.md](docs/mobile.md)) |
| macOS | Planned |

## Features

- **Fast:** the catalog lives in a local SQLite database, so the app opens on cached data in about half a second; channel switching takes under 100 ms on a local stream, and the player is warmed up before the first click.
- **Live TV:** categories, channel list and preview side by side; zapping with the arrow keys or channel numbers; automatic failover and reconnect; local timeshift (pause and rewind live TV from a disk buffer).
- **TV guide:** streaming XMLTV import (a 250 MB guide in 3.4 s using 53 MB of memory), matching by `tvg-id` or name with manual fixes, per-channel time shift, catch-up (Xtream and M3U templates), programme reminders.
- **Movies and series:** resume where you left off, accent-insensitive search (Turkish-aware), optional TMDB artwork and details with your own API key, OpenSubtitles search with your own key.
- **Your list, your way:** hide or rename channels, reorder categories, custom groups, favorites, parental PIN.
- **Private by design:** passwords, MAC addresses and API keys are kept in the OS credential store, never in the database; encrypted backups (Argon2id + XChaCha20-Poly1305); no telemetry, no accounts, nothing sent to our servers.
- **Player:** audio and subtitle tracks with readable names, subtitle delay and size, aspect ratio, speed, sleep timer, a "why is it buffering" stats panel, media keys.
- **Desktop:** frameless window with Windows Snap Layouts, single instance, `Ctrl+K` command palette.

## Repository layout

| Path | Contents |
|---|---|
| `apps/player` | The Flutter app for Windows, Android and iOS (UI, player, translations in `lib/l10n`) |
| `core/crates/kp-core` | Rust data core: Xtream / M3U / Stalker clients, SQLite + FTS5, XMLTV, catch-up, TMDB, updater, credential store |
| `core/crates/kp-bridge` | flutter_rust_bridge surface (`apps/player/lib/src/rust` is generated from it) |
| `packages/karadelik_mpv_libs` | LGPL libmpv + ANGLE for Windows, pinned by SHA-256 (replaces media_kit_libs_video) |
| `packages/media_kit_video` | media_kit_video with stability patches (`KARADELIK_PATCHES.md`) |
| `tools/mock-iptv` | Local test provider: Xtream, M3U + XMLTV, Stalker portal, TMDB and OpenSubtitles stand-ins, test streams |
| `tools/installer` | Inno Setup script (per-user install) |
| `design/ui-spec.md` | Design decisions and their sources |
| `THIRD_PARTY.md` | Third-party components and license obligations |

## Building

Requirements: Flutter 3.47, a stable Rust toolchain, and for Windows Visual Studio 2022+ with the C++ workload.

```powershell
# Once: test streams and artwork for the mock provider (-Audio adds sound)
tools\mock-iptv\make-media.ps1; tools\mock-iptv\make-art.ps1

# Data core tests
cargo test --workspace
cargo run -p mock-iptv --release -- 8089          # in another terminal
cargo test -p kp-core --test xtream_mock -- --ignored --test-threads=1

# Bridge code (after a Rust API change) and translations
cd apps\player; flutter_rust_bridge_codegen generate; flutter gen-l10n

# The app
cd apps\player; flutter test; flutter build windows --release
tools\demo.ps1                    # a normal window with a demo source
tools\shots.ps1 [-Language en]    # off-screen and silent: a PNG of every screen
```

Automated runs (`--kp-offscreen`) open the window off-screen, never take focus, open no audio device,
stay out of the system media controls and keep passwords in memory instead of the OS credential store.

## Releases

```powershell
# tools\release-notes\<version>.en.txt / .tr.txt: notes shown in the update dialog
tools\release.ps1 -Version 0.2.0      # dist\: installer + latest.json
```

- Pushing a `v0.2.0` tag makes GitHub Actions (`.github/workflows/release.yml`) do the same and publish a GitHub release.
- The in-app updater reads `releases/latest/download/latest.json`, downloads the installer, checks its SHA-256, installs silently and reopens the app. The previous installer is kept, so rolling back is possible.
- The `native-deps` pre-release only holds build dependencies (libmpv, ANGLE and their LGPL sources); it never counts as the latest release. When upstream prunes a pinned archive, the build downloads it from there.
- **Signing:** when `KP_SIGN_CMD` (environment variable or repository secret, e.g. Azure Trusted Signing) is set, the executable and installer are signed; otherwise they are unsigned and SmartScreen warns on first run. Releases are currently unsigned.

## Known issues

- **Memory while zapping:** there is no leak. Memory moves by about ±200 MB with the channel playing (a 4K stream holds more decoder and cache buffers than 720p), so single samples mislead; `tools/soak.ps1` compares the floor of each fifth of the run. Over 20 minutes with a channel change every 5 s (~240 changes) the floor stayed flat at 630–670 MB after warm-up. To narrow things down: `-Channels 2` (few channels), `-Mpv "hwdec=no;vid=no"` (mpv options).
- **Timeshift writes to disk:** while a live channel plays, the stream is buffered up to the chosen size (2 GB by default) under `timeshift` in the data folder; it is deleted on channel change and on exit. It can be turned off in Preferences.
- **The parental PIN guards the screen, not the file:** the PIN is salted and hashed and five wrong tries lock it for 30 s, but a 4–6 digit code does not protect against someone with access to the library file.

## License, contributing, security

- **License:** [Mozilla Public License 2.0](LICENSE). Files you change stay open under the MPL; you may combine them with other code and distribute the result. Third-party components: [THIRD_PARTY.md](THIRD_PARTY.md).
- **Name and logo:** the "Karadelik" name and the logo under `apps/player/assets/brand` are not licensed (MPL-2.0 §2.3). Forks must ship under their own name and logo.
- **Content:** the app contains and sells no streams, playlists or subscriptions. Add only sources you are entitled to use.
- **Contributing:** [CONTRIBUTING.md](CONTRIBUTING.md). **Vulnerabilities:** report privately, see [SECURITY.md](SECURITY.md).
