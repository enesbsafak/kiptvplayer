# Android and iOS

The Flutter app in `apps/player` builds for Android and iOS from the same code
as Windows; the Android build is also the Android TV / Google TV app. Every
push builds them in CI (`.github/workflows/ci.yml`): Android APKs that are
started on a phone emulator and on an Android TV emulator (driven with remote
keys), an unsigned iOS device build and a simulator build that is started on
an iPhone simulator. The screenshots and logs are kept as the
`android-smoke`, `android-tv-smoke` and `ios-smoke` artifacts.

## What is different on a phone

| | Windows | Android / iOS |
|---|---|---|
| Layout | Sidebar, three panes | Below 1000 px wide (phones, tablets held upright): top bar, bottom navigation, one pane, categories in a sheet; a tap on a channel plays it full screen. Android: its own look, below |
| Full screen | The window, on request | System bars hidden and landscape while the player is open |
| Saved passwords | Windows Credential Manager | iOS: Keychain. Android: a file in the app's private folder sealed with XChaCha20-Poly1305 under a key kept by the Android Keystore (`MainActivity.kt`, `core/crates/kp-core/src/secret.rs`) |
| TLS | Windows (schannel) | iOS: Security.framework. Android: rustls with the Mozilla root store (`core/crates/kp-core/src/net.rs`) |
| libmpv | `packages/karadelik_mpv_libs` (pinned LGPL build) | media_kit's LGPL "default" builds (`media_kit_libs_android_video`, `media_kit_libs_ios_video`) at the pinned media_kit commit |
| Updates | Built-in updater (`latest.json`) | The stores |

To see the phone layout without a phone: `tools\shots.ps1 -Phone 390x844`
captures every screen at that size, off-screen, with the mock provider.
`tools\shots.ps1 -Phone 390x844 -Android` captures the Android look below,
and `tools\shots.ps1 -Tv -Scale 2` the TV layout at 1920x1080.

## The Android look

One codebase, a layout of its own: Android phones (not TVs) get
`lib/mobile`, set at startup (`androidUi` in `lib/app/platform.dart`;
`--kp-android` previews it on a desktop). The look is KaradelikDev's black and
orange with frosted glass for everything that floats; the behaviour is
Android's own.

- **Glass** (`mobile/glass.dart`): what lies behind is blurred and a little
  more saturated, under a dark tint and a rim lit from above. Bars, sheets,
  the mini player, the player's controls. Low-RAM phones get the same
  surfaces tinted instead of blurred. Behind it all, the icon's space: black
  with a violet core and a faint orange glow.
- **Shell** (`mobile/mobile_shell.dart`): a glass top bar (the source, tap to
  switch; guide, search, settings), a floating glass bar for the sections
  with a lit pill that slides to the current one, the playing stream in a
  glass bar above it (tap or swipe up to open). Sections fade through; the
  player rises from below; the bars step aside for the keyboard.
- **Opening** (`mobile/intro.dart`): Android's launch screen shows the mark
  (`res/values-v31`, `tools/make-icons.py`); the first frame draws the same
  mark and the event horizon opens into the app in under a second. Touches
  work from the first frame; off when animations are.
- **Android behaviour**: the predictive back shrinks the screen with the
  finger (`enableOnBackInvokedCallback`); back closes an open detail before
  the section; ripples on everything tappable; haptics on navigation, chips
  and long presses; a long press opens the actions in a bottom sheet; the
  stretch overscroll; Android's switch; 28 dp dialogs.
- **Controls** (`mobile/controls.dart`): the shared Kd widgets hand over to
  Android forms: pill buttons (the CTA keeps the orange gradient), 48 dp
  icon buttons, filter chips, 52 dp filled text fields. Text is 15 % larger
  than on desktop, on top of the user's own font size.
- **Player**: the controls in one glass capsule; a double tap on the left or
  right half seeks 10 s; audio, subtitles and the adjustments in a glass
  sheet on the right with finger-sized rows.

`test/android_test.dart` lays out every section at phone sizes with
Android's text size and drives the bars, the predictive back, the sheets,
the mini player, the player's gestures and the opening.

## Android TV and Google TV

One APK and one Play listing serve phones and TVs. The manifest declares
`android.software.leanback` and the touchscreen as not required, puts the app
on the TV launcher (`LEANBACK_LAUNCHER`) and gives it the 320x180 banner
(`res/drawable-xhdpi/tv_banner.png`, from `tools/make-icons.py`).

On a TV (`MainActivity` reports `UI_MODE_TYPE_TELEVISION` or the leanback
feature over the `karadelik/device` channel; `--kp-tv` on a desktop):

- The app is drawn 1.2x larger and kept clear of the screen edges
  (`lib/shell/tv.dart`), with the sidebar on the left and the one-pane
  screens beside it.
- Everything clickable is focusable (`KdTappable`, `lib/design/widgets/kd_focus.dart`)
  and shows an orange ring when the remote is on it. The open section starts
  with the focus.
- Text fields take the remote's focus without typing; OK opens the on-screen
  keyboard, up and down leave the field.
- In the player: up and down (and channel up / down) zap, left and right seek
  where possible, OK brings up the controls on the play button, the menu or
  info key opens audio and subtitles, back hides the controls and then leaves.

`test/tv_test.dart` drives all of this with key events at 960x540 dp.

For Google Play: Release > Advanced settings > Form factors > Android TV
(opt in), then TV screenshots (1920x1080) and the banner in the store
listing; Google reviews TV apps separately against its TV app quality
guidelines.

## Identity

- Android `applicationId` and iOS bundle identifier: `dev.karadelik.player`.
  Both are permanent once the app is in a store; change them before the
  first upload if a different domain is wanted.
- Display name: "Karadelik". Icons: `python tools/make-icons.py` regenerates
  them from the vector icon in `design/brand` (`tools/icon/app-icon.js`).

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
