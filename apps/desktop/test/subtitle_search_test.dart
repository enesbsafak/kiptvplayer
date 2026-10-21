// OpenSubtitles from the player and its key in Settings.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/player/player_controller.dart';
import 'package:karadelik_player/screens/subtitle_search.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

Future<TestHarness> _playing(WidgetTester tester, FakeLibrary lib) async {
  await setLargeWindow(tester);
  final h = TestHarness(lib);
  await h.state.load();
  final film = FakeLibrary.item(50, 'Film');
  // Not awaited: a film's resume timer would outlive the test otherwise.
  h.player.play(film, Kind.movie, view: PlayerView.preview);
  await tester.pumpWidget(app(h, Builder(
    builder: (context) => TextButton(onPressed: () => showSubtitleSearch(context, h.player), child: const Text('ara')),
  )));
  await tester.pump();
  return h;
}

/// The film's resume-point timer goes with the player.
Future<void> _done(WidgetTester tester, TestHarness h) async {
  await tester.pumpWidget(const SizedBox());
  h.player.dispose();
}

void main() {
  testWidgets('without a key the dialog points to Settings', (tester) async {
    final lib = FakeLibrary(sources: [FakeLibrary.source()]);
    final h = await _playing(tester, lib);
    await tester.tap(find.text('ara'));
    await tester.pumpAndSettle();
    expect(find.text('Ayarlara git'), findsOneWidget);
    expect(lib.subtitleSearches, isEmpty);
    await _done(tester, h);
  });

  testWidgets('results load, a click downloads and turns the subtitle on', (tester) async {
    final lib = FakeLibrary(sources: [FakeLibrary.source()])..opensubsKey = 'os-key';
    final h = await _playing(tester, lib);
    await tester.tap(find.text('ara'));
    await tester.pumpAndSettle();
    expect(lib.subtitleSearches, [(50, null, null)]);
    expect(find.text('Film.1080p.WEB'), findsOneWidget);
    expect(find.text('Türkçe'), findsOneWidget);
    expect(find.text('SDH'), findsOneWidget);

    await tester.tap(find.text('Film.1080p.WEB'));
    await tester.pumpAndSettle();
    expect(h.engine.adjustments['subFile'], 'C:/subs/1.srt');
    expect(h.engine.adjustments['subFileName'], ('OpenSubtitles', 'tr'));
    expect(find.byType(AlertDialog), findsNothing);
    await _done(tester, h);
  });

  testWidgets('the key is checked before it is kept', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()]);
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const OpenSubsSettings()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'yanlis');
    await tester.tap(find.text('Doğrula ve kaydet').first);
    await tester.pumpAndSettle();
    expect(find.text('OpenSubtitles anahtarı reddedildi'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'os-key');
    await tester.tap(find.text('Doğrula ve kaydet').first);
    await tester.pumpAndSettle();
    expect(lib.opensubsKey, 'os-key');
  });
}
