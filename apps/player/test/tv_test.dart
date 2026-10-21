// Android TV / Google TV: a 1080p TV (960x540 dp) with the TV frame, driven
// only with a remote's keys: every section lays out, the sidebar takes the
// first focus, the arrows reach a channel, OK plays it, the player answers the
// remote and back walks out the way it came.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/app_state.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/app/platform.dart';
import 'package:karadelik_player/design/theme.dart';
import 'package:karadelik_player/player/player_controller.dart';
import 'package:karadelik_player/screens/player_screen.dart';
import 'package:karadelik_player/shell/app_shell.dart';
import 'package:karadelik_player/shell/sidebar.dart';
import 'package:karadelik_player/shell/tv.dart';

import 'fakes.dart';

Future<void> setTv(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 2;
  isTv = true;
  addTearDown(() {
    isTv = false;
    tester.view.reset();
  });
}

Widget tvApp(TestHarness h) => h.wrap(
  MaterialApp(
    theme: buildKdTheme(),
    builder: (context, child) => TvFrame(child: child!),
    home: const Scaffold(body: AppShell()),
  ),
);

FakeLibrary _library() => FakeLibrary(sources: [FakeLibrary.source(name: 'Ev aboneliği')])
  ..cats[Kind.live] = const [
    Category(uid: 1, name: 'TR: Ulusal', adult: false, count: 3),
    Category(uid: 2, name: 'DE: Sport', adult: false, count: 1),
  ]
  ..cats[Kind.movie] = const [Category(uid: 3, name: 'Aksiyon', adult: false, count: 2)]
  ..cats[Kind.series] = const [Category(uid: 4, name: 'Dram', adult: false, count: 1)]
  ..items[Kind.live] = [FakeLibrary.item(10, 'TRT 1'), FakeLibrary.item(11, 'Kanal D'), FakeLibrary.item(12, 'Sport 1 HD')]
  ..items[Kind.movie] = [FakeLibrary.item(20, 'Film bir'), FakeLibrary.item(21, 'Film iki')]
  ..items[Kind.series] = [FakeLibrary.item(30, 'Dizi')];

FocusNode? get _focused => FocusManager.instance.primaryFocus;

/// The texts inside the focused widget: what a viewer sees highlighted.
String _focusedLabel() {
  final texts = <String>[];
  void visit(Element e) {
    final w = e.widget;
    if (w is Text && w.data != null) texts.add(w.data!);
    e.visitChildren(visit);
  }

  final focused = _focused;
  // A whole pane or screen is never what a remote highlights.
  if (focused == null || focused.rect.height > 120) return '';
  final context = focused.context;
  if (context is Element) visit(context);
  return texts.join(' | ');
}

/// Presses [key] until the focused widget shows [label], as a viewer would.
Future<void> _moveTo(WidgetTester tester, LogicalKeyboardKey key, String label, {int max = 10}) async {
  for (var i = 0; i < max && !_focusedLabel().contains(label); i++) {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }
  expect(_focusedLabel(), contains(label), reason: 'the remote reached "$label"');
}

void main() {
  testWidgets('every section lays out on a TV, beside the sidebar', (tester) async {
    await setTv(tester);
    final h = TestHarness(_library());
    await h.state.load();
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) => errors.add('${h.state.section}: ${d.exceptionAsString().split('\n').first}');
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(tvApp(h));
    await tester.pumpAndSettle();
    expect(find.byType(Sidebar), findsOneWidget, reason: 'a TV keeps the left rail');
    expect(find.byType(CompactNavBar), findsNothing);
    for (final s in Section.values) {
      h.state.go(s);
      await tester.pumpAndSettle();
    }
    FlutterError.onError = previous;
    expect(errors, isEmpty);
  });

  testWidgets('first run on a TV lays out and the form is reachable', (tester) async {
    await setTv(tester);
    final h = TestHarness(FakeLibrary());
    await h.state.load();
    final errors = <String>[];
    final previous = FlutterError.onError;
    FlutterError.onError = (d) => errors.add(d.exceptionAsString().split('\n').first);
    addTearDown(() => FlutterError.onError = previous);
    await tester.pumpWidget(tvApp(h));
    await tester.pumpAndSettle();
    for (final type in ['M3U bağlantısı', 'Stalker portalı', 'Xtream Codes']) {
      await tester.ensureVisible(find.text(type));
      await tester.tap(find.text(type));
      await tester.pumpAndSettle();
    }
    FlutterError.onError = previous;
    expect(errors, isEmpty);
  });

  testWidgets('a remote reaches a channel, plays it, zaps and backs out', (tester) async {
    await setTv(tester);
    final lib = _library();
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(tvApp(h));
    await tester.pumpAndSettle();

    // The open section starts with the focus.
    expect(_focusedLabel(), contains('Ana Sayfa'));
    await _moveTo(tester, LogicalKeyboardKey.arrowDown, 'Canlı TV');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(h.state.section, Section.live);

    // Right into the channels, down to the second one; OK plays it.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    await _moveTo(tester, LogicalKeyboardKey.arrowDown, 'Kanal D');
    expect(lib.played, isEmpty, reason: 'moving along the list plays nothing');
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump(const Duration(milliseconds: 400));
    expect(lib.played, [11]);
    expect(h.player.view, PlayerView.full);
    expect(find.byType(PlayerScreen), findsOneWidget);
    await tester.pump();
    expect(_focused?.debugLabel, 'player', reason: 'the player takes the remote');

    // Channel down zaps to the next channel.
    await tester.sendKeyEvent(LogicalKeyboardKey.channelDown);
    await tester.pump(const Duration(milliseconds: 400));
    expect(lib.played, [11, 12]);

    // The info key opens audio and subtitles, on screen and with the focus.
    await tester.sendKeyEvent(LogicalKeyboardKey.info);
    await tester.pump();
    await tester.pump();
    final subtitles = find.textContaining(RegExp('altyazı', caseSensitive: false)).first;
    final screen = Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(screen.contains(tester.getTopLeft(subtitles)), isTrue, reason: 'the panel fits the TV');
    expect(_focused?.debugLabel, isNot('player'), reason: 'the panel took the remote');
    await tester.sendKeyEvent(LogicalKeyboardKey.info);
    await tester.pump();
    expect(_focused?.debugLabel, 'player');

    // OK brings the controls up on the play button; the arrows move on.
    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pump();
    await tester.pump();
    expect(_focused?.debugLabel, 'player-play');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(_focused?.debugLabel, isNot('player-play'));
    expect(lib.played, [11, 12], reason: 'arrows on the buttons move, they do not zap');

    // Back hides the controls first, then leaves the player.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 400));
    expect(_focused?.debugLabel, 'player');
    expect(h.player.view, PlayerView.full);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(h.player.view, PlayerView.hidden);
    expect(h.state.section, Section.live);
    expect(_focusedLabel(), contains('Kanal D'), reason: 'the focus is back on the channel it left from');
  });

  testWidgets('a text field on a TV opens the keyboard only on OK', (tester) async {
    await setTv(tester);
    final h = TestHarness(_library());
    await h.state.load();
    h.state.go(Section.live);
    await tester.pumpWidget(tvApp(h));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    // Down from the category button onto the filter: framed, not typing.
    await _moveTo(tester, LogicalKeyboardKey.arrowDown, 'TRT 1');
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(_focused?.debugLabel, 'input-frame');
    expect(tester.testTextInput.isVisible, isFalse, reason: 'passing over the field keeps the keyboard down');

    await tester.sendKeyEvent(LogicalKeyboardKey.select);
    await tester.pumpAndSettle();
    expect(tester.testTextInput.isVisible, isTrue);
    await tester.enterText(find.byType(TextField), 'kanal');
    await tester.pumpAndSettle();
    expect(find.text('TRT 1'), findsNothing, reason: 'the filter applies');

    // Down leaves the field for the list.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(_focusedLabel(), contains('Kanal D'));
  });
}
