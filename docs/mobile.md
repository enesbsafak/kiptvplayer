# Android and iOS

The Flutter app in `apps/player` builds for Android and iOS from the same code
as Windows. Every push builds both in CI (`.github/workflows/ci.yml`): Android
APKs that are started on an emulator, an unsigned iOS device build and a
simulator build that is started on an iPhone simulator. The screenshots and
logs are kept as the `android-smoke` and `ios-smoke` artifacts.

## What is different on a phone

| | Windows | Android / iOS |
|---|---|---|
| Layout | Sidebar, three panes | Below 1000 px wide (phones, tablets held upright): top bar, bottom navigation, one pane, categories in a sheet; a tap on a channel plays it full screen |
| Full screen | The window, on request | System bars hidden and landscape while the player is open |
| Saved passwords | Windows Credential Manager | iOS: Keychain. Android: a file in the app's private folder sealed with XChaCha20-Poly1305 under a key kept by the Android Keystore (`MainActivity.kt`, `core/crates/kp-core/src/secret.rs`) |
| TLS | Windows (schannel) | iOS: Security.framework. Android: rustls with the Mozilla root store (`core/crates/kp-core/src/net.rs`) |
| libmpv | `packages/karadelik_mpv_libs` (pinned LGPL build) | media_kit's LGPL "default" builds (`media_kit_libs_android_video`, `media_kit_libs_ios_video`) at the pinned media_kit commit |
| Updates | Built-in updater (`latest.json`) | The stores |

To see the phone layout without a phone: `tools\shots.ps1 -Phone 390x844`
captures every screen at that size, off-screen, with the mock provider.

## Identity

- Android `applicationId` and iOS bundle identifier: `dev.karadelik.player`.
  Both are permanent once the app is in a store; change them before the
  first upload if a different domain is wanted.
- Display name: "Karadelik". Icons: `python tools/make-icons.py` regenerates
  them from `design/brand/app-icon-512.png`.

## Before publishing to Google Play

Listing texts, graphics, form answers and reviewer notes: [play-store.md](play-store.md).
Privacy policy: [privacy.md](privacy.md).

1. Create an upload key (keep it and its passwords outside the repository):
   `keytool -genkey -v -keystore upload.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload`
2. Local builds: `apps/player/android/key.properties` (ignored by git) with
   `storeFile`, `storePassword`, `keyAlias`, `keyPassword`. CI: the
   `KP_ANDROID_KEYSTORE` (path), `KP_ANDROID_STORE_PASSWORD`,
   `KP_ANDROID_KEY_ALIAS` and `KP_ANDROID_KEY_PASSWORD` environment variables.
   Without them release builds are signed with the debug key, which Play
   refuses.
3. Build the bundle: `flutter build appbundle --release`.
4. Play Console: Play App Signing, a privacy policy URL, the Data safety form
   (no data collected or shared; credentials stay on the device), content
   rating, and the store listing (see "Store listings" below).
5. Android TV (later): the UI needs D-pad focus handling and a leanback
   banner before the manifest may declare `android.software.leanback`.

## Before publishing to the App Store

1. An Apple Developer account; set the team in Xcode
   (`apps/player/ios/Runner.xcworkspace`, Signing & Capabilities).
2. `flutter build ipa --release`, then upload with Transporter or Xcode.
3. Export compliance: the app uses only standard encryption (HTTPS, the
   encrypted backup file), which is exempt; add
   `ITSAppUsesNonExemptEncryption` = `NO` to `Info.plist` once confirmed.
4. App Review notes: `NSAllowsArbitraryLoads` is on because most IPTV
   providers serve plain http and the user chooses the provider; the app
   ships no content, so a demo account is needed for review (a test playlist
   the reviewer may use).
5. LGPL: libmpv and FFmpeg are dynamically linked frameworks inside the app;
   keep the third-party notices (Settings › About › Open-source licenses).

## Store listings

The stores have removed many "IPTV" apps. The listing must make clear that the
app is a player only:

- No channel names, logos, sports or film titles in screenshots: use the mock
  provider's test streams and posters (`tools/shots.ps1`).
- No words such as "free TV", "channels included", "watch sports".
- State that the app provides no content and that users must add sources they
  are entitled to use.
- No links to playlist sellers, no MAC activation or reseller scheme, no VPN.
