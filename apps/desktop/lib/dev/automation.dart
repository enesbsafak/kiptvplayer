import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../app/app_state.dart';
import '../app/library.dart';
import '../player/media_track.dart';
import '../player/player_controller.dart';
import '../shell/command_palette.dart';

/// Development driver:
/// - `--kp-add-mock=<url>` adds the local mock provider when no source exists
/// - `--kp-shot=<dir>` (with `--kp-offscreen` only) visits each section,
///   saves `<section>.png`, then exits
/// - `--kp-tmdb-key=<key>` (with `--kp-shot`) turns TMDB on for the run
/// - `--kp-language=tr|en` (with `--kp-shot`) captures in that language
/// - `--kp-soak=<minutes>` (with `--kp-offscreen` only) plays live TV, zapping
///   every minute (`--kp-soak-every=<seconds>`), then exits: a leak check
///   (tools/soak.ps1)
///
/// Screenshots come from Flutter's own layer tree, so nothing is captured
/// from (or shown on) the user's desktop.
class Automation {
  Automation(this.args, this.boundaryKey);

  final List<String> args;
  final GlobalKey boundaryKey;

  String? _arg(String name) {
    for (final a in args) {
      if (a.startsWith('--$name=')) return a.substring(name.length + 3);
    }
    return null;
  }

  bool get _offscreen => args.contains('--kp-offscreen');

  bool get active => _arg('kp-add-mock') != null || (_offscreen && (_arg('kp-shot') != null || _arg('kp-soak') != null));

  /// [quit] closes the app the way users do (player released first).
  Future<void> run(AppState app, PlayerController player, {required Future<void> Function() quit}) async {
    final mock = _arg('kp-add-mock');
    if (mock != null && app.sources.isEmpty) {
      final input = NewSourceInput(
        kind: SourceType.xtream,
        name: 'Demo sağlayıcı',
        url: mock,
        username: 'demo',
        password: 'demo',
        insecureTls: false,
      );
      await for (final e in app.library.addSource(input)) {
        if (e is SyncEvent_Done) await app.sourceChanged(e.source);
        if (e is SyncEvent_Failed) stderr.writeln('add mock failed: ${e.message}');
      }
    }

    final soak = int.tryParse(_arg('kp-soak') ?? '');
    if (soak != null && _offscreen) {
      await _soak(app, player, Duration(minutes: soak), every: Duration(seconds: int.tryParse(_arg('kp-soak-every') ?? '') ?? 60));
      await quit();
      return;
    }

    final dir = _arg('kp-shot');
    if (dir == null || !_offscreen) return;
    // Offscreen runs keep secrets in memory, so a test key never reaches
    // (or replaces a key in) the user's keyring.
    final language = _arg('kp-language');
    if (language != null) await app.setLanguage(language);
    final tmdbKey = _arg('kp-tmdb-key');
    if (tmdbKey != null) await app.library.setTmdbKey(tmdbKey);
    await Directory(dir).create(recursive: true);
    Future<void> shot(String name, {Duration wait = const Duration(milliseconds: 1500)}) async {
      await Future<void>.delayed(wait);
      await _capture('$dir${Platform.pathSeparator}$name.png');
    }

    for (final s in [Section.home, Section.live, Section.guide, Section.movies, Section.series, Section.search, Section.settings]) {
      app.go(s);
      await shot(s.name, wait: const Duration(milliseconds: 2500));
    }

    // The command palette with a query matching commands and the library.
    final ctx = rootNavigator.currentContext;
    if (ctx != null && ctx.mounted) {
      unawaited(showCommandPalette(ctx, query: 'ka'));
      await shot('palette', wait: const Duration(milliseconds: 1200));
      rootNavigator.currentState?.pop();
    }

    // A reminder coming due, through the real storage, then its banner.
    // No taskbar flash: captures never draw attention.
    app.reminders.onDue = null;
    if (app.activeSource?.id case final rsid?) {
      final first = await app.library.page(rsid, Kind.live, limit: 1);
      if (first.isNotEmpty) {
        final at = DateTime.now().millisecondsSinceEpoch ~/ 1000 + 30;
        await app.library.setReminder(first.first.id, at, at + 1800, 'Akşam Haberleri', on: true);
        await app.reminders.load(rsid);
        app.go(Section.home);
        await shot('reminder', wait: const Duration(milliseconds: 1200));
        app.reminders.dismiss();
        await app.library.setReminder(first.first.id, at, at + 1800, '', on: false);
        await app.reminders.load(rsid);
      }
    }

    // Parental lock through the real core: adult categories leave the rail
    // and a "locked categories" row takes their place.
    await app.setPin(pin: '2580');
    app.go(Section.live);
    await shot('live-locked', wait: const Duration(milliseconds: 1500));
    await app.setPin(current: '2580', pin: null);

    // Live preview, then the full player with its OSD.
    app.go(Section.live);
    await Future<void>.delayed(const Duration(milliseconds: 800));
    final sid = app.activeSource?.id;
    if (sid != null) {
      final channels = await app.library.page(sid, Kind.live, limit: 30);
      if (channels.isNotEmpty) {
        // A catch-up channel, so the preview shows its past programmes too.
        final channel = channels.firstWhere((c) => c.hasCatchup, orElse: () => channels.first);
        await player.play(channel, Kind.live, queue: channels, view: PlayerView.preview);
        await shot('live-preview', wait: const Duration(milliseconds: 2500));
        player.setView(PlayerView.full);
        await shot('player', wait: const Duration(milliseconds: 1200));
        // Local timeshift on the live stream: pause, step back, capture.
        if (player.canTimeshift) {
          await Future<void>.delayed(const Duration(seconds: 6));
          await player.togglePause();
          await Future<void>.delayed(const Duration(seconds: 3));
          await player.seekBy(const Duration(seconds: -5));
          await Future<void>.delayed(const Duration(milliseconds: 1500));
          final range = await player.engine.seekableRange();
          await File('$dir${Platform.pathSeparator}timeshift.txt').writeAsString(
            'range=${range?.$1.inMilliseconds}..${range?.$2.inMilliseconds} '
            'position=${player.position.value.inMilliseconds} playing=${player.playing}',
          );
          await shot('player-timeshift', wait: const Duration(milliseconds: 300));
          await player.goLive();
        }
        // Statistics after a few samples, with the provider checked.
        player.statsPanelRequest.value = true;
        await shot('player-stats', wait: const Duration(milliseconds: 3500));
        final past = await app.library.archive(channel.id);
        if (past.isNotEmpty) {
          await player.play(channel, Kind.live, queue: channels, programme: past.first, view: PlayerView.full);
          await shot('player-catchup', wait: const Duration(milliseconds: 1500));
        }
        await player.stop();
      }
      final movies = await app.library.page(sid, Kind.movie, limit: 5);
      if (movies.isNotEmpty) {
        app.openDetail(movies.first, Kind.movie);
        await shot('movie-detail', wait: const Duration(milliseconds: 2500));
        // Track picker input as the player sees it, labels included.
        await player.play(movies.first, Kind.movie, view: PlayerView.full, fromStart: true);
        await Future<void>.delayed(const Duration(milliseconds: 1500));
        final lines = <String>[];
        for (final kind in TrackKind.values) {
          final list = player.tracks.where((t) => t.kind == kind).toList();
          for (final (i, l) in trackLabels(list).indexed) {
            lines.add('${kind.name} | ${list[i].selected ? '*' : ' '} | ${l.name} | ${l.detail}');
          }
        }
        await File('$dir${Platform.pathSeparator}tracks.txt').writeAsString(lines.join(String.fromCharCode(10)));
        // The seek bar must have moved by now.
        await shot('player-movie', wait: const Duration(milliseconds: 3500));
        // The audio/subtitle panel with same-language tracks.
        player.tracksPanelRequest.value = true;
        await shot('player-tracks', wait: const Duration(milliseconds: 600));
        await File('$dir${Platform.pathSeparator}position.txt').writeAsString('${player.position.value.inMilliseconds}');
        await player.stop();
      }
      final series = await app.library.page(sid, Kind.series, limit: 5);
      if (series.isNotEmpty) {
        app.openDetail(series.first, Kind.series);
        await shot('series-detail', wait: const Duration(milliseconds: 2500));
      }
    }
    // An M3U source with an XMLTV guide: its EPG grid and status line.
    if (mock != null) {
      final m3u = NewSourceInput(kind: SourceType.m3U, name: 'M3U listesi', url: '$mock/playlist.m3u?n=60', insecureTls: false);
      await for (final e in app.library.addSource(m3u)) {
        if (e is SyncEvent_Done) await app.sourceChanged(e.source);
      }
      app.go(Section.guide);
      await shot('guide-m3u', wait: const Duration(milliseconds: 2500));
      app.go(Section.settings);
      await shot('settings-m3u', wait: const Duration(milliseconds: 1500));
    }
    await quit();
  }

  /// Long run for leaks: live TV for [length], a new channel every minute.
  /// Memory is sampled from outside (tools/soak.ps1); zap times and
  /// reconnects land in perf.jsonl as usual.
  Future<void> _soak(AppState app, PlayerController player, Duration length, {required Duration every}) async {
    final sid = app.activeSource?.id;
    if (sid == null) return;
    final channels = await app.library.page(sid, Kind.live, limit: 40);
    if (channels.isEmpty) return;
    final end = DateTime.now().add(length);
    app.go(Section.live);
    await player.play(channels.first, Kind.live, queue: channels, view: PlayerView.full);
    while (DateTime.now().isBefore(end)) {
      await Future<void>.delayed(every);
      await player.zap(1);
    }
    await player.stop();
  }

  Future<void> _capture(String path) async {
    final boundary = boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return;
    final image = await boundary.toImage(pixelRatio: 1);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    if (png != null) await File(path).writeAsBytes(png.buffer.asUint8List());
  }
}
