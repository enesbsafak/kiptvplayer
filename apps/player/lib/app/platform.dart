import 'dart:io' show File, Platform;

import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

/// Windows, macOS, Linux: a frameless window we draw ourselves, the
/// installer-based updater, the taskbar. Layout never depends on this; it
/// follows the screen width ([isCompact] in design/layout.dart).
final bool isDesktopOs = Platform.isWindows || Platform.isMacOS || Platform.isLinux;

/// Android and iOS: system bars, rotation, the store updates the app.
final bool isMobileOs = Platform.isAndroid || Platform.isIOS;

/// Android TV and Google TV: driven with a remote, seen from the sofa. Set
/// once at startup ([detectTv], or `--kp-tv` to preview the layout on a
/// desktop); the shell then lays the app out for a TV (shell/tv.dart).
bool isTv = false;

Future<bool> detectTv() => _device('isTv');

/// Android phones and tablets (not TVs): Android's own behaviour (ripples,
/// the predictive back, bottom sheets, haptics, the stretch overscroll) in
/// the Karadelik glass look, laid out by lib/mobile. Set once at startup;
/// `--kp-android` previews it on a desktop.
bool androidUi = false;

/// Frosted glass blurs what lies behind the bars and sheets. Low-RAM phones
/// get the same surfaces tinted instead: a blur costs every frame that
/// scrolls under it.
bool glassBlur = true;

Future<bool> detectLowRam() => _device('isLowRam');

Future<bool> _device(String method) async {
  if (!Platform.isAndroid) return false;
  try {
    return await const MethodChannel('karadelik/device').invokeMethod<bool>(method) ?? false;
  } on PlatformException {
    return false;
  } on MissingPluginException {
    return false;
  }
}

/// The installer-based updater exists for Windows only; app stores update
/// the phone apps. Tests switch it on wherever they run.
bool hasAppUpdater = Platform.isWindows;

/// Full screen for the player: the window on desktop; on phones the system
/// bars hide and the video turns to landscape.
Future<void> setPlayerFullscreen(bool on) async {
  if (isDesktopOs) {
    await windowManager.setFullScreen(on).catchError((_) {});
    return;
  }
  if (on) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  } else {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await SystemChrome.setPreferredOrientations(const []);
  }
}

Future<bool> isPlayerFullscreen() async => isDesktopOs ? windowManager.isFullScreen() : false;

/// The 32-byte key that seals saved passwords on Android, created on first
/// use and kept by the Android Keystore (android/.../MainActivity.kt). Null
/// elsewhere: those platforms have an OS credential store. A fresh key means
/// the old one is gone, so a sealed file under [dataDir] can never open
/// again: it goes, and the user types the passwords once more.
Future<Uint8List?> secretsKey(String dataDir) async {
  if (!Platform.isAndroid) return null;
  final answer = await const MethodChannel('karadelik/keystore').invokeMapMethod<String, Object?>('secretsKey');
  final key = answer?['key'];
  if (key is! Uint8List || key.length != 32) throw StateError('the Android Keystore returned no key');
  if (answer?['fresh'] == true) {
    final stale = File('$dataDir${Platform.pathSeparator}secrets.bin');
    if (stale.existsSync()) stale.deleteSync();
  }
  return key;
}
