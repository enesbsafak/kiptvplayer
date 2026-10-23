import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app/app_state.dart';
import 'app/library.dart';
import 'app/licenses.dart';
import 'app/paging.dart';
import 'app/platform.dart';
import 'app/scope.dart';
import 'app/shutdown.dart';
import 'app/updates.dart';
import 'design/theme.dart';
import 'design/tokens.dart';
import 'design/widgets/kd_titlebar.dart' show flashTaskbar;
import 'dev/automation.dart';
import 'l10n/l10n.dart';
import 'mobile/intro.dart';
import 'perf/perf.dart';
import 'player/media_session.dart';
import 'player/player_controller.dart';
import 'player/player_engine.dart';
import 'shell/app_shell.dart';
import 'shell/tv.dart';
import 'shell/command_palette.dart' show rootNavigator;
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

  if (isDesktopOs) {
    // Frameless before the first frame: the runner shows the window only once
    // Flutter has painted, so the native caption never flashes. These calls
    // only restyle the still-hidden window, so --kp-offscreen runs get the real
    // frame too (tools/check-snap.ps1 depends on it) without taking focus.
    await windowManager.ensureInitialized();
    await windowManager.setTitleBarStyle(TitleBarStyle.hidden, windowButtonVisibility: false);
    await windowManager.setMinimumSize(const Size(1100, 680));
    await windowManager.setTitle('Karadelik IPTV Player');
    perf.mark('window_configured');
  } else {
    // Dark system bars over the dark app, drawn edge to edge.
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Color(0x00000000),
      systemNavigationBarColor: Color(0x00000000),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ));
  }

  // Mpv warms up in the background while the library opens.
  final engine = MediaKitEngine.warmUp(silent: offscreen);
  final warmUp = Stopwatch()..start();
  unawaited(engine.ready.then((_) => perf.record('player_warm_up', warmUp.elapsedMilliseconds)));

  final dataDir = _arg(args, 'kp-data-dir') ?? (await getApplicationSupportDirectory()).path;
  isTv = args.contains('--kp-tv') || await detectTv();
  androidUi = !isTv && (Platform.isAndroid || args.contains('--kp-android'));
  glassBlur = !await detectLowRam();
  final library = RustLibrary();
  final state = AppState(library);
  state.reminders.onDue = (_) => flashTaskbar();
  try {
    await RustLib.init();
    await rust.openLibrary(dataDir: dataDir, ephemeralSecrets: offscreen, secretsKey: offscreen ? null : await secretsKey(dataDir));
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
  // Timeshift files are deleted when mpv closes them; a crash can leave
  // some behind, so the folder starts empty.
  final timeshiftDir = Directory('$dataDir${Platform.pathSeparator}timeshift');
  try {
    if (timeshiftDir.existsSync()) timeshiftDir.deleteSync(recursive: true);
    timeshiftDir.createSync(recursive: true);
  } on FileSystemException catch (_) {}
  player.configureTimeshift(
    int.tryParse(await library.appSetting('timeshift_mb') ?? '') ?? PlayerController.defaultTimeshiftMb,
    dir: timeshiftDir.path,
  );
  final epg = EpgCache(library);
  final shutdown = Shutdown(player);
  if (isDesktopOs) await shutdown.install();
  final updates = UpdateService(quit: shutdown.run);
  if (!offscreen && hasAppUpdater) updates.startBackgroundCheck();
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
      child: KaradelikPlayerApp(boundaryKey: boundary, perf: perf, state: state, phone: _phoneSize(args)),
    ),
  );

  final automation = Automation(args, boundary);
  if (automation.active) {
    WidgetsBinding.instance.addPostFrameCallback((_) => automation.run(state, player, quit: shutdown.run));
  }
}

/// `--kp-phone=390x844` (development, with `--kp-offscreen`): lays the app
/// out at a phone's size inside the desktop window, so tools/shots.ps1 -Phone
/// captures the compact layout with real fonts and data.
Size? _phoneSize(List<String> args) {
  // --kp-tv alone: a 1080p TV's 960x540 dp.
  final v = _arg(args, 'kp-phone') ?? (args.contains('--kp-tv') ? '960x540' : null);
  if (v == null || !args.contains('--kp-offscreen')) return null;
  final parts = v.split('x').map(double.tryParse).toList();
  if (parts.length != 2 || parts.contains(null)) return null;
  return Size(parts[0]!, parts[1]!);
}

class KaradelikPlayerApp extends StatefulWidget {
  const KaradelikPlayerApp({super.key, required this.boundaryKey, required this.perf, required this.state, this.phone});

  final GlobalKey boundaryKey;
  final Perf perf;
  final AppState state;
  final Size? phone;

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
        navigatorKey: rootNavigator,
        title: 'Karadelik IPTV Player',
        debugShowCheckedModeBanner: false,
        theme: buildKdTheme(android: androidUi),
        locale: Locale(language),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        // Around the navigator, so captures include dialogs and menus.
        builder: (context, child) {
          final app = isTv
              ? TvFrame(child: child!)
              : androidUi
                  ? _AndroidText(child: KdIntro(child: child!))
                  : child;
          final phone = widget.phone;
          if (phone == null) return RepaintBoundary(key: widget.boundaryKey, child: app);
          // A status bar and a home indicator, as on a real phone.
          final insets = isTv ? EdgeInsets.zero : const EdgeInsets.only(top: 24, bottom: 16);
          return OverflowBox(
            alignment: Alignment.topLeft,
            minWidth: phone.width,
            maxWidth: phone.width,
            minHeight: phone.height,
            maxHeight: phone.height,
            child: RepaintBoundary(
              key: widget.boundaryKey,
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(size: phone, padding: insets, viewPadding: insets),
                child: ColoredBox(color: KdColors.bg, child: app),
              ),
            ),
          );
        },
        home: const Scaffold(body: AppShell()),
      ),
    );
  }
}

/// Android: the desktop type scale (13 px body) read at arm's length is
/// small; every size grows by the same step so the hierarchy holds (body
/// 15, captions 12.6), on top of the user's own font size setting.
class _AndroidText extends StatelessWidget {
  const _AndroidText({required this.child});

  final Widget child;

  static const step = 1.15;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final user = mq.textScaler.scale(100) / 100;
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(user * step)),
      child: child,
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
