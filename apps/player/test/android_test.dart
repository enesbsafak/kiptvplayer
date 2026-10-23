// The Android phone layout (lib/mobile): every section lays out between the
// glass bars at Android's text size, the floating bar and the top bar reach
// the sections, the system back gesture shrinks the screen and goes back,
// a long press opens the actions in a sheet, and the playing stream waits
// in the mini bar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/app_state.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/app/platform.dart';
import 'package:karadelik_player/design/theme.dart';
import 'package:karadelik_player/mobile/glass.dart';
import 'package:karadelik_player/mobile/intro.dart';
import 'package:karadelik_player/mobile/mobile_shell.dart';
import 'package:karadelik_player/player/player_controller.dart';
import 'package:karadelik_player/screens/player_screen.dart';
import 'package:karadelik_player/shell/app_shell.dart';

import 'fakes.dart';

Future<void> setAndroidPhone(WidgetTester tester, {Size size = const Size(390, 844)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 16);
  androidUi = true;
  addTearDown(() {
    androidUi = false;
    tester.view.reset();
  });
}

/// As main.dart builds it on Android, with its larger type.
Widget androidApp(TestHarness h) => h.wrap(
  MaterialApp(
    theme: buildKdTheme(android: true),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.15)),
      child: child!,
    ),
    home: const Scaffold(body: AppShell()),
  ),
);

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

Finder _nav(String label) => find.descendant(of: find.byType(MobileShell), matching: find.text(label));

/// What Android sends while the user drags back from the left edge.
Future<void> _backGesture(WidgetTester tester, String method, [double progress = 0]) async {
  final message = const StandardMethodCodec().encodeMethodCall(
    MethodCall(method, method == 'startBackGesture' || method == 'updateBackGestureProgress'
        ? <String, Object?>{'touchOffset': <double>[5, 300], 'progress': progress, 'swipeEdge': 0}
        : null),
  );
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage('flutter/backgesture', message, (_) {});
}

void main() {
  for (final (name, size) in [('phone', const Size(390, 844)), ('small phone', const Size(360, 640))]) {
    testWidgets('every section lays out on an Android $name', (tester) async {
      await setAndroidPhone(tester, size: size);
      final h = TestHarness(_library());
      await h.state.load();
      await tester.pumpWidget(androidApp(h));
      await tester.pumpAndSettle();
      expect(find.byType(MobileShell), findsOneWidget);
      for (final s in Section.values) {
        h.state.go(s);
        await tester.pumpAndSettle();
      }
      // An overflow anywhere fails the test by itself.
    });
  }

  testWidgets('first run on Android lays out', (tester) async {
    await setAndroidPhone(tester, size: const Size(360, 640));
    final h = TestHarness(FakeLibrary());
    await h.state.load();
    await tester.pumpWidget(androidApp(h));
    await tester.pumpAndSettle();
    for (final type in ['M3U bağlantısı', 'M3U dosyası', 'Stalker portalı', 'Xtream Codes']) {
      await tester.ensureVisible(find.text(type));
      await tester.tap(find.text(type));
      await tester.pumpAndSettle();
    }
  });

  testWidgets('the floating bar and the top bar reach the sections', (tester) async {
    await setAndroidPhone(tester);
    final h = TestHarness(_library());
    await h.state.load();
    await tester.pumpWidget(androidApp(h));
    await tester.pumpAndSettle();

    await tester.tap(_nav('Canlı TV'));
    await tester.pumpAndSettle();
    expect(h.state.section, Section.live);
    await tester.tap(_nav('Filmler'));
    await tester.pumpAndSettle();
    expect(h.state.section, Section.movies);
    await tester.tap(find.byTooltip('Ayarlar'));
    await tester.pumpAndSettle();
    expect(h.state.section, Section.settings);
    await tester.tap(find.byTooltip('Yayın Akışı'));
    await tester.pumpAndSettle();
    expect(h.state.section, Section.guide);
  });

  testWidgets('the predictive back shrinks the screen with the finger, then goes back', (tester) async {
    await setAndroidPhone(tester);
    final h = TestHarness(_library());
    await h.state.load();
    h.state.go(Section.movies);
    await tester.pumpWidget(androidApp(h));
    await tester.pumpAndSettle();

    await _backGesture(tester, 'startBackGesture');
    await _backGesture(tester, 'updateBackGestureProgress', 0.5);
    await tester.pump();
    final scaled = tester.widgetList<Transform>(find.descendant(of: find.byType(MobileShell), matching: find.byType(Transform)));
    expect(scaled.any((t) => (t.transform.storage[0] - 0.95).abs() < 0.001), isTrue, reason: 'half way: 95 %');

    // Let go before the end: nothing happens.
    await _backGesture(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(h.state.section, Section.movies);

    await _backGesture(tester, 'startBackGesture');
    await _backGesture(tester, 'updateBackGestureProgress', 0.8);
    await _backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(h.state.section, Section.home);
  });

  testWidgets('a long press on a channel opens its actions in a sheet', (tester) async {
    await setAndroidPhone(tester);
    final h = TestHarness(_library());
    await h.state.load();
    h.state.go(Section.live);
    await tester.pumpWidget(androidApp(h));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Kanal D'));
    await tester.pumpAndSettle();
    expect(find.text('Yeniden adlandır…'), findsOneWidget);
    expect(find.byType(PopupMenuItem<int>), findsNothing, reason: 'not the desktop menu');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Yeniden adlandır…'), findsNothing);
  });

  testWidgets('the playing stream waits in the mini bar; a tap opens the player', (tester) async {
    await setAndroidPhone(tester);
    final lib = _library();
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(androidApp(h));
    await tester.pumpAndSettle();
    await h.player.play(lib.items[Kind.live]![1], Kind.live, view: PlayerView.preview);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Kapat'), findsOneWidget, reason: 'the mini bar');
    await tester.tap(find.text('CANLI'));
    await tester.pumpAndSettle();
    expect(h.player.view, PlayerView.full);
    expect(find.byType(PlayerScreen), findsOneWidget);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.player.view, isNot(PlayerView.full));
  });

  testWidgets('the opening plays over a usable app, then leaves', (tester) async {
    await setAndroidPhone(tester);
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: KdIntro(child: Center(child: TextButton(onPressed: () => taps++, child: const Text('içeride')))),
    ));
    expect(find.byType(CustomPaint), findsWidgets, reason: 'the horizon is drawn');
    await tester.tap(find.text('içeride'), warnIfMissed: false);
    expect(taps, 1, reason: 'the app takes touches from the first frame');
    await tester.pump(KdIntro.duration ~/ 2);
    expect(find.byType(IgnorePointer), findsWidgets);
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is Image), findsNothing, reason: 'the mark is gone');
  });

  testWidgets('no opening when animations are off', (tester) async {
    await setAndroidPhone(tester);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: KdIntro(child: const Text('içeride')),
      ),
    ));
    expect(find.byWidgetPredicate((w) => w is Image), findsNothing);
  });

  testWidgets('the player: glass controls, a double tap on a side seeks 10 s', (tester) async {
    await setAndroidPhone(tester, size: const Size(800, 390));
    final lib = _library();
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(androidApp(h));
    await tester.pumpAndSettle();
    await h.player.play(lib.items[Kind.movie]![0], Kind.movie, view: PlayerView.full);
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(PlayerScreen), matching: find.byType(KdGlass)), findsWidgets);

    final screen = tester.getRect(find.byType(PlayerScreen));
    final right = Offset(screen.right - 120, screen.center.dy);
    await tester.tapAt(right);
    await tester.pump(const Duration(milliseconds: 60));
    await tester.tapAt(right);
    await tester.pumpAndSettle();
    expect(h.engine.seeks, isNotEmpty, reason: 'a double tap on the right seeks');
    expect(find.text('10 s »'), findsOneWidget);
    // The controls hide on a timer; leave the player before the test ends.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle(const Duration(seconds: 6));
  });

  testWidgets('back closes a detail first: to the list, or to where it was opened from', (tester) async {
    await setAndroidPhone(tester);
    final lib = _library();
    final h = TestHarness(lib);
    await h.state.load();
    h.state.go(Section.movies);
    await tester.pumpWidget(androidApp(h));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Film bir'));
    await tester.pumpAndSettle();
    expect(find.text('Oynat'), findsOneWidget, reason: 'the detail is open');
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.state.section, Section.movies, reason: 'back closed the detail, not the section');
    expect(find.text('Oynat'), findsNothing);

    // Opened from home: back returns home.
    h.state.go(Section.home);
    await tester.pumpAndSettle();
    h.state.openDetail(lib.items[Kind.movie]![1], Kind.movie);
    await tester.pumpAndSettle();
    expect(h.state.section, Section.movies);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.state.section, Section.home);
  });

  testWidgets('every settings tab lays out on a small Android phone', (tester) async {
    await setAndroidPhone(tester, size: const Size(360, 640));
    final h = TestHarness(_library());
    await h.state.load();
    h.state.go(Section.settings);
    await tester.pumpWidget(androidApp(h));
    await tester.pumpAndSettle();
    for (final tab in ['Tercihler', 'Hakkında', 'Kaynaklar']) {
      await tester.tap(find.text(tab).first);
      await tester.pumpAndSettle();
      // Down to the end: the fields and links further down lay out too.
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -4000));
      await tester.pumpAndSettle();
    }
    // An overflow anywhere fails the test by itself.
  });

  testWidgets('a phone on its side: the sections in a rail, every section lays out', (tester) async {
    await setAndroidPhone(tester, size: const Size(844, 390));
    final h = TestHarness(_library());
    await h.state.load();
    await tester.pumpWidget(androidApp(h));
    await tester.pumpAndSettle();
    // The rail sits on the left, the content beside it, full height.
    final live = tester.getRect(_nav('Canlı TV'));
    expect(live.left, lessThan(100), reason: 'a rail on the left, not a bar at the bottom');
    await tester.tap(_nav('Canlı TV'));
    await tester.pumpAndSettle();
    expect(h.state.section, Section.live);
    for (final s in Section.values) {
      h.state.go(s);
      await tester.pumpAndSettle();
    }
    // An overflow anywhere fails the test by itself.
  });

  testWidgets('a long-running series: the seasons scroll sideways to the last one', (tester) async {
    await setAndroidPhone(tester, size: const Size(360, 640));
    final lib = _library();
    lib.episodesOf[30] = [
      for (var season = 1; season <= 14; season++)
        for (var n = 1; n <= 2; n++)
          EpisodeInfo(extId: season * 100 + n, season: season, number: n, title: 'S$season B$n', container: 'mkv'),
    ];
    final h = TestHarness(lib);
    await h.state.load();
    h.state.go(Section.series);
    await tester.pumpWidget(androidApp(h));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dizi'));
    await tester.pumpAndSettle();

    final last = find.text('14. Sezon');
    await tester.scrollUntilVisible(find.text('1. Sezon'), 200, scrollable: find.byType(Scrollable).first);
    await tester.dragUntilVisible(last, find.text('1. Sezon'), const Offset(-200, 0));
    await tester.pumpAndSettle();
    await tester.tap(last);
    await tester.pumpAndSettle();
    expect(find.textContaining('S14 B1'), findsOneWidget, reason: 'the last season, reached by a swipe');
  });
}
