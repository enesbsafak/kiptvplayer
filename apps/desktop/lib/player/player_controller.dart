import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:window_manager/window_manager.dart';

import '../app/library.dart';
import '../l10n/l10n.dart';
import '../perf/perf.dart';
import 'media_track.dart';
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
      engine.tracks.listen(_onTracks),
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

  /// Asks the full-screen player to open its audio/subtitle panel (media
  /// flyout, automation); the player screen resets it once shown.
  final tracksPanelRequest = ValueNotifier(false);
  List<MediaTrack> tracks = const [];
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

  /// Failover: after this many failed reopens of the chosen stream, the
  /// channel's backup streams (same tvg-id or name) are tried in turn, then
  /// the original again, with the same growing waits.
  static const failoverAfter = 2;

  /// The channel the user picked; [now] may be one of its backups.
  Item? _origin;
  List<Item>? _backups;

  /// Name of the backup stream playing (or being tried) instead of the
  /// chosen one; null on the original.
  String? get backupName {
    final n = now, o = _origin;
    return n == null || o == null || n.item.id == o.id ? null : n.item.name;
  }

  /// Playback adjustments shown in the player's settings column. Delays
  /// belong to one stream and reset on the next; size, aspect stay.
  double subtitleDelay = 0;
  double audioDelay = 0;
  double subtitleScale = 1;
  String? aspect;
  double speed = 1;

  /// When the sleep timer stops playback; null when off.
  DateTime? sleepAt;
  Timer? _sleepTimer;

  /// Number-key channel entry: digits typed so far, shown on screen.
  String zapDigits = '';
  Timer? _digitTimer;
  static const digitWait = Duration(milliseconds: 1500);

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
    if (!retry) {
      _clearReconnect();
      _origin = item;
      _backups = null;
    }
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
      await _applyAdjustments(newStream: !retry);
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
        error = e is TimeoutException ? l10n.errNoPicture : errorText(e);
        _scheduleReconnect(error!);
      }
    } finally {
      if (token == _openToken) _set(() => opening = false);
    }
  }

  String? _loggedTracks;

  /// Tracks as mpv reports them go to perf.jsonl (no URLs): what a
  /// "subtitle shows nothing" report needs to be explained.
  void _onTracks(List<MediaTrack> v) {
    _set(() => tracks = v);
    if (v.isEmpty) return;
    final summary = v
        .map((t) => [
              '${t.kind.name}#${t.id}',
              t.lang ?? '-',
              t.codec ?? '-',
              if (t.title != null) '"${t.title}"',
              if (t.forced) 'forced',
              if (t.isDefault) 'default',
              if (t.hearingImpaired) 'sdh',
              if (t.external) 'external',
              if (t.selected) 'SELECTED',
            ].join(' '))
        .join('; ');
    if (summary == _loggedTracks) return;
    _loggedTracks = summary;
    perf.record('tracks', v.length, {'title': now?.title, 'tracks': summary});
  }

  void _onBuffering(bool v) {
    buffering = v;
    final live = now?.isLive ?? false;
    if (v && live && !opening) {
      _stallTimer ??= Timer(stallLimit, () {
        _stallTimer = null;
        _scheduleReconnect(l10n.reasonStalled);
      });
    } else if (!v) {
      _stallTimer?.cancel();
      _stallTimer = null;
    }
    notifyListeners();
  }

  void _onError(String e) {
    error = e;
    if (!opening) _scheduleReconnect(l10n.reasonError);
    notifyListeners();
  }

  void _onCompleted(bool done) {
    // A live stream has no end: reaching one means the connection dropped.
    if (done && (now?.isLive ?? false) && !opening) _scheduleReconnect(l10n.reasonEnded);
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

  Future<void> _retry() async {
    final n = now;
    if (n == null) return;
    perf.record('reconnect', reconnectAttempt, {'reason': reconnectReason});
    final next = await _nextStream(n);
    if (now != n) return; // the user moved on meanwhile
    play(next, n.kind, queue: n.queue, episode: n.episode, view: view, retry: true);
  }

  /// The stream to reopen: the current one at first, then backups in turn.
  Future<Item> _nextStream(NowPlaying n) async {
    final origin = _origin ?? n.item;
    if (!n.isLive || reconnectAttempt <= failoverAfter) return n.item;
    _backups ??= await library.alternates(origin.id).catchError((_) => <Item>[]);
    final candidates = [..._backups!, origin];
    if (candidates.length == 1) return origin;
    final next = candidates[(reconnectAttempt - failoverAfter - 1) % candidates.length];
    if (next.id != n.item.id) perf.record('failover', reconnectAttempt, {'to': next.id});
    return next;
  }

  /// A digit pressed while live TV plays: after a short pause (or Enter),
  /// tunes to that channel number in the current list.
  void typeDigit(int digit) {
    final n = now;
    if (n == null || !n.isLive || n.queue.isEmpty) return;
    zapDigits = '$zapDigits$digit';
    if (zapDigits.length > 4) zapDigits = zapDigits.substring(zapDigits.length - 4);
    _digitTimer?.cancel();
    _digitTimer = Timer(digitWait, commitDigits);
    notifyListeners();
  }

  /// Tunes to the typed number: the channel carrying that number (tvg-chno /
  /// provider order), else that position in the list.
  Future<void> commitDigits() async {
    _digitTimer?.cancel();
    final typed = int.tryParse(zapDigits);
    zapDigits = '';
    notifyListeners();
    final n = now;
    if (typed == null || n == null || n.queue.isEmpty) return;
    final target = n.queue.where((c) => c.chno == typed).firstOrNull ??
        (typed >= 1 && typed <= n.queue.length ? n.queue[typed - 1] : null);
    if (target != null && target.id != n.item.id) await play(target, n.kind, queue: n.queue, view: view);
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
    // Leaving full screen is cosmetic: never let it keep the player running.
    await windowManager.setFullScreen(false).catchError((_) {});
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

  Future<void> setAudio(MediaTrack t) => engine.selectTrack(TrackKind.audio, t.id);

  /// Null turns subtitles off.
  Future<void> setSubtitle(MediaTrack? t) => engine.selectTrack(TrackKind.subtitle, t?.id);

  /// Delays are per stream: a new one starts at zero; speed applies to
  /// files only (live always plays at 1x).
  Future<void> _applyAdjustments({required bool newStream}) async {
    if (newStream) {
      subtitleDelay = 0;
      audioDelay = 0;
    }
    if (now?.isLive ?? true) speed = 1;
    await engine.setSubtitleDelay(subtitleDelay);
    await engine.setAudioDelay(audioDelay);
    await engine.setSubtitleScale(subtitleScale);
    await engine.setAspect(aspect);
    await engine.setSpeed(speed);
  }

  Future<void> nudgeSubtitleDelay(double by) async {
    subtitleDelay = double.parse((subtitleDelay + by).toStringAsFixed(1));
    await engine.setSubtitleDelay(subtitleDelay);
    notifyListeners();
  }

  Future<void> nudgeAudioDelay(double by) async {
    audioDelay = double.parse((audioDelay + by).toStringAsFixed(1));
    await engine.setAudioDelay(audioDelay);
    notifyListeners();
  }

  Future<void> setSubtitleScale(double scale) async {
    subtitleScale = scale.clamp(0.5, 2.5).toDouble();
    await engine.setSubtitleScale(subtitleScale);
    notifyListeners();
  }

  Future<void> setAspect(String? value) async {
    aspect = value;
    await engine.setAspect(value);
    notifyListeners();
  }

  Future<void> setSpeed(double value) async {
    if (now?.isLive ?? true) return;
    speed = value;
    await engine.setSpeed(value);
    notifyListeners();
  }

  Future<void> addSubtitleFile(String path) => engine.addSubtitleFile(path);

  /// Stops playback after [after]; null switches the timer off.
  void setSleepTimer(Duration? after) {
    _sleepTimer?.cancel();
    _sleepTimer = null;
    sleepAt = after == null ? null : DateTime.now().add(after);
    if (after != null) {
      _sleepTimer = Timer(after, () {
        sleepAt = null;
        stop();
      });
    }
    notifyListeners();
  }

  /// Sleep at the end of the programme now on air (live TV with a guide).
  void sleepAtProgrammeEnd(int stopUnix) {
    final left = DateTime.fromMillisecondsSinceEpoch(stopUnix * 1000).difference(DateTime.now());
    if (left > Duration.zero) setSleepTimer(left);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _progressTimer?.cancel();
    _stallTimer?.cancel();
    _retryTimer?.cancel();
    _digitTimer?.cancel();
    _sleepTimer?.cancel();
    position.dispose();
    tracksPanelRequest.dispose();
    super.dispose();
  }
}
