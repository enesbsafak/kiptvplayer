// The statistics panel's reading of a sample: what "why is it stuttering"
// answers for typical cases, without a player.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/player/playback_stats.dart';
import 'package:karadelik_player/player/player_controller.dart';
import 'package:karadelik_player/player/stats_panel.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

void main() {
  const smooth = PlaybackStats(videoBitrate: 4000000, inputRate: 600000, cacheSeconds: 8, hwdec: 'd3d11va');

  test('a smooth stream reads healthy', () {
    expect(diagnose(smooth, previous: smooth), [Finding.healthy]);
  });

  test('a starved live stream is the network, not the decoder', () {
    const starved = PlaybackStats(videoBitrate: 6000000, inputRate: 400000, cacheSeconds: 0.6);
    expect(diagnose(starved), [Finding.slowNetwork]);
    expect(diagnose(starved, live: false), [Finding.cacheLow], reason: 'files read ahead as fast as they can');
  });

  test('dropping frames on software decoding points at the decoder', () {
    const later = PlaybackStats(videoBitrate: 4000000, inputRate: 600000, cacheSeconds: 8, hwdec: 'no', decoderDrops: 9);
    const before = PlaybackStats(hwdec: 'no', decoderDrops: 1);
    expect(diagnose(later, previous: before), [Finding.framesDropping, Finding.softwareDecoding]);
  });

  test('the provider check comes first: down, expired, full', () {
    const down = SourceHealth(ok: false, latencyMs: 10000, error: 'timeout');
    expect(diagnose(smooth, health: down).first, Finding.sourceDown);
    const full = SourceHealth(ok: true, latencyMs: 90, expiresAt: 100, maxConnections: 1, activeConnections: 1);
    expect(diagnose(smooth, health: full, nowUnix: 200), [Finding.accountExpired, Finding.connectionLimit]);
    expect(diagnose(smooth, reconnects: 2), [Finding.reconnected]);
  });

  testWidgets('the panel shows the numbers and checks the provider', (tester) async {
    await setLargeWindow(tester);
    final library = FakeLibrary(sources: [FakeLibrary.source()]);
    final h = TestHarness(library);
    await h.state.load();
    h.engine.nextStats = const PlaybackStats(
      videoCodec: 'h264', width: 1920, height: 1080, fps: 25, hwdec: 'd3d11va', videoBitrate: 4200000, cacheSeconds: 3.5,
    );
    final trt = FakeLibrary.item(10, 'TRT 1');
    h.player.play(trt, Kind.live, queue: [trt], view: PlayerView.preview);
    await tester.pumpWidget(app(h, StatsPanel(player: h.player, onClose: () {})));
    await tester.pump();
    await tester.pump();
    expect(library.checked, ['s1'], reason: 'checked once on opening');
    expect(find.text('H264 · 1920×1080 · 25 fps'), findsOneWidget);
    expect(find.text('4,2 Mbit/s'), findsOneWidget);
    expect(find.text('3,5 s'), findsOneWidget);
    expect(find.text('Şu an bir sorun görünmüyor.'), findsOneWidget);

    library.health = const SourceHealth(ok: true, latencyMs: 120, maxConnections: 1, activeConnections: 1);
    await tester.tap(find.text('Sağlayıcıyı kontrol et'));
    await tester.pump();
    expect(library.checked, ['s1', 's1']);
    expect(find.text('Bağlantı 1/1'), findsOneWidget);
    expect(find.textContaining('Bağlantı sınırı dolu'), findsOneWidget);
    expect(find.text('Sunucu yanıt verdi · 120 ms'), findsOneWidget);
    await tester.pumpWidget(const SizedBox()); // stops the sampling timer
  });
}
