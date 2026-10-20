import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_state.dart';
import 'app/library.dart';
import 'app/licenses.dart';
import 'app/paging.dart';
import 'app/scope.dart';
import 'app/shutdown.dart';
import 'app/updates.dart';
import 'design/theme.dart';
import 'dev/automation.dart';
import 'l10n/l10n.dart';
import 'perf/perf.dart';
import 'player/media_session.dart';
import 'player/player_controller.dart';
import 'player/player_engine.dart';
import 'shell/app_shell.dart';
import 'src/rust/api/library.dart' as rust;
import 'src/rust/frb_generated.dart';

String? _arg(List<String> args, String name) {
  for (final a in args) {
    if (a.startsWith('--$name=')) return a.substring(name.length + 3);
  }
  return null;
}

Future<void> main(List<String> args) async {
  final perf = Perf.init(args)..mark('dart_main');
  // Until the stored choice is read: the system language (startup errors).
  setLanguage(AppState.systemLocale().toLowerCase().startsWith('tr') ? 'tr' : 'en');
  WidgetsFlutterBinding.ensureInitialized();
  registerLicenses();
  await initializeDateFormatting();
  MediaKit.ensureInitialized();
  final offscreen = args.contains('--kp-offscreen');

  // Frameless before the first frame: the runner shows the window only once
  // Flutter has painted, so the native caption never flashes. These calls
  // only restyle the still-hidden window, so --kp-offscreen runs get the real
  // frame too (tools/check-snap.ps1 depends on it) without taking focus.
  await windowManager.ensureInitialized();
  await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
  await windowManager.setMinimumSize(const Size(1100, 680));
  await windowManager.setTitle('Karadelik IPTV Player');
  perf.mark('window_configured');

  // Mpv warms up in the background while the library opens.
  final engine = MediaKitEngine.warmUp(silent: offscreen);
  final warmUp = Stopwatch()..start();
  unawaited(engine.ready.then((_) => perf.record('player_warm_up', warmUp.elapsedMilliseconds)));

  final dataDir = _arg(args, 'kp-data-dir') ?? (await getApplicationSupportDirectory()).path;
  final library = RustLibrary();
  final state = AppState(library);
  try {
    await RustLib.init();
    await rust.openLibrary(dataDir: dataDir, ephemeralSecrets: offscreen);
    perf.mark('library_open');
    await state.load();
    perf.mark('library_loaded');
  } catch (e) {
    // Never leave a hidden window behind: the runner shows it on the first
    // frame, so a failed start must still paint something.
    perf.record('startup_failed', 0, {'error': '$e'});
    runApp(_StartupError(message: '$e', dataDir: dataDir));
    return;
  }
  final player = PlayerController(engine, library, perf);
  final epg = EpgCache(library);
  final shutdown = Shutdown(player);
  await shutdown.install();
  final updates = UpdateService(quit: shutdown.run);
  if (!offscreen) updates.startBackgroundCheck();
  MediaSession(player);
  var guideVersion = state.guideVersion;
  state.addListener(() {
    if (state.guideVersion != guideVersion) {
      guideVersion = state.guideVersion;
      epg.clear();
    }
  });

  final boundary = GlobalKey();
  runApp(
    AppScope(
      state: state,
      player: player,
      library: library,
      epg: epg,
      updates: updates,
      child: KaradelikPlayerApp(boundaryKey: boundary, perf: perf, state: state),
    ),
  );

  final automation = Automation(args, boundary);
  if (automation.active) {
    WidgetsBinding.instance.addPostFrameCallback((_) => automation.run(state, player, quit: shutdown.run));
  }
}

class KaradelikPlayerApp extends StatefulWidget {
  const KaradelikPlayerApp({super.key, required this.boundaryKey, required this.perf, required this.state});

  final GlobalKey boundaryKey;
  final Perf perf;
  final AppState state;

  @override
  State<KaradelikPlayerApp> createState() => _KaradelikPlayerAppState();
}

class _KaradelikPlayerAppState extends State<KaradelikPlayerApp> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final cold = widget.perf.sinceProcessStart();
      if (cold != null) widget.perf.record('cold_start_first_frame', cold, {'pid': pid});
    });
  }

  @override
  Widget build(BuildContext context) {
    // A new language rebuilds everything: strings are read from l10n while
    // building, so no screen keeps the old one.
    return ValueListenableBuilder<String>(
      valueListenable: widget.state.language,
      builder: (context, language, _) => MaterialApp(
        key: ValueKey(language),
        title: 'Karadelik IPTV Player',
        debugShowCheckedModeBanner: false,
        theme: buildKdTheme(),
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: RepaintBoundary(
          key: widget.boundaryKey,
          child: const Scaffold(body: AppShell()),
        ),
      ),
    );
  }
}

/// Shown when the library cannot be opened, instead of an invisible window.
class _StartupError extends StatelessWidget {
  const _StartupError({required this.message, required this.dataDir});

  final String message;
  final String dataDir;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Karadelik IPTV Player',
      debugShowCheckedModeBanner: false,
      theme: buildKdTheme(),
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.startupFailed, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                SelectableText(message, style: const TextStyle(color: Color(0xFFFF5D5D))),
                const SizedBox(height: 14),
                SelectableText(l10n.startupDataDir(dataDir), style: const TextStyle(color: Color(0xFF8D8A9C))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
