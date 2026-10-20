import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../src/rust/api/update.dart' as rust;
import '../src/rust/api/update.dart' show UpdateInfo, UpdateProgress, UpdateProgress_Downloading, UpdateProgress_Failed, UpdateProgress_Ready;
import 'library.dart' show errorText;
import 'version.dart';

export '../src/rust/api/update.dart' show UpdateInfo, UpdateProgress, UpdateProgress_Downloading, UpdateProgress_Failed, UpdateProgress_Ready;

/// Where releases are announced. Release builds can point elsewhere with
/// `--dart-define=KP_UPDATE_FEED=…`; development runs with the
/// `KP_UPDATE_FEED` environment variable (e.g. the local mock).
const _builtInFeed = String.fromEnvironment(
  'KP_UPDATE_FEED',
  defaultValue: 'https://github.com/enesbsafak/karadelik-iptv-player/releases/latest/download/latest.json',
);

String get updateFeed => Platform.environment['KP_UPDATE_FEED'] ?? _builtInFeed;

enum UpdatePhase { idle, checking, upToDate, available, downloading, ready, failed }

/// Checks for, downloads and installs app updates. Installing starts the
/// silent installer and quits; the installer reopens the app.
class UpdateService extends ChangeNotifier {
  UpdateService({
    Future<UpdateInfo?> Function()? check,
    Stream<UpdateProgress> Function()? download,
    Future<void> Function(String path)? install,
    Future<(String, String)?> Function()? previous,
    Future<void> Function()? quit,
  })  : _check = check ?? (() => rust.checkUpdate(feedUrl: updateFeed, current: appVersion, language: languageCode)),
        _download = download ?? rust.downloadUpdate,
        _install = install ?? ((path) => rust.installUpdate(path: path)),
        _previous = previous ?? (() => rust.previousVersion(current: appVersion)),
        _quit = quit ?? (() async => exit(0));

  final Future<UpdateInfo?> Function() _check;
  final Stream<UpdateProgress> Function() _download;
  final Future<void> Function(String) _install;
  final Future<(String, String)?> Function() _previous;
  final Future<void> Function() _quit;

  UpdatePhase phase = UpdatePhase.idle;
  UpdateInfo? available;
  double progress = 0;
  String? error;
  String? _installer;

  /// The version before this one, if its installer was kept.
  (String, String)? previous;

  void _set(UpdatePhase p) {
    phase = p;
    notifyListeners();
  }

  Future<void> check({bool quiet = false}) async {
    if (phase == UpdatePhase.checking || phase == UpdatePhase.downloading) return;
    _set(UpdatePhase.checking);
    try {
      previous = await _previous().catchError((_) => null);
      available = await _check();
      error = null;
      _set(available == null ? UpdatePhase.upToDate : UpdatePhase.available);
    } catch (e) {
      // A background check that fails stays silent; a requested one says why.
      error = errorText(e);
      _set(quiet ? UpdatePhase.idle : UpdatePhase.failed);
    }
  }

  Future<void> download() async {
    if (available == null) return;
    progress = 0;
    _set(UpdatePhase.downloading);
    await for (final e in _download()) {
      switch (e) {
        case UpdateProgress_Downloading(:final fraction):
          progress = fraction;
          notifyListeners();
        case UpdateProgress_Ready(:final path):
          _installer = path;
          _set(UpdatePhase.ready);
        case UpdateProgress_Failed(:final message):
          error = message;
          _set(UpdatePhase.failed);
      }
    }
  }

  /// Runs the verified installer and quits so it can replace the files.
  Future<void> installAndRestart() async {
    final path = _installer;
    if (path == null) return;
    await _install(path);
    await _quit();
  }

  /// Reinstalls the kept previous version.
  Future<void> rollBack() async {
    final p = previous;
    if (p == null) return;
    await _install(p.$2);
    await _quit();
  }

  /// Once per start, a little after launch, without bothering anyone on
  /// failure. Automated (offscreen) runs never call this.
  void startBackgroundCheck() {
    Timer(const Duration(seconds: 8), () => check(quiet: true));
  }
}
