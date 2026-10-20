// Windows media controls: what the flyout is told, what its buttons do.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/player/media_session.dart';
import 'package:karadelik_player/player/player_controller.dart';

import 'fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('karadelik/media-test');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  Future<void> press(String button) async {
    final completer = messenger.handlePlatformMessage(
      channel.name,
      const StandardMethodCodec().encodeMethodCall(MethodCall('button', button)),
      (_) {},
    );
    await completer;
    await pumpEventQueue();
  }

  test('tells Windows what plays, only when it changes, and obeys its buttons', () async {
    final sent = <Map<Object?, Object?>>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'update') sent.add(call.arguments as Map<Object?, Object?>);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));

    final h = TestHarness(FakeLibrary());
    MediaSession(h.player, channel: channel);
    final trt = FakeLibrary.item(10, 'TRT 1');
    final kanalD = FakeLibrary.item(11, 'Kanal D');
    await h.player.play(trt, Kind.live, queue: [trt, kanalD], view: PlayerView.preview);
    h.engine.playingCtl.add(true);
    await pumpEventQueue();
    expect(sent.last, {'status': 'playing', 'title': 'TRT 1', 'subtitle': 'Canlı yayın', 'art': ''});
    final count = sent.length;
    h.player.position.value = const Duration(seconds: 5);
    h.engine.bufferingCtl.add(false);
    await pumpEventQueue();
    expect(sent.length, count, reason: 'no update without a visible change');

    await press('next');
    expect(h.player.now!.item.id, 11, reason: 'next = next channel on live TV');
    await press('previous');
    expect(h.player.now!.item.id, 10);

    await press('pause');
    expect(h.engine.toggles, 1);
    await press('pause');
    expect(h.engine.toggles, 2, reason: 'player still reports playing in the fake');
    h.engine.playingCtl.add(false);
    await pumpEventQueue();
    expect(sent.last['status'], 'paused');
    await press('play');
    expect(h.engine.toggles, 3);

    await press('stop');
    expect(h.player.now, isNull);
    expect(sent.last['status'], 'closed');
  });
}
