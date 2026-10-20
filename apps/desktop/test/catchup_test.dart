// Catch-up: replaying past programmes of live channels. Headless.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/design/widgets/kd_controls.dart' show kdDay;
import 'package:karadelik_player/player/player_controller.dart';
import 'package:karadelik_player/screens/guide_screen.dart';
import 'package:karadelik_player/screens/live_screen.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

int get _now => DateTime.now().millisecondsSinceEpoch ~/ 1000;

Programme _show(String title, int start, int stop, {bool archive = true}) =>
    Programme(start: start, stop: stop, title: title, description: '', archive: archive);

void main() {
  final trt = FakeLibrary.item(10, 'TRT 1', catchup: true);

  test('a replay opens the archive URL, seekable, and never reconnects', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      final news = _show('Ana Haber', 1000, 2800);
      h.player.play(trt, Kind.live, queue: [trt], programme: news);
      clock.flushMicrotasks();

      expect(h.library.caughtUp, [(10, 1000)]);
      expect(h.library.played, isEmpty, reason: 'no live playback lookup');
      expect(h.engine.opened.single, 'http://127.0.0.1/timeshift/10/1000.ts');
      final n = h.player.now!;
      expect((n.isLive, n.isCatchup, n.title), (false, true, 'TRT 1 · Ana Haber'));

      // The end of a recording is the end, not a dropped live stream.
      h.engine.completedCtl.add(true);
      h.engine.bufferingCtl.add(true);
      clock.elapse(const Duration(seconds: 30));
      expect(h.player.reconnecting, isFalse);
      expect(h.engine.opened, hasLength(1));
    });
  });

  test('back to live leaves the replay for the live stream', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      h.player.play(trt, Kind.live, queue: [trt], programme: _show('Ana Haber', 1000, 2800));
      clock.flushMicrotasks();
      h.player.backToLive();
      clock.flushMicrotasks();

      expect(h.library.played, [10]);
      expect(h.engine.opened.last, 'http://127.0.0.1/10.ts');
      expect((h.player.now!.isLive, h.player.now!.isCatchup), (true, false));
    });
  });

  test('the EPG cache merges the archive and lists it newest first', () {
    fakeAsync((clock) {
      final t = _now;
      final lib = FakeLibrary()
        ..past[10] = [
          _show('Dizi', t - 3600, t - 1800),
          _show('Sabah', t - 7200, t - 3600),
        ];
      final h = TestHarness(lib);
      h.epg.want(10);
      clock.flushMicrotasks();
      expect(h.epg.hasArchive(10), isFalse, reason: 'rows ask for now/next only');

      h.epg.want(10, archive: true);
      clock.flushMicrotasks();
      expect(h.epg.hasArchive(10), isTrue);
      expect(h.epg.archive(10).map((p) => p.title), ['Dizi', 'Sabah']);
    });
  });

  testWidgets('the live preview lists past programmes and a click replays one', (tester) async {
    await setLargeWindow(tester);
    final t = _now;
    final lib = FakeLibrary(sources: [FakeLibrary.source()])
      ..cats[Kind.live] = const [Category(uid: 1, name: 'TR: Ulusal', adult: false, count: 1)]
      ..items[Kind.live] = [trt]
      ..past[10] = [_show('Ana Haber', t - 3600, t - 1800), _show('Sabah Kuşağı', t - 7200, t - 3600)];
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const LiveScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('TRT 1'));
    await tester.pump(const Duration(milliseconds: 400));
    // The archive request queues behind the row's now/next request.
    await tester.pump();
    await tester.pump();
    expect(find.text('GEÇMİŞ YAYINLAR'), findsOneWidget, reason: 'Turkish uppercase: İ, not I');
    expect(find.text(kdDay(t - 3600)), findsOneWidget);
    expect(find.text('2 program'), findsOneWidget);

    await tester.tap(find.text('Ana Haber'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(lib.caughtUp, [(10, t - 3600)]);
    expect(h.player.view, PlayerView.full);
    expect(h.player.now!.isCatchup, isTrue);
  });

  testWidgets('going back in the guide shows the archive and a past tile replays', (tester) async {
    await setLargeWindow(tester);
    final t = _now;
    final window = t - t % 1800 - 1800; // what the guide opens on
    final lib = FakeLibrary(sources: [FakeLibrary.source()])
      ..cats[Kind.live] = const [Category(uid: 1, name: 'TR: Ulusal', adult: false, count: 1)]
      ..items[Kind.live] = [trt]
      ..past[10] = [_show('Gece Haberleri', window - 5400, window - 3600)];
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const GuideScreen()));
    await tester.pump();
    await tester.pump();
    expect(find.text('Gece Haberleri'), findsNothing, reason: 'the archive is fetched only when looking back');

    await tester.tap(find.text('Önceki'));
    await tester.pump();
    await tester.pump();
    await tester.pump();
    expect(find.text('Gece Haberleri'), findsOneWidget);

    await tester.tap(find.text('Gece Haberleri'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(lib.caughtUp, [(10, window - 5400)]);
    expect(h.player.now!.isCatchup, isTrue);
  });
}
