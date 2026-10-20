// Live-stream recovery, on a virtual clock: no window, no real waiting.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/player/player_controller.dart';

import 'fakes.dart';

void main() {
  final trt = FakeLibrary.item(10, 'TRT 1');
  final kanalD = FakeLibrary.item(11, 'Kanal D');

  test('a live stream stalled for 10 s is reopened', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      h.player.play(trt, Kind.live, queue: [trt, kanalD], view: PlayerView.preview);
      clock.flushMicrotasks();
      expect(h.engine.opened, hasLength(1));

      h.engine.bufferingCtl.add(true);
      clock.elapse(const Duration(seconds: 9));
      expect(h.player.reconnecting, isFalse, reason: 'short buffering is normal');

      clock.elapse(const Duration(milliseconds: 1500)); // 10.5 s: stall detected
      expect(h.player.reconnecting, isTrue);
      expect(h.player.reconnectReason, 'Yayın takıldı');

      clock.elapse(const Duration(seconds: 1)); // first retry 1 s after detection
      clock.flushMicrotasks();
      expect(h.engine.opened, hasLength(2));
      expect(h.player.reconnecting, isFalse, reason: 'picture came back');
      expect(h.player.reconnectAttempt, 0);
    });
  });

  test('failed reopens back off 1, 2, 4 s and recover', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      h.engine.failNextOpens = 3; // initial open + two retries fail
      h.player.play(trt, Kind.live, queue: [trt], view: PlayerView.full);
      clock.flushMicrotasks();
      expect(h.player.reconnectAttempt, 1);

      clock.elapse(const Duration(seconds: 1));
      clock.flushMicrotasks();
      expect(h.player.reconnectAttempt, 2);

      clock.elapse(const Duration(seconds: 1));
      clock.flushMicrotasks();
      expect(h.engine.opened, hasLength(2), reason: 'second wait is 2 s, not 1 s');

      clock.elapse(const Duration(seconds: 1));
      clock.flushMicrotasks();
      expect(h.engine.opened, hasLength(3));
      expect(h.player.reconnectAttempt, 3);

      clock.elapse(const Duration(seconds: 4));
      clock.flushMicrotasks();
      expect(h.engine.opened, hasLength(4));
      expect(h.player.reconnecting, isFalse);
    });
  });

  test('a dropped live stream (end of file) triggers recovery', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      h.player.play(trt, Kind.live, queue: [trt], view: PlayerView.full);
      clock.flushMicrotasks();
      h.engine.completedCtl.add(true);
      clock.flushMicrotasks();
      expect(h.player.reconnectReason, 'Yayın kesildi');
    });
  });

  test('zapping away cancels a pending retry', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      h.engine.failNextOpens = 1;
      h.player.play(trt, Kind.live, queue: [trt, kanalD], view: PlayerView.full);
      clock.flushMicrotasks();
      expect(h.player.reconnecting, isTrue);

      h.player.play(kanalD, Kind.live, queue: [trt, kanalD], view: PlayerView.full);
      clock.flushMicrotasks();
      expect(h.player.reconnecting, isFalse);
      clock.elapse(const Duration(seconds: 40));
      expect(h.engine.opened.where((u) => u.endsWith('/10.ts')), hasLength(1), reason: 'TRT 1 never reopened');
    });
  });

  test('VOD errors are shown, not retried', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      h.engine.failNextOpens = 1;
      h.player.play(FakeLibrary.item(50, 'Film'), Kind.movie, view: PlayerView.full);
      clock.flushMicrotasks();
      expect(h.player.reconnecting, isFalse);
      expect(h.player.error, 'Yayından görüntü gelmedi');
      clock.elapse(const Duration(seconds: 40));
      expect(h.engine.opened, hasLength(1));
    });
  });
}
