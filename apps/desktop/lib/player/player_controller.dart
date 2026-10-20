import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart' show AudioTrack, SubtitleTrack, Track, Tracks;
import 'package:window_manager/window_manager.dart';

import '../app/library.dart';
import '../perf/perf.dart';
import 'player_engine.dart';

/// What is playing, and the list ↑/↓ zaps through.
class NowPlaying {
  const NowPlaying({
    required this.item,
    required this.kind,
    required this.title,
    required this.isLive,
    this.episode,
    this.programme,
    this.queue = const [],
  });

  final Item item;
  final Kind kind;
  final String title;
  final bool isLive;
  final EpisodeInfo? episode;

  /// A past programme replayed from the provider's archive (catch-up).
  final Programme? programme;
  final List<Item> queue;

  bool get isCatchup => programme != null;
}

enum PlayerView { hidden, preview, full }

class PlayerController extends ChangeNotifier {
  PlayerController(this.engine, this.library, this.perf) {
    _subs = [
      engine.buffering.listen(_onBuffering),
      engine.completed.listen(_onCompleted),
      engine.playing.listen((v) => _set(() => playing = v)),
      engine.position.listen((v) => position.value = v),
      engine.duration.listen((v) => _set(() => duration = v)),
      engine.tracks.listen((v) => _set(() => tracks = v)),
      engine.track.listen((v) => _set(() => track = v)),
      engine.videoHeight.listen((v) => _set(() => videoHeight = v)),
      engine.errors.listen(_onError),
    ];
  }

  final PlayerEngine engine;
  final LibraryApi library;
  final Perf perf;
  late final List<StreamSubscription<Object?>> _subs;

  NowPlaying? now;
  PlayerView view = PlayerView.hidden;
  bool opening = false;
  bool buffering = false;
  bool playing = false;
  Duration duration = Duration.zero;
  final position = ValueNotifier(Duration.zero);
  Tracks tracks = const Tracks();
  Track track = const Track();
  int? videoHeight;
  String? error;
  int? lastZapMs;
  double volume = 100;

  /// Live recovery: set while waiting to reopen a stalled or dropped stream.
  bool reconnecting = false;
  int reconnectAttempt = 0;
  String? reconnectReason;
  DateTime? reconnectAt;

  /// A live stream buffering longer than this is treated as stalled.
  static const stallLimit = Duration(seconds: 10);

  Timer? _progressTimer;
  Timer? _stallTimer;
  Timer? _retryTimer;
  int _openToken = 0;

  void _set(VoidCallback f) {
    f();
    notifyListeners();
  }

  /// Plays [item]. [queue] is what ↑/↓ moves through; [episode] selects a
  /// series episode; [programme] replays a past programme of a live channel.
  Future<void> play(
    Item item,
    Kind kind, {
    List<Item> queue = const [],
    EpisodeInfo? episode,
    Programme? programme,
    PlayerView view = PlayerView.full,
    bool fromStart = false,
    bool retry = false,
  }) async {
    final token = ++_openToken;
    _stallTimer?.cancel();
    _retryTimer?.cancel();
    if (!retry) _clearReconnect();
    await _saveProgress();
    _set(() {
      opening = true;
      error = null;
      this.view = view;
      now = NowPlaying(
        item: item,
        kind: kind,
        title: switch ((episode, programme)) {
          (final e?, _) => '${item.name} · ${e.title}',
          (_, final p?) => '${item.name} · ${p.title}',
          _ => item.name,
        },
        isLive: kind == Kind.live && programme == null,
        episode: episode,
        programme: programme,
        queue: queue,
      );
    });
    try {
      final p = programme != null
          ? await library.catchupPlayback(item.id, start: programme.start, stop: programme.stop)
          : await library.playback(
              item.id,
              episodeId: episode?.extId,
              container: episode?.container,
            );
      if (token != _openToken) return;
      final headers = <String, String>{
        if (p.userAgent != null) 'User-Agent': p.userAgent!,
        if (p.referrer != null) 'Referer': p.referrer!,
      };
      final resume = fromStart ? null : (episode?.progressMs ?? p.resumeMs);
      final took = await engine.open(
        p.url,
        headers: headers,
        start: resume == null ? null : Duration(milliseconds: resume),
      );
      if (token != _openToken) return;
      if (retry) _clearReconnect();
      lastZapMs = took.inMilliseconds;
      perf.record('zap_first_frame', took.inMilliseconds, {'kind': programme != null ? 'catchup' : kind.name});
      _progressTimer?.cancel();
      if (kind != Kind.live) {
        _progressTimer = Timer.periodic(
          const Duration(seconds: 10),
          (_) => _saveProgress(),
        );
      }
    } catch (e) {
      if (token == _openToken) {
        error = e is TimeoutException ? 'Yayından görüntü gelmedi' : '$e';
        _scheduleReconnect(error!);
      }
    } finally {
      if (token == _openToken) _set(() => opening = false);
    }
  }

  void _onBuffering(bool v) {
    buffering = v;
    final live = now?.isLive ?? false;
    if (v && live && !opening) {
      _stallTimer ??= Timer(stallLimit, () {
        _stallTimer = null;
        _scheduleReconnect('Yayın takıldı');
      });
    } else if (!v) {
      _stallTimer?.cancel();
      _stallTimer = null;
    }
    notifyListeners();
  }

  void _onError(String e) {
    error = e;
    if (!opening) _scheduleReconnect('Bağlantı hatası');
    notifyListeners();
  }

  void _onCompleted(bool done) {
    // A live stream has no end: reaching one means the connection dropped.
    if (done && (now?.isLive ?? false) && !opening) _scheduleReconnect('Yayın kesildi');
  }

  /// Reopens the current live stream after 1, 2, 4 … 30 s, without limit,
  /// until it plays again or the user moves on. VOD shows the error instead.
  void _scheduleReconnect(String reason) {
    final n = now;
    if (n == null || !n.isLive || (_retryTimer?.isActive ?? false)) return;
    reconnectAttempt++;
    final delay = Duration(seconds: math.min(30, 1 << math.min(reconnectAttempt - 1, 5)));
    _set(() {
      reconnecting = true;
      reconnectReason = reason;
      reconnectAt = DateTime.now().add(delay);
    });
    _retryTimer = Timer(delay, _retry);
  }

  void _retry() {
    final n = now;
    if (n == null) return;
    perf.record('reconnect', reconnectAttempt, {'reason': reconnectReason});
    play(n.item, n.kind, queue: n.queue, episode: n.episode, view: view, retry: true);
  }

  /// Leaves a catch-up replay for the channel's live stream.
  Future<void> backToLive() async {
    final n = now;
    if (n == null || !n.isCatchup) return;
    await play(n.item, n.kind, queue: n.queue, view: view);
  }

  /// "Şimdi dene": skip the remaining wait.
  void retryNow() {
    _retryTimer?.cancel();
    _retry();
  }

  void _clearReconnect() {
    _retryTimer?.cancel();
    reconnecting = false;
    reconnectAttempt = 0;
    reconnectReason = null;
    reconnectAt = null;
  }

  /// Next/previous channel in the queue (wraps around).
  Future<void> zap(int delta) async {
    final n = now;
    if (n == null || n.queue.isEmpty) return;
    final i = n.queue.indexWhere((c) => c.id == n.item.id);
    final next = n.queue[((i < 0 ? 0 : i) + delta) % n.queue.length];
    await play(next, n.kind, queue: n.queue, view: view);
  }

  Future<void> _saveProgress() async {
    final n = now;
    // Catch-up replays are not resumable items of their own.
    if (n == null || n.isLive || n.isCatchup) return;
    final pos = position.value.inMilliseconds;
    final dur = duration.inMilliseconds;
    if (dur <= 0 || pos <= 0) return;
    await library
        .saveProgress(
          n.item.id,
          episodeId: n.episode?.extId,
          title: n.title,
          positionMs: pos,
          durationMs: dur,
        )
        .catchError((_) {});
  }

  void setView(PlayerView v) {
    if (view == v) return;
    if (v != PlayerView.full) windowManager.setFullScreen(false);
    _set(() => view = v);
  }

  Future<void> toggleWindowFullscreen() async {
    final fs = await windowManager.isFullScreen();
    await windowManager.setFullScreen(!fs);
  }

  Future<void> stop() async {
    _openToken++;
    _progressTimer?.cancel();
    _stallTimer?.cancel();
    _clearReconnect();
    await _saveProgress();
    await engine.stop();
    await windowManager.setFullScreen(false);
    _set(() {
      now = null;
      view = PlayerView.hidden;
      opening = false;
      buffering = false;
    });
  }

  Future<void> togglePause() => engine.togglePause();

  Future<void> seekBy(Duration d) async {
    if (now?.isLive ?? true) return;
    var to = position.value + d;
    if (to < Duration.zero) to = Duration.zero;
    if (duration > Duration.zero && to > duration) to = duration;
    await engine.seek(to);
  }

  Future<void> seekTo(Duration d) => engine.seek(d);

  Future<void> setVolume(double v) async {
    volume = v.clamp(0, 100);
    await engine.setVolume(volume);
    notifyListeners();
  }

  Future<void> setAudio(AudioTrack t) => engine.setAudioTrack(t);
  Future<void> setSubtitle(SubtitleTrack t) => engine.setSubtitleTrack(t);

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _progressTimer?.cancel();
    _stallTimer?.cancel();
    _retryTimer?.cancel();
    position.dispose();
    super.dispose();
  }
}
