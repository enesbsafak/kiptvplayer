import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:karadelik_player/app/app_state.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/app/paging.dart';
import 'package:karadelik_player/app/scope.dart';
import 'package:karadelik_player/perf/perf.dart';
import 'package:karadelik_player/player/media_track.dart';
import 'package:karadelik_player/player/player_controller.dart';
import 'package:karadelik_player/player/player_engine.dart';

/// In-memory library: what the Rust core would return, without Rust.
class FakeLibrary implements LibraryApi {
  FakeLibrary({List<SourceInfo>? sources, this.addResult}) : _sources = sources ?? [];

  final List<SourceInfo> _sources;

  /// Events `addSource` emits; defaults to a successful add.
  final List<SyncEvent>? addResult;
  final List<NewSourceInput> added = [];
  final Map<Kind, List<Category>> cats = {};
  final Map<Kind, List<Item>> items = {};
  final Set<int> favs = {};
  String? region = 'TR';
  bool regionChosen = true;
  final List<int> played = [];
  final List<(int, int)> caughtUp = [];
  final Map<int, List<Programme>> past = {};

  /// TMDB: the key the fake accepts, what it returns per item.
  static const goodTmdbKey = 'good-key';
  String? tmdbKey;
  String tmdbLanguage = 'tr-TR';
  final Map<int, TmdbInfo> tmdb = {};
  final Map<int, List<TmdbEpisodeInfo>> tmdbEpisodes = {};

  static SourceInfo source({String id = 's1', String name = 'Demo', String? error, bool m3u = false, GuideInfo? guide}) => SourceInfo(
    id: id,
    kind: m3u ? SourceType.m3U : SourceType.xtream,
    epgUrl: m3u ? 'http://127.0.0.1:8089/xmltv.xml.gz' : null,
    guide: guide,
    name: name,
    url: 'http://127.0.0.1:8089',
    username: 'demo',
    lastError: error,
    liveCount: BigInt.from(3),
    movieCount: BigInt.from(2),
    seriesCount: BigInt.zero,
  );

  static Item item(int id, String name, {int? sort, bool catchup = false}) =>
      Item(id: id, uid: id, name: name, adult: false, sort: sort ?? id, hasCatchup: catchup);

  @override
  Future<List<SourceInfo>> sources() async => List.of(_sources);

  @override
  Stream<SyncEvent> addSource(NewSourceInput input) async* {
    added.add(input);
    for (final e in addResult ??
        [
          const SyncEvent.connecting(),
          const SyncEvent.downloading(what: 'Canlı kanallar'),
          const SyncEvent.saving(),
          SyncEvent.done(source: source(name: input.name.isEmpty ? 'Yeni' : input.name)),
        ]) {
      if (e is SyncEvent_Done) _sources.add(e.source);
      yield e;
    }
  }

  @override
  Stream<SyncEvent> syncSource(String sourceId) async* {
    yield SyncEvent.done(source: _sources.firstWhere((s) => s.id == sourceId));
  }

  /// What the next guide refresh reports.
  GuideInfo? nextGuide;
  final List<String> guideRefreshes = [];

  @override
  Future<SourceInfo> refreshGuide(String sourceId) async {
    guideRefreshes.add(sourceId);
    final i = _sources.indexWhere((s) => s.id == sourceId);
    final s = _sources[i];
    final updated = SourceInfo(
      id: s.id,
      kind: s.kind,
      name: s.name,
      url: s.url,
      username: s.username,
      lastError: s.lastError,
      liveCount: s.liveCount,
      movieCount: s.movieCount,
      seriesCount: s.seriesCount,
      epgUrl: s.epgUrl,
      guide: nextGuide,
    );
    _sources[i] = updated;
    return updated;
  }

  @override
  Future<void> removeSource(String sourceId) async => _sources.removeWhere((s) => s.id == sourceId);

  @override
  Future<List<Category>> categories(String sourceId, Kind kind) async => cats[kind] ?? const [];

  @override
  Future<List<Item>> page(String sourceId, Kind kind, {int? categoryUid, int? afterSort, int limit = 200}) async {
    final all = items[kind] ?? const <Item>[];
    return all.where((i) => afterSort == null || i.sort > afterSort).take(limit).toList();
  }

  @override
  Future<List<Item>> search(String query, {Kind? kind, int limit = 100}) async => (items[kind ?? Kind.live] ?? const [])
      .where((i) => i.name.toLowerCase().contains(query.toLowerCase()))
      .take(limit)
      .toList();

  @override
  Future<List<Item>> recentlyAdded(String sourceId, Kind kind, int limit) async =>
      (items[kind] ?? const []).take(limit).toList();

  final Map<int, List<Item>> backups = {};

  @override
  Future<List<Item>> alternates(int itemId) async => backups[itemId] ?? const [];

  @override
  Future<List<Item>> favorites(String sourceId, Kind kind) async =>
      (items[kind] ?? const []).where((i) => favs.contains(i.id)).toList();

  @override
  Future<List<Item>> recent(String sourceId, Kind kind, int limit) async => const [];

  @override
  Future<List<ContinueItem>> continueWatching(String sourceId, int limit) async => const [];

  @override
  Future<void> setFavorite(int itemId, bool on) async => on ? favs.add(itemId) : favs.remove(itemId);

  @override
  Future<bool> isFavorite(int itemId) async => favs.contains(itemId);

  @override
  Future<void> saveProgress(int itemId, {int? episodeId, required String title, required int positionMs, required int durationMs}) async {}

  @override
  Future<Playback> playback(int itemId, {int? episodeId, String? container}) async {
    played.add(itemId);
    return Playback(url: 'http://127.0.0.1/$itemId.ts', title: 'K$itemId', isLive: true);
  }

  @override
  Future<ItemDetail> detail(int itemId) async => ItemDetail(
    id: itemId,
    kind: Kind.movie,
    name: 'Film $itemId',
    plot: 'Sağlayıcının özeti.',
    cast: 'Oyuncu Bir, Oyuncu İki',
    episodes: const [],
    isFavorite: false,
  );

  @override
  Future<List<Programme>> epg(int itemId) async => const [];

  @override
  Future<List<Programme>> archive(int itemId) async => past[itemId] ?? const [];

  @override
  Future<Playback> catchupPlayback(int itemId, {required int start, required int stop}) async {
    caughtUp.add((itemId, start));
    return Playback(url: 'http://127.0.0.1/timeshift/$itemId/$start.ts', title: 'K$itemId', isLive: false);
  }

  @override
  Future<RegionPreference> regionPreference() async => RegionPreference(chosen: regionChosen, region: region);

  @override
  Future<void> setRegionPreference(String? region) async {
    this.region = region;
    regionChosen = true;
  }

  String? uiLanguageChoice;
  String? coreLanguage;

  @override
  Future<String?> uiLanguage() async => uiLanguageChoice;

  @override
  Future<void> setUiLanguage(String? choice, String effective) async {
    uiLanguageChoice = choice;
    coreLanguage = effective;
  }

  @override
  Future<TmdbStatus> tmdbStatus() async => TmdbStatus(configured: tmdbKey != null, language: tmdbLanguage);

  @override
  Future<void> setTmdbKey(String? key) async {
    if (key != null && key != goodTmdbKey) throw Exception('TMDB anahtarı geçersiz');
    tmdbKey = key;
  }

  @override
  Future<void> setTmdbLanguage(String language) async => tmdbLanguage = language;

  @override
  Future<TmdbInfo?> tmdbDetail(int itemId) async => tmdbKey == null ? null : tmdb[itemId];

  @override
  Future<List<TmdbEpisodeInfo>> tmdbSeason(int itemId, int season) async =>
      (tmdbEpisodes[itemId] ?? const []).where((e) => e.season == season).toList();

  @override
  Future<List<RegionCount>> sourceRegions(String sourceId) async =>
      const [RegionCount(region: 'TR', count: 2), RegionCount(region: 'DE', count: 1)];
}

/// Player engine that never touches mpv.
class FakeEngine implements PlayerEngine {
  final opened = <String>[];
  final bufferingCtl = StreamController<bool>.broadcast();
  final completedCtl = StreamController<bool>.broadcast();
  final errorsCtl = StreamController<String>.broadcast();

  /// How many upcoming opens should fail as if no picture arrived.
  int failNextOpens = 0;

  @override
  Widget surface() => const ColoredBox(color: Color(0xFF000000));
  @override
  Stream<bool> get buffering => bufferingCtl.stream;
  @override
  Stream<bool> get completed => completedCtl.stream;
  final playingCtl = StreamController<bool>.broadcast();
  int toggles = 0;
  @override
  Stream<bool> get playing => playingCtl.stream;
  @override
  Stream<Duration> get position => const Stream.empty();
  @override
  Stream<Duration> get duration => const Stream.empty();
  final tracksCtl = StreamController<List<MediaTrack>>.broadcast();
  final selections = <(TrackKind, String?)>[];
  @override
  Stream<List<MediaTrack>> get tracks => tracksCtl.stream;
  @override
  Stream<String> get errors => errorsCtl.stream;
  @override
  Stream<int?> get videoHeight => const Stream.empty();

  @override
  Future<Duration> open(String url, {Map<String, String> headers = const {}, Duration? start}) async {
    opened.add(url);
    if (failNextOpens > 0) {
      failNextOpens--;
      throw TimeoutException('no picture');
    }
    return const Duration(milliseconds: 1);
  }

  @override
  Future<void> stop() async {}
  @override
  Future<void> togglePause() async => toggles++;
  @override
  Future<void> seek(Duration to) async {}
  @override
  Future<void> setVolume(double percent) async {}
  @override
  Future<void> selectTrack(TrackKind kind, String? id) async => selections.add((kind, id));
  @override
  Future<void> dispose() async {}
}

/// Wraps [child] in the same scope the app uses, backed by fakes.
class TestHarness {
  TestHarness(this.library) : engine = FakeEngine() {
    // Tests read Turkish strings unless they choose otherwise.
    AppState.systemLocale = () => 'tr_TR';
    state = AppState(library);
    player = PlayerController(engine, library, Perf.init(const []));
    epg = EpgCache(library);
  }

  final FakeLibrary library;
  final FakeEngine engine;
  late final AppState state;
  late final PlayerController player;
  late final EpgCache epg;

  Widget wrap(Widget child) => AppScope(state: state, player: player, library: library, epg: epg, child: child);
}
