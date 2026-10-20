import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// Playback behind one narrow interface, so media_kit can be swapped for a
/// direct libmpv render-API binding without touching screens.
abstract interface class PlayerEngine {
  /// The video picture, sized by its parent; letterboxed on black.
  Widget surface();
  Stream<bool> get buffering;
  Stream<bool> get playing;
  /// True when the current file reached its end (for live: the stream died).
  Stream<bool> get completed;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<Tracks> get tracks;
  Stream<Track> get track;
  Stream<String> get errors;
  Stream<int?> get videoHeight;

  /// Opens [url]; the returned future completes when the first frame of the
  /// new stream is on screen.
  Future<Duration> open(
    String url, {
    Map<String, String> headers,
    Duration? start,
  });
  Future<void> stop();
  Future<void> togglePause();
  Future<void> seek(Duration to);
  Future<void> setVolume(double percent);
  Future<void> setAudioTrack(AudioTrack track);
  Future<void> setSubtitleTrack(SubtitleTrack track);
  Future<void> dispose();
}

/// mpv options for live IPTV, carried over from AbiPlayer's tuned launch
/// arguments (`mpv-controller.ts` buildLaunchArgs) plus faster stream opening.
const _liveOptions = <String, String>{
  'network-timeout': '30',
  'stream-lavf-o':
      'reconnect=1,reconnect_streamed=1,reconnect_delay_max=5,reconnect_on_network_error=1',
  'demuxer-max-bytes': '150MiB',
  'demuxer-max-back-bytes': '50MiB',
  'cache': 'yes',
  'cache-secs': '30',
  'cache-pause-initial': 'no',
  // Live TS/HLS rarely needs mpv's full probe; a smaller probe starts faster.
  'demuxer-lavf-probesize': '1000000',
  'demuxer-lavf-analyzeduration': '1',
  'keep-open': 'yes',
  'sub-font-size': '42',
  'sub-border-size': '2',
};

class MediaKitEngine implements PlayerEngine {
  MediaKitEngine._(this._player, this.video, {required bool silent}) {
    ready = _applyOptions(silent: silent);
  }

  final Player _player;
  final VideoController video;

  @override
  Widget surface() => Video(controller: video, controls: NoVideoControls, fill: const Color(0xFF000000));

  /// Completes once mpv is configured and the video surface exists.
  late final Future<void> ready;

  /// Creates the player and its video surface at launch, so the first channel
  /// click does not pay for mpv start-up (AbiPlayer spawned mpv on demand).
  ///
  /// Returns immediately and warms up in the background: the video texture
  /// can only be created once Flutter has a view, and the runner shows the
  /// window only after Flutter's first frame, so awaiting it before runApp
  /// deadlocks.
  ///
  /// [silent] is for automated runs: no audio device is opened at all.
  factory MediaKitEngine.warmUp({bool silent = false}) {
    final player = Player(
      configuration: PlayerConfiguration(
        title: 'Karadelik IPTV Player',
        logLevel: MPVLogLevel.warn,
        bufferSize: 64 * 1024 * 1024,
        muted: silent,
      ),
    );
    final video = VideoController(
      player,
      configuration: const VideoControllerConfiguration(hwdec: 'auto-safe'),
    );
    return MediaKitEngine._(player, video, silent: silent);
  }

  Future<void> _applyOptions({required bool silent}) async {
    // Set before any file loads, so an audio device is never even opened.
    if (silent) await _native.setProperty('ao', 'null');
    for (final e in _liveOptions.entries) {
      await _native.setProperty(e.key, e.value);
    }
    await video.platform.future;
  }

  NativePlayer get _native => _player.platform as NativePlayer;

  @override
  Stream<bool> get buffering => _player.stream.buffering;
  @override
  Stream<bool> get playing => _player.stream.playing;
  @override
  Stream<bool> get completed => _player.stream.completed;
  @override
  Stream<Duration> get position => _player.stream.position;
  @override
  Stream<Duration> get duration => _player.stream.duration;
  @override
  Stream<Tracks> get tracks => _player.stream.tracks;
  @override
  Stream<Track> get track => _player.stream.track;
  @override
  Stream<String> get errors => _player.stream.error;
  @override
  Stream<int?> get videoHeight => _player.stream.height;

  Completer<void>? _firstFrame;

  @override
  Future<Duration> open(
    String url, {
    Map<String, String> headers = const {},
    Duration? start,
  }) async {
    final sw = Stopwatch()..start();
    await ready;
    // A zap before the previous stream showed a frame releases its waiter.
    final previous = _firstFrame;
    if (previous != null && !previous.isCompleted) previous.complete();
    final firstFrame = _firstFrame = Completer<void>();

    // time-pos turns non-empty once the first frame plays. Until loadfile
    // swaps files the *previous* stream keeps reporting time-pos, so a value
    // only counts when mpv's current path is already the new URL.
    await _native.unobserveProperty('time-pos').catchError((_) {});
    await _native.observeProperty('time-pos', (value) async {
      if (value.isEmpty || firstFrame.isCompleted) return;
      final path = await _native.getProperty('path');
      if (path == url && !firstFrame.isCompleted) firstFrame.complete();
    });

    try {
      await _player.open(Media(url, httpHeaders: headers, start: start));
      // No picture in 30 s means the stream is not coming; the caller
      // decides whether to retry.
      await firstFrame.future.timeout(const Duration(seconds: 30));
      sw.stop();
      return sw.elapsed;
    } finally {
      await _native.unobserveProperty('time-pos').catchError((_) {});
    }
  }

  @override
  Future<void> stop() async {
    final pending = _firstFrame;
    if (pending != null && !pending.isCompleted) pending.complete();
    await _player.stop();
  }

  @override
  Future<void> togglePause() => _player.playOrPause();
  @override
  Future<void> seek(Duration to) => _player.seek(to);
  @override
  Future<void> setVolume(double percent) => _player.setVolume(percent);
  @override
  Future<void> setAudioTrack(AudioTrack track) => _player.setAudioTrack(track);
  @override
  Future<void> setSubtitleTrack(SubtitleTrack track) =>
      _player.setSubtitleTrack(track);
  @override
  Future<void> dispose() => _player.dispose();
}
