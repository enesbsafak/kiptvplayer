// App updates: badge, About section, download, install, going back.

import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/updates.dart';
import 'package:karadelik_player/screens/settings_screen.dart';
import 'package:karadelik_player/shell/app_shell.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

void main() {
  testWidgets('an update shows in the title bar, downloads, installs and restarts', (tester) async {
    await setLargeWindow(tester);
    final h = TestHarness(FakeLibrary(sources: [FakeLibrary.source()]))
      ..nextUpdate = const UpdateInfo(version: '0.2.0', notes: 'Hız iyileştirmeleri.')
      ..downloadEvents = const [
        UpdateProgress.downloading(fraction: 0.5),
        UpdateProgress.ready(path: r'C:\updates\KaradelikIPTVPlayer-Setup-0.2.0.exe'),
      ];
    await h.state.load();
    await tester.pumpWidget(app(h, const AppShell()));
    await tester.pumpAndSettle();
    expect(find.text('Güncelleme var'), findsNothing);

    await h.updates.check(quiet: true);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Güncelleme var'));
    await tester.pumpAndSettle();
    expect(find.text('Yeni sürüm hazır: 0.2.0'), findsOneWidget, reason: 'the badge opens Settings › About');
    expect(find.text('Hız iyileştirmeleri.'), findsOneWidget);

    await tester.tap(find.text('İndir'));
    await tester.pumpAndSettle();
    expect(find.text('Güncelleme hazır'), findsOneWidget);
    await tester.tap(find.text('Kur ve yeniden başlat'));
    await tester.pumpAndSettle();
    expect(h.installed, [r'C:\updates\KaradelikIPTVPlayer-Setup-0.2.0.exe']);
    expect(h.quits, 1);
  });

  testWidgets('up to date, a failed check, and going back to the kept version', (tester) async {
    await setLargeWindow(tester);
    final h = TestHarness(FakeLibrary(sources: [FakeLibrary.source()]))..previousRelease = ('0.0.9', r'C:\updates\old.exe');
    await h.state.load();
    await tester.pumpWidget(app(h, const SettingsScreen()));
    await tester.tap(find.text('Hakkında'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Güncellemeleri denetle'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Güncelsiniz'), findsOneWidget);

    await tester.tap(find.text('0.0.9 sürümüne dön'));
    await tester.pumpAndSettle();
    expect(h.installed, [r'C:\updates\old.exe']);
    expect(h.quits, 1);
  });

  test('a background check that fails stays quiet; an asked-for one explains', () async {
    final failing = UpdateService(
      check: () async => throw Exception('offline'),
      download: () => const Stream.empty(),
      install: (_) async {},
      previous: () async => null,
      quit: () async {},
    );
    await failing.check(quiet: true);
    expect(failing.phase, UpdatePhase.idle);
    await failing.check();
    expect((failing.phase, failing.error), (UpdatePhase.failed, 'offline'));
  });
}
