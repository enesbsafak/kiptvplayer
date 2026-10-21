import 'dart:async';

import 'package:window_manager/window_manager.dart';

import '../player/player_controller.dart';

/// The one way out of the app. Destroying the window while mpv still owns a
/// video texture crashes inside the Flutter engine (access violation on
/// exit), so every exit (close button, Alt+F4, the updater, automated runs)
/// stops playback and releases the player first.
class Shutdown with WindowListener {
  Shutdown(this.player);

  final PlayerController player;
  bool _running = false;

  Future<void> install() async {
    windowManager.addListener(this);
    await windowManager.setPreventClose(true);
  }

  @override
  void onWindowClose() => run();

  Future<void> run() async {
    if (_running) return;
    _running = true;
    try {
      await player.stop().timeout(const Duration(seconds: 2));
      await player.engine.dispose().timeout(const Duration(seconds: 3));
    } catch (_) {
      // A stuck player must not keep the app open: close regardless.
    }
    // A normal close (WM_CLOSE -> DestroyWindow) shuts the engine down
    // in order; destroy() only posts a quit message.
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }
}
