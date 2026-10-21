// Player adjustments (delays, size, aspect, speed) and the sleep timer, on
// a virtual clock with the fake engine.

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/player/player_controller.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // stop() talks to the window plugin
  final trt = FakeLibrary.item(10, 'TRT 1');
  final kanalD = FakeLibrary.item(11, 'Kanal D');
  final film = FakeLibrary.item(50, 'Film');

  test('delays reset on the next stream, size and aspect stay', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      h.player.play(trt, Kind.live, queue: [trt, kanalD], view: PlayerView.full);
      clock.flushMicrotasks();

      h.player.nudgeSubtitleDelay(0.1);
      h.player.nudgeSubtitleDelay(0.1);
      h.player.nudgeAudioDelay(-0.1);
      h.player.setSubtitleScale(1.25);
      h.player.setAspect('4:3');
      clock.flushMicrotasks();
      expect(h.player.subtitleDelay, 0.2, reason: 'no float drift after two nudges');
      expect(h.engine.adjustments, containsPair('subDelay', 0.2));
      expect(h.engine.adjustments, containsPair('audioDelay', -0.1));

      h.player.zap(1);
      clock.flushMicrotasks();
      expect(h.player.subtitleDelay, 0);
      expect(h.engine.adjustments, containsPair('subDelay', 0.0));
      expect(h.engine.adjustments, containsPair('audioDelay', 0.0));
      expect(h.engine.adjustments, containsPair('subScale', 1.25));
      expect(h.engine.adjustments, containsPair('aspect', '4:3'));
    });
  });

  test('speed changes files only; live plays at 1x', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      h.player.play(film, Kind.movie, view: PlayerView.full);
      clock.flushMicrotasks();
      h.player.setSpeed(1.5);
      clock.flushMicrotasks();
      expect(h.engine.adjustments, containsPair('speed', 1.5));

      h.player.play(trt, Kind.live, queue: [trt], view: PlayerView.full);
      clock.flushMicrotasks();
      expect(h.engine.adjustments, containsPair('speed', 1.0));
      h.player.setSpeed(2);
      clock.flushMicrotasks();
      expect(h.player.speed, 1, reason: 'live ignores speed');
    });
  });

  test('the sleep timer stops playback, and can be switched off', () {
    fakeAsync((clock) {
      final h = TestHarness(FakeLibrary());
      h.player.play(trt, Kind.live, queue: [trt], view: PlayerView.full);
      clock.flushMicrotasks();

      h.player.setSleepTimer(const Duration(minutes: 15));
      h.player.setSleepTimer(null);
      clock.elapse(const Duration(minutes: 16));
      expect(h.engine.stops, 0, reason: 'switched off');

      h.player.setSleepTimer(const Duration(minutes: 30));
      expect(h.player.sleepAt, isNotNull);
      clock.elapse(const Duration(minutes: 29));
      expect(h.engine.stops, 0);
      clock.elapse(const Duration(minutes: 2));
      // stop() goes on to leave full screen through the window plugin, which
      // never answers on a virtual clock: the engine stopping is the point.
      expect(h.engine.stops, 1);
      expect(h.player.sleepAt, isNull);
    });
  });
}
