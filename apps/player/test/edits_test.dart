// The user's own channel list: right-click to hide, rename or group, and
// Settings to bring hidden ones back.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/screens/live_screen.dart';
import 'package:karadelik_player/screens/settings_screen.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

Future<(TestHarness, FakeLibrary)> _live(WidgetTester tester) async {
  await setLargeWindow(tester);
  final lib = FakeLibrary(sources: [FakeLibrary.source()])
    ..items[Kind.live] = [FakeLibrary.item(10, 'TRT 1'), FakeLibrary.item(11, 'Kanal D'), FakeLibrary.item(12, 'Show TV')];
  final h = TestHarness(lib);
  await h.state.load();
  await tester.pumpWidget(app(h, const LiveScreen()));
  await tester.pumpAndSettle();
  return (h, lib);
}

Future<void> _rightClick(WidgetTester tester, String text) async {
  await tester.tap(find.text(text).first, buttons: kSecondaryButton);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a hidden channel leaves the list and comes back from Settings', (tester) async {
    final (h, lib) = await _live(tester);
    await _rightClick(tester, 'Kanal D');
    await tester.tap(find.text('Kanalı gizle'));
    await tester.pumpAndSettle();
    expect(lib.hiddenIds, {11});
    expect(find.text('Kanal D'), findsNothing);

    await tester.pumpWidget(app(h, const SettingsScreen()));
    await tester.tap(find.text('Tercihler'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Göster'), 200, scrollable: find.byType(Scrollable).last);
    expect(find.text('Kanal D'), findsOneWidget);
    await tester.tap(find.text('Göster'));
    await tester.pumpAndSettle();
    expect(lib.hiddenIds, isEmpty);
  });

  testWidgets('rename, then a new group with the channel in it', (tester) async {
    final (_, lib) = await _live(tester);
    await _rightClick(tester, 'TRT 1');
    await tester.tap(find.text('Yeniden adlandır…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'TRT 1 (yedek değil)');
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(find.text('TRT 1 (yedek değil)'), findsOneWidget);

    await _rightClick(tester, 'Show TV');
    await tester.tap(find.text('Yeni gruba ekle…'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Akşam');
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(lib.groups.values.single.$2, [12]);

    await tester.tap(find.text('Akşam'));
    await tester.pumpAndSettle();
    expect(find.text('Show TV'), findsOneWidget);
    expect(find.text('Kanal D'), findsNothing, reason: 'the group shows only its own');

    await _rightClick(tester, 'Show TV');
    await tester.tap(find.text('Gruptan çıkar'));
    await tester.pumpAndSettle();
    expect(lib.groups.values.single.$2, isEmpty);
  });
}
