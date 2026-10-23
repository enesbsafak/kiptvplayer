// Phones and tablets held upright: every section lays out without overflow,
// the bottom bar and top bar reach every section, a tap on a channel plays
// it full screen and back leaves the player.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/app_state.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/player/media_track.dart';
import 'package:karadelik_player/player/player_controller.dart';
import 'package:karadelik_player/screens/player_screen.dart';
import 'package:karadelik_player/shell/app_shell.dart';
import 'package:karadelik_player/shell/sidebar.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app;

Future<void> setPhone(WidgetTester tester, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

FakeLibrary _library() => FakeLibrary(sources: [FakeLibrary.source(name: 'Ev aboneliği, uzun bir ad')])
  ..cats[Kind.live] = const [
    Category(uid: 1, name: 'TR: Ulusal', adult: false, count: 2),
    Category(uid: 2, name: 'DE: Sport ve çok uzun bir kategori adı', adult: false, count: 1),
  ]
  ..cats[Kind.movie] = const [Category(uid: 3, name: 'Aksiyon', adult: false, count: 2)]
  ..cats[Kind.series] = const [Category(uid: 4, name: 'Dram', adult: false, count: 1)]
  ..items[Kind.live] = [FakeLibrary.item(10, 'TRT 1'), FakeLibrary.item(11, 'Kanal D'), FakeLibrary.item(12, 'Sport 1 HD Çok Uzun Kanal Adı')]
  ..items[Kind.movie] = [FakeLibrary.item(20, 'Film bir'), FakeLibrary.item(21, 'Film iki, adı uzun olan bir film')]
  ..items[Kind.series] = [FakeLibrary.item(30, 'Dizi')];

/// The message and the widget that overflowed (file and line).
String _where(FlutterErrorDetails d) {
  final text = [
    d.toString(),
    for (final n in d.informationCollector?.call() ?? const <DiagnosticsNode>[]) n.toStringDeep(),
  ].join('\n');
  final at = RegExp(r'apps/player/(lib/\S+)').firstMatch(text)?.group(1);
  return '${d.exceptionAsString().split('\n').first} @ ${at ?? '?'}';
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('small phone', const Size(360, 640)), ('tablet', const Size(820, 1180))]) {
    testWidgets('every section lays out on a $name', (tester) async {
      await setPhone(tester, size: size);
      final h = TestHarness(_library());
      await h.state.load();
      // Collected with where they came from, not just the first message.
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => errors.add('${h.state.section}: ${_where(d)}');
      addTearDown(() => FlutterError.onError = previous);
      await tester.pumpWidget(app(h, const AppShell()));
      await tester.pumpAndSettle();
      for (final s in Section.values) {
        h.state.go(s);
        await tester.pumpAndSettle();
      }
      FlutterError.onError = previous;
      expect(errors, isEmpty, reason: 'on a $name');
    });
  }

  for (final size in [const Size(390, 844), const Size(320, 640)]) {
    testWidgets('first run (add a source) lays out at ${size.width.toInt()} px', (tester) async {
      await setPhone(tester, size: size);
      final h = TestHarness(FakeLibrary());
      await h.state.load();
      final errors = <String>[];
      final previous = FlutterError.onError;
      FlutterError.onError = (d) => errors.add(_where(d));
      addTearDown(() => FlutterError.onError = previous);
      await tester.pumpWidget(app(h, const AppShell()));
      await tester.pumpAndSettle();
      // Every source type, with its fields.
      for (final type in ['M3U bağlantısı', 'M3U dosyası', 'Stalker portalı', 'Xtream Codes']) {
        await tester.ensureVisible(find.text(type));
        await tester.tap(find.text(type));
        await tester.pumpAndSettle();
      }
      FlutterError.onError = previous;
      expect(errors, isEmpty);
    });
  }

  testWidgets('the bottom bar and the top bar reach the sections', (tester) async {
    await setPhone(tester);
    final h = TestHarness(_library());
    await h.state.load();
    await tester.pumpWidget(app(h, const AppShell()));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byType(CompactNavBar), matching: find.text('Canlı TV')));
    await tester.pumpAndSettle();
    expect(h.state.section, Section.live);
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
    expect(h.state.section, Section.settings);
    await tester.tap(find.byTooltip('Ara'));
    await tester.pumpAndSettle();
    expect(h.state.section, Section.search);
  });

  testWidgets('live TV: categories in a sheet, a tap plays full screen, back stops it', (tester) async {
    await setPhone(tester);
    final lib = _library();
    final h = TestHarness(lib);
    await h.state.load();
    h.state.go(Section.live);
    await tester.pumpWidget(app(h, const AppShell()));
    await tester.pumpAndSettle();

    // The current category on a button; the list opens in a sheet.
    await tester.tap(find.text('Tüm kanallar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('TR: Ulusal'));
    await tester.pumpAndSettle();
    expect(find.text('TR: Ulusal'), findsOneWidget, reason: 'the sheet closed and the button shows the choice');

    await tester.tap(find.text('Kanal D'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(lib.played, [11]);
    expect(h.player.view, PlayerView.full);
    expect(find.byType(PlayerScreen), findsOneWidget);

    // Android's back button: no preview pane on a phone, so playback stops.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.player.view, PlayerView.hidden);
    expect(h.state.section, Section.live, reason: 'back left the player, not the section');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.state.section, Section.home);
  });

  testWidgets('live TV: a new category starts unfiltered; an empty filter result says why', (tester) async {
    await setPhone(tester);
    final lib = _library()..categoryOf.addAll({10: 1, 11: 1, 12: 2});
    final h = TestHarness(lib);
    await h.state.load();
    h.state.go(Section.live);
    await tester.pumpWidget(app(h, const AppShell()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'trt');
    await tester.pumpAndSettle();
    expect(find.text('Kanal D'), findsNothing);

    // Another category: its channels show, not the old filter's leftovers.
    await tester.tap(find.text('Tüm kanallar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('DE: Sport ve çok uzun bir kategori adı'));
    await tester.pumpAndSettle();
    expect(find.text('Sport 1 HD Çok Uzun Kanal Adı'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

    // A filter with no match here says so and offers the way out.
    await tester.enterText(find.byType(TextField), 'trt');
    await tester.pumpAndSettle();
    expect(find.textContaining('“trt” ile eşleşen kanal yok'), findsOneWidget);
    await tester.tap(find.text('Aramayı temizle'));
    await tester.pumpAndSettle();
    expect(find.text('Sport 1 HD Çok Uzun Kanal Adı'), findsOneWidget);
  });

  testWidgets('live TV: a list that fails to load says so and retries', (tester) async {
    await setPhone(tester);
    final lib = _library()..pageError = Exception('disk I/O error');
    final h = TestHarness(lib);
    await h.state.load();
    h.state.go(Section.live);
    await tester.pumpWidget(app(h, const AppShell()));
    await tester.pumpAndSettle();
    expect(find.text('Kanallar yüklenemedi'), findsOneWidget, reason: 'not "no channels"');
    expect(find.text('Kanal bulunamadı'), findsNothing);

    lib.pageError = null;
    await tester.tap(find.text('Tekrar dene'));
    await tester.pumpAndSettle();
    expect(find.text('TRT 1'), findsOneWidget);
  });

  testWidgets('player on a phone on its side: audio, subtitles and settings fit in a sheet', (tester) async {
    await setPhone(tester, size: const Size(800, 360));
    final lib = _library();
    final h = TestHarness(lib);
    await h.state.load();
    h.state.go(Section.live);
    await tester.pumpWidget(app(h, const AppShell()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kanal D'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(h.player.view, PlayerView.full);
    h.engine.tracksCtl.add(MediaTrack.parseTrackList('''[
      {"id":1,"type":"audio","lang":"tur","codec":"aac","selected":true},
      {"id":2,"type":"audio","lang":"eng","codec":"aac"},
      {"id":1,"type":"sub","lang":"tur","codec":"subrip"},
      {"id":2,"type":"sub","lang":"eng","codec":"subrip","selected":true},
      {"id":3,"type":"sub","lang":"ger","codec":"subrip"},
      {"id":4,"type":"sub","lang":"fre","codec":"subrip"},
      {"id":5,"type":"sub","lang":"spa","codec":"subrip"},
      {"id":6,"type":"sub","lang":"ara","codec":"subrip"}
    ]'''));
    await tester.pump();

    // The subtitles button on the controls (a phone has no A key).
    await tester.tap(find.byTooltip('Ses ve altyazı (A)'));
    await tester.pump();
    await tester.pump();
    final screen = Offset.zero & const Size(800, 360);
    bool onScreen(Finder f) => screen.contains(tester.getTopLeft(f)) && screen.contains(tester.getBottomRight(f));
    expect(onScreen(find.textContaining('İngilizce').first), isTrue, reason: 'audio tab');

    await tester.tap(find.text('Altyazı').last);
    await tester.pump();
    expect(find.text('Kapalı'), findsOneWidget);
    // The last subtitle is reachable by scrolling inside the sheet.
    await tester.scrollUntilVisible(find.textContaining('Arapça'), 60, scrollable: find.byType(Scrollable).last);
    expect(onScreen(find.textContaining('Arapça')), isTrue);

    await tester.tap(find.text('Ayarlar').last);
    await tester.pump();
    expect(onScreen(find.text('Altyazı gecikmesi')), isTrue);
    // An overflow anywhere would have failed the test on its own.
  });
}
