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

  test('after two failed reopens the backup streams are tried, then the original', () {
    fakeAsync((clock) {
      final trtBackup = FakeLibrary.item(20, 'TRT 1 Yedek');
      final lib = FakeLibrary()..backups[10] = [trtBackup];
      final h = TestHarness(lib);
      h.engine.failNextOpens = 3; // the original and its first two reopens
      h.player.play(trt, Kind.live, queue: [trt, kanalD], view: PlayerView.full);
      clock.flushMicrotasks();
      // Waits of 1 and 2 s: reopens 1 and 2 retry the chosen stream.
      clock.elapse(const Duration(seconds: 3));
      clock.flushMicrotasks();
      expect(h.engine.opened, List.filled(3, 'http://127.0.0.1/10.ts'));
      expect(h.player.backupName, isNull);

      clock.elapse(const Duration(seconds: 4)); // reopen 3: the backup
      clock.flushMicrotasks();
      expect(h.engine.opened.last, 'http://127.0.0.1/20.ts');
      expect(h.player.reconnecting, isFalse, reason: 'the backup plays');
      expect(h.player.backupName, 'TRT 1 Yedek');
      expect(h.player.now!.queue.map((c) => c.id), [10, 11], reason: 'zapping still uses the list');
    });
  });

  test('a channel without backups keeps retrying itself', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      h.engine.failNextOpens = 4;
      h.player.play(trt, Kind.live, queue: [trt], view: PlayerView.full);
      clock.elapse(const Duration(seconds: 20));
      clock.flushMicrotasks();
      expect(h.engine.opened.toSet(), {'http://127.0.0.1/10.ts'});
    });
  });

  test('typed digits tune to that channel number after a pause', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      final list = [for (var i = 1; i <= 15; i++) FakeLibrary.item(100 + i, 'Kanal $i')];
      h.player.play(list[0], Kind.live, queue: list, view: PlayerView.full);
      clock.flushMicrotasks();
      h.player.typeDigit(1);
      h.player.typeDigit(2);
      expect(h.player.zapDigits, '12');
      clock.elapse(const Duration(milliseconds: 1000));
      expect(h.player.now!.item.id, 101, reason: 'still waiting for more digits');
      clock.elapse(const Duration(milliseconds: 600));
      clock.flushMicrotasks();
      expect(h.player.now!.item.id, 112);
      expect(h.player.zapDigits, isEmpty);

      h.player.typeDigit(9);
      h.player.typeDigit(9);
      h.player.commitDigits(); // Enter: no waiting; 99 is past the list
      clock.flushMicrotasks();
      expect(h.player.now!.item.id, 112);
    });
  });
}
