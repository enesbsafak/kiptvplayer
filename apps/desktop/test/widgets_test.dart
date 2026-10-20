// Headless UI tests: no window, no mpv, no Rust. Run with `flutter test`.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/app_state.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/design/theme.dart';
import 'package:karadelik_player/screens/add_source.dart';
import 'package:karadelik_player/screens/live_screen.dart';
import 'package:karadelik_player/screens/settings_screen.dart';
import 'package:karadelik_player/shell/app_shell.dart';

import 'fakes.dart';

Widget app(TestHarness h, Widget child) =>
    h.wrap(MaterialApp(theme: buildKdTheme(), home: Scaffold(body: child)));

Future<void> setLargeWindow(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('first run shows onboarding and validates the Xtream form', (tester) async {
    await setLargeWindow(tester);
    final h = TestHarness(FakeLibrary());
    await h.state.load();
    await tester.pumpWidget(app(h, const AppShell()));
    await tester.pump();

    expect(find.text('Başlamak için bir kaynak ekleyin.'), findsOneWidget);
    expect(find.textContaining('kanal, film veya yayın sağlamaz'), findsOneWidget);

    await tester.tap(find.text('Bağlan ve eşitle'));
    await tester.pump();
    expect(find.text('Sunucu adresini girin'), findsOneWidget);
    expect(h.library.added, isEmpty, reason: 'nothing is sent with an empty form');
  });

  testWidgets('adding a source streams progress and ends on a summary', (tester) async {
    await setLargeWindow(tester);
    final h = TestHarness(FakeLibrary());
    await h.state.load();
    await tester.pumpWidget(app(h, const AddSourceForm()));

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'http://127.0.0.1:8089');
    await tester.enterText(fields.at(2), 'demo');
    await tester.enterText(fields.at(3), 'demo');
    await tester.tap(find.text('Bağlan ve eşitle'));
    await tester.pumpAndSettle();

    expect(h.library.added.single.username, 'demo');
    expect(h.library.added.single.isXtream, isTrue);
    expect(find.textContaining('hazır'), findsOneWidget);
    expect(find.text('canlı kanal'), findsOneWidget);
  });

  testWidgets('a failed add shows the provider message and keeps the form', (tester) async {
    await setLargeWindow(tester);
    final h = TestHarness(FakeLibrary(addResult: const [SyncEvent.failed(message: 'kullanıcı adı veya şifre reddedildi')]));
    await h.state.load();
    await tester.pumpWidget(app(h, const AddSourceForm()));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(1), 'http://x');
    await tester.enterText(fields.at(2), 'u');
    await tester.enterText(fields.at(3), 'p');
    await tester.tap(find.text('Bağlan ve eşitle'));
    await tester.pumpAndSettle();
    expect(find.text('kullanıcı adı veya şifre reddedildi'), findsOneWidget);
    expect(find.text('Bağlan ve eşitle'), findsOneWidget);
  });

  testWidgets('sidebar navigation highlights the active section', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()]);
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const AppShell()));
    await tester.pump();

    await tester.tap(find.text('Ayarlar').first);
    await tester.pumpAndSettle();
    expect(h.state.section, Section.settings);
    expect(find.text('Kaynaklar'), findsWidgets);
  });

  testWidgets('live screen lists categories as the provider gave them and plays on click', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()])
      ..cats[Kind.live] = const [
        Category(uid: 1, name: 'TR: Ulusal', adult: false, count: 2),
        Category(uid: 2, name: 'DE: Sport', adult: false, count: 1),
      ]
      ..items[Kind.live] = [FakeLibrary.item(10, 'TRT 1'), FakeLibrary.item(11, 'Kanal D'), FakeLibrary.item(12, 'Sport 1')];
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const LiveScreen()));
    await tester.pumpAndSettle();

    expect(find.text('TR: Ulusal'), findsOneWidget);
    expect(find.text('DE: Sport'), findsOneWidget);
    expect(find.text('TRT 1'), findsOneWidget);

    // A single click previews in place (no full-screen player).
    h.player.addListener(() {});
    await tester.tap(find.text('Kanal D'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(lib.played, [11]);
    expect(h.engine.opened.single, 'http://127.0.0.1/11.ts');
  });

  testWidgets('region preference can be switched off and on', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()]);
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const SettingsScreen()));
    await tester.tap(find.text('Tercihler'));
    await tester.pumpAndSettle();

    expect(find.text('Türkiye'), findsOneWidget);
    await tester.tap(find.text('Kapalı'));
    await tester.pumpAndSettle();
    expect(lib.region, isNull);
    expect(h.state.region, isNull);

    await tester.tap(find.text('Almanya'));
    await tester.pumpAndSettle();
    expect(lib.region, 'DE');
  });

  testWidgets('first launch takes the region from the OS locale', (tester) async {
    final lib = FakeLibrary()..regionChosen = false;
    final h = TestHarness(lib);
    await h.state.load();
    expect(lib.regionChosen, isTrue, reason: 'the choice is stored once');
  });
}
