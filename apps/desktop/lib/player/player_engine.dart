import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/widgets.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import 'media_track.dart';

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
  /// Audio and subtitle tracks of the current stream, re-sent whenever the
  /// list or the selection changes.
  Stream<List<MediaTrack>> get tracks;
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
  /// Selects track [id] of [kind]; null turns subtitles off.
  Future<void> selectTrack(TrackKind kind, String? id);
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
    // media_kit's track model drops forced/SDH/selected; read mpv's own
    // list whenever media_kit says something changed.
    _player.stream.tracks.listen((_) => _refreshTracks());
    _player.stream.track.listen((_) => _refreshTracks());
  }

  final _tracks = StreamController<List<MediaTrack>>.broadcast();

  Future<void> _refreshTracks() async {
    final json = await _native.getProperty('track-list').catchError((_) => '');
    if (!_tracks.isClosed) _tracks.add(MediaTrack.parseTrackList(json));
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
    final size = _textureSize();
    final video = VideoController(
      player,
      configuration: VideoControllerConfiguration(hwdec: 'auto-safe', width: size?.$1, height: size?.$2),
    );
    return MediaKitEngine._(player, video, silent: silent);
  }

  /// A fixed video texture, the size of the screen. media_kit otherwise
  /// re-creates the texture whenever the stream's resolution changes
  /// (1080p -> 4K on a zap), and that path leaks a texture per change, leaks
  /// an mpv node per frame (video-out-params is never freed) and races the
  /// raster thread into a fail-fast crash. With a fixed size mpv scales the
  /// picture into the same texture and none of that code runs.
  /// `KP_DYNAMIC_TEXTURE=1` restores the old behaviour for comparison runs.
  static (int, int)? _textureSize() {
    if (Platform.environment['KP_DYNAMIC_TEXTURE'] == '1') return null;
    final displays = PlatformDispatcher.instance.displays;
    final screen = displays.isEmpty ? const Size(1920, 1080) : displays.first.size;
    int even(double v, int lo, int hi) => (v.round().clamp(lo, hi) ~/ 2) * 2;
    return (even(screen.width, 1280, 3840), even(screen.height, 720, 2160));
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
  Stream<List<MediaTrack>> get tracks => _tracks.stream;
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
  Future<void> selectTrack(TrackKind kind, String? id) async {
    await _native.setProperty(kind == TrackKind.audio ? 'aid' : 'sid', id ?? 'no');
    await _refreshTracks();
  }

  @override
  Future<void> dispose() async {
    await _tracks.close();
    await _player.dispose();
  }
}
