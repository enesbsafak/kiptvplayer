// Local timeshift: live channels open with the disk buffer, seeking stays
// inside it, "Canlıya dön" goes back to the edge; the size is a setting.

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/player/player_controller.dart';
import 'package:karadelik_player/screens/settings_screen.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

void main() {
  final trt = FakeLibrary.item(10, 'TRT 1');
  final film = FakeLibrary.item(50, 'Film');
  Duration s(int seconds) => Duration(seconds: seconds);

  test('only live channels open with the buffer', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      h.player.configureTimeshift(2048);
      h.player.play(trt, Kind.live, queue: [trt], view: PlayerView.full);
      clock.flushMicrotasks();
      h.player.play(film, Kind.movie, view: PlayerView.full);
      clock.flushMicrotasks();
      final past = Programme(start: 1000, stop: 2000, title: 'Dün', description: '', archive: true);
      h.player.play(trt, Kind.live, queue: [trt], programme: past, view: PlayerView.full);
      clock.flushMicrotasks();
      expect(h.engine.openedLive, [true, false, false]);
      expect(h.engine.timeshiftMb, 2048);
    });
  });

  test('seeking on live stays inside the buffer, a second from the edge', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      h.player.play(trt, Kind.live, queue: [trt], view: PlayerView.full);
      clock.flushMicrotasks();
      h.engine.range = (s(100), s(400));
      h.player.position.value = s(395);

      h.player.seekBy(s(-10));
      clock.flushMicrotasks();
      expect(h.engine.seeks, isEmpty, reason: 'timeshift off: live does not seek');

      h.player.configureTimeshift(1024);
      h.player.seekBy(s(10));
      h.player.seekBy(s(-500));
      h.player.seekTo(s(250));
      clock.flushMicrotasks();
      expect(h.engine.seeks, [s(399), s(100), s(250)]);

      h.engine.playingCtl.add(false);
      clock.flushMicrotasks();
      h.player.goLive();
      clock.flushMicrotasks();
      expect(h.engine.seeks.last, s(399));
      expect(h.engine.toggles, 1, reason: 'paused: plays again');
    });
  });

  testWidgets('the timeshift size is a preference', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()]);
    final h = TestHarness(lib);
    await h.state.load();
    h.player.configureTimeshift(2048);
    await tester.pumpWidget(app(h, const SettingsScreen()));
    await tester.tap(find.text('Tercihler'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('1 GB'), 200, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('1 GB'));
    await tester.pump();
    expect(lib.appSettings['timeshift_mb'], '1024');
    expect(h.engine.timeshiftMb, 1024);
  });
}
