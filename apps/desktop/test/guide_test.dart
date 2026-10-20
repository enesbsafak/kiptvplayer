// XMLTV guides of M3U sources: status line, refresh, background updates.

import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/screens/settings_screen.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

int get _now => DateTime.now().millisecondsSinceEpoch ~/ 1000;

GuideInfo _ok({int matched = 118, int at = 0}) => GuideInfo(
  ok: true,
  programmes: BigInt.from(19200),
  matched: BigInt.from(matched),
  channels: BigInt.from(120),
  at: at == 0 ? _now - 3 * 3600 : at,
);

void main() {
  testWidgets('settings tell how the guide is doing and can refresh it', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source(m3u: true, guide: _ok())])
      ..nextGuide = GuideInfo(
        ok: false,
        programmes: BigInt.zero,
        matched: BigInt.zero,
        channels: BigInt.zero,
        error: 'Yayın akışı indirilemedi: HTTP 404',
        at: _now,
      );
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const SettingsScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Yayın akışı: 118/120 kanal eşleşti · 19 bin program · 3 sa önce'), findsOneWidget);

    await tester.tap(find.text('Yayın akışı'));
    await tester.pumpAndSettle();
    expect(lib.guideRefreshes, ['s1']);
    expect(find.text('Yayın akışı alınamadı: Yayın akışı indirilemedi: HTTP 404'), findsOneWidget);
  });

  test('a stale guide is refreshed in the background at start, a fresh one is not', () async {
    final stale = FakeLibrary(sources: [FakeLibrary.source(m3u: true, guide: _ok(at: _now - 13 * 3600))])..nextGuide = _ok();
    final h = TestHarness(stale);
    await h.state.load();
    await pumpEventQueue();
    expect(stale.guideRefreshes, ['s1']);
    expect(h.state.guideVersion, 1, reason: 'cached now/next is dropped');

    final fresh = FakeLibrary(sources: [FakeLibrary.source(m3u: true, guide: _ok())]);
    await TestHarness(fresh).state.load();
    await pumpEventQueue();
    expect(fresh.guideRefreshes, isEmpty);

    final xtream = FakeLibrary(sources: [FakeLibrary.source()]);
    await TestHarness(xtream).state.load();
    await pumpEventQueue();
    expect(xtream.guideRefreshes, isEmpty, reason: 'Xtream has its own EPG');
  });
}
