// Parental lock: set a PIN in Settings, the rail offers the locked
// categories, the right PIN opens them and screens reload.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/screens/live_screen.dart';
import 'package:karadelik_player/screens/settings_screen.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

Future<void> _enter(WidgetTester tester, String pin) async {
  await tester.enterText(find.byType(TextField).last, pin);
  await tester.tap(find.text('Tamam'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a PIN is set twice, then changing it needs the old one', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()]);
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const SettingsScreen()));
    await tester.tap(find.text('Tercihler'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('PIN belirle'), 200, scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(find.text('PIN belirle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PIN belirle'));
    await tester.pumpAndSettle();

    await _enter(tester, '4321');
    await _enter(tester, '1111');
    expect(find.text('PIN\'ler aynı değil'), findsOneWidget);
    await _enter(tester, '4321');
    expect(lib.pin, '4321');
    expect(h.state.parental.locked, isTrue);
    expect(find.text('Kilitli: yetişkin içerik gizli.'), findsOneWidget);

    await tester.ensureVisible(find.text('PIN\'i kaldır'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('PIN\'i kaldır'));
    await tester.pumpAndSettle();
    await _enter(tester, '0000');
    expect(find.text('PIN yanlış'), findsOneWidget);
    await _enter(tester, '4321');
    expect(lib.pin, isNull);
    expect(h.state.parental.pinSet, isFalse);
  });

  testWidgets('the rail offers locked categories and the PIN opens them', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()])
      ..pin = '2580'
      ..locked = true
      ..adultCategories = 2;
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const LiveScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Kilitli kategoriler'), findsOneWidget);
    final version = h.state.catalogVersion;

    await tester.tap(find.text('Kilitli kategoriler'));
    await tester.pumpAndSettle();
    await _enter(tester, '1234');
    expect(find.text('PIN yanlış'), findsOneWidget);
    await _enter(tester, '2580');
    expect(h.state.parental.locked, isFalse);
    expect(h.state.catalogVersion, greaterThan(version), reason: 'lists reload with adult content');
    expect(find.text('Kilitli kategoriler'), findsNothing);
  });
}
