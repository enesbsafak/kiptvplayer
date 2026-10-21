// From real-provider feedback: long category lists, clearing watch history,
// subtitles above the player controls.

import 'package:flutter/widgets.dart' show EditableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/player/player_controller.dart';
import 'package:karadelik_player/screens/home_screen.dart';
import 'package:karadelik_player/screens/player_screen.dart';
import 'package:karadelik_player/screens/vod_screen.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

void main() {
  testWidgets('movies list categories down the left, filterable without accents', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()])
      ..cats[Kind.movie] = [
        for (var i = 0; i < 20; i++) Category(uid: i + 1, name: 'TR/FILM ⚡ KATEGORI $i', adult: false, count: 10),
        const Category(uid: 99, name: 'TR/FILM ⚡ BİLİM KURGU', adult: false, count: 535),
      ]
      ..items[Kind.movie] = [FakeLibrary.item(1, 'Film')];
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const VodScreen(kind: Kind.movie)));
    await tester.pumpAndSettle();

    expect(find.text('Tümü'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).first, 'bilim');
    await tester.pumpAndSettle();
    expect(find.text('TR/FILM ⚡ BİLİM KURGU'), findsOneWidget, reason: '"bilim" finds "BİLİM"');
    expect(find.text('TR/FILM ⚡ KATEGORI 3'), findsNothing);
  });

  testWidgets('recent channels and resume points can be cleared from Home', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()])..recentItems = [FakeLibrary.item(10, 'TRT 1')];
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, HomeScreen(onOpen: (_, _) {})));
    await tester.pumpAndSettle();
    expect(find.text('Son izlenen kanallar'), findsOneWidget);

    await tester.tap(find.text('Temizle'));
    await tester.pumpAndSettle();
    expect(lib.cleared, [(true, false)], reason: 'only recent channels');
    expect(find.text('Son izlenen kanallar'), findsNothing);
  });

  testWidgets('subtitles rise above the controls while they show, then drop back', (tester) async {
    await setLargeWindow(tester);
    final h = TestHarness(FakeLibrary(sources: [FakeLibrary.source()]));
    await h.state.load();
    // Live TV: no resume-point timer to outlive the test.
    final channel = FakeLibrary.item(7, 'TRT 1');
    await h.player.play(channel, Kind.live, queue: [channel], view: PlayerView.full);
    await tester.pumpWidget(app(h, const PlayerScreen()));
    await tester.pump();
    expect(h.engine.subtitlePositions.last, lessThan(100), reason: 'controls visible: raised');

    await tester.pump(const Duration(seconds: 4));
    expect(h.engine.subtitlePositions.last, 100, reason: 'controls faded: usual place');
  });
}
