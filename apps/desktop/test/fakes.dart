import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show AnyhowException;
import 'package:karadelik_player/app/app_state.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/app/paging.dart';
import 'package:karadelik_player/app/scope.dart';
import 'package:karadelik_player/app/updates.dart';
import 'package:karadelik_player/perf/perf.dart';
import 'package:karadelik_player/player/media_track.dart';
import 'package:karadelik_player/player/playback_stats.dart';
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

  // The user's edits, in memory: hidden ids, names, groups.
  final hiddenIds = <int>{};
  final hiddenCats = <int>{};
  final names = <int, String>{};
  final groups = <int, (String, List<int>)>{};
  int _nextGroup = 1;

  Item _named(Item i) => names.containsKey(i.id)
      ? Item(id: i.id, uid: i.uid, name: names[i.id]!, logo: i.logo, chno: i.chno, adult: i.adult, sort: i.sort, hasCatchup: i.hasCatchup)
      : i;
  Item? _find(int id) => items.values.expand((l) => l).where((i) => i.id == id).firstOrNull;

  @override
  Future<void> hideChannel(int itemId, {required bool hidden}) async => hidden ? hiddenIds.add(itemId) : hiddenIds.remove(itemId);
  @override
  Future<void> renameChannel(int itemId, String? name) async => name == null ? names.remove(itemId) : names[itemId] = name;
  @override
  Future<void> hideCategory(String sourceId, int uid, {required bool hidden}) async => hidden ? hiddenCats.add(uid) : hiddenCats.remove(uid);
  @override
  Future<void> renameCategory(String sourceId, int uid, String? name) async {}
  @override
  Future<void> moveCategory(String sourceId, Kind kind, int uid, int delta) async {}
  @override
  Future<HiddenItems> hiddenItems(String sourceId) async => HiddenItems(
    categories: [for (final c in cats.values.expand((l) => l)) if (hiddenCats.contains(c.uid)) c],
    channels: [for (final id in hiddenIds) ?_find(id)],
  );
  @override
  Future<String?> originalName(String sourceId, int uid, {required bool category}) async =>
      names.containsKey(uid) ? _find(uid)?.name : null;
  @override
  Future<List<Category>> userGroups(String sourceId, Kind kind) async => [
    for (final e in groups.entries) Category(uid: e.key, name: e.value.$1, adult: false, count: e.value.$2.length),
  ];
  @override
  Future<int> createGroup(String sourceId, Kind kind, String name) async {
    groups[_nextGroup] = (name, []);
    return _nextGroup++;
  }

  @override
  Future<void> renameGroup(int groupId, String name) async => groups[groupId] = (name, groups[groupId]!.$2);
  @override
  Future<void> deleteGroup(int groupId) async => groups.remove(groupId);
  @override
  Future<void> moveGroup(int groupId, int delta) async {}
  @override
  Future<void> addToGroup(int groupId, int itemId) async {
    final ids = groups[groupId]!.$2;
    if (!ids.contains(itemId)) ids.add(itemId);
  }

  @override
  Future<void> removeFromGroup(int groupId, int itemId) async => groups[groupId]!.$2.remove(itemId);
  @override
  Future<void> moveInGroup(int groupId, int itemId, int delta) async {
    final ids = groups[groupId]!.$2;
    final at = ids.indexOf(itemId);
    ids.insert((at + delta).clamp(0, ids.length - 1), ids.removeAt(at));
  }

  @override
  Future<List<Item>> groupItems(int groupId) async => [for (final id in groups[groupId]!.$2) ?_find(id)].map(_named).toList();

  String? opensubsKey;
  final subtitleSearches = <(int, int?, int?)>[];
  @override
  Future<bool> opensubsConfigured() async => opensubsKey != null;
  @override
  Future<void> setOpensubsKey(String? key) async {
    if (key != null && key != 'os-key') throw AnyhowException('OpenSubtitles anahtarı reddedildi');
    opensubsKey = key;
  }

  @override
  Future<List<SubtitleResult>> subtitleSearch(int itemId, {int? season, int? episode}) async {
    subtitleSearches.add((itemId, season, episode));
    return const [
      SubtitleResult(fileId: 1, language: 'tr', release: 'Film.1080p.WEB', fileName: 'a.srt', downloads: 4200, hearingImpaired: false, machine: false, trusted: true),
      SubtitleResult(fileId: 2, language: 'en', release: 'Film.1080p.BluRay', fileName: 'b.srt', downloads: 90, hearingImpaired: true, machine: false, trusted: true),
    ];
  }

  @override
  Future<SubtitleFile> subtitleDownload(int fileId) async => SubtitleFile(path: 'C:/subs/$fileId.srt', remaining: 19);

  final backupFiles = <String, String>{};
  @override
  Future<BackupCounts> exportBackup(String path, String password) async {
    if (password.length < 8) throw AnyhowException('Parola en az 8 karakter olmalı');
    backupFiles[path] = password;
    return BackupCounts(sources: _sources.length, favorites: favs.length, groups: groups.length, edits: 0);
  }

  @override
  Future<RestoreResult> importBackup(String path, String password) async {
    if (backupFiles[path] != password) throw AnyhowException('Parola yanlış ya da dosya bozuk');
    return RestoreResult(counts: BackupCounts(sources: _sources.length, favorites: favs.length, groups: 0, edits: 0), toSync: const []);
  }

  final epgOverrides = <int, (String?, int)>{};
  List<GuideEntry> guideChannels = const [GuideEntry(id: 'trt1.tr', label: 'TRT 1'), GuideEntry(id: 'atv.tr', label: 'ATV')];
  @override
  Future<EpgSettings> epgSettings(int itemId) async {
    final o = epgOverrides[itemId];
    return EpgSettings(hasGuide: true, mapped: guideChannels.first, forced: o?.$1, shiftMinutes: o?.$2 ?? 0);
  }

  @override
  Future<void> setEpgSettings(int itemId, {String? forced, required int shiftMinutes}) async =>
      epgOverrides[itemId] = (forced, shiftMinutes);
  @override
  Future<List<GuideEntry>> findGuideChannels(String sourceId, String query) async =>
      guideChannels.where((g) => g.label.toLowerCase().contains(query.toLowerCase())).toList();

  String? pin;
  bool locked = false;
  int adultCategories = 0;
  @override
  Future<Parental> parental() async => Parental(pinSet: pin != null, locked: locked);
  @override
  Future<Parental> setParentalPin({String? current, String? pin}) async {
    if (this.pin != null && current != this.pin) throw AnyhowException('PIN yanlış');
    this.pin = pin;
    locked = pin != null;
    return parental();
  }

  @override
  Future<bool> unlockAdult(String pin) async {
    if (pin != this.pin) return false;
    locked = false;
    return true;
  }

  @override
  Future<void> lockAdult() async => locked = pin != null;
  @override
  Future<int> lockedCategories(String sourceId, Kind kind) async => locked ? adultCategories : 0;

  final appSettings = <String, String>{};
  @override
  Future<String?> appSetting(String key) async => appSettings[key];
  @override
  Future<void> setAppSetting(String key, String? value) async =>
      value == null ? appSettings.remove(key) : appSettings[key] = value;

  List<Reminder> reminderList = [];
  @override
  Future<List<Reminder>> reminders(String sourceId) async => [...reminderList]..sort((a, b) => a.start.compareTo(b.start));
  @override
  Future<void> setReminder(int itemId, int start, int stop, String title, {required bool on}) async {
    reminderList.removeWhere((r) => r.item.id == itemId && r.start == start);
    if (on) reminderList.add(Reminder(item: item(itemId, 'Kanal $itemId'), start: start, stop: stop, title: title));
  }

  SourceHealth health = const SourceHealth(ok: true, latencyMs: 120, maxConnections: 2, activeConnections: 1);
  final checked = <String>[];
  @override
  Future<SourceHealth> checkSource(String sourceId) async {
    checked.add(sourceId);
    return health;
  }

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
    return all
        .where((i) => !hiddenIds.contains(i.id) && (afterSort == null || i.sort > afterSort))
        .map(_named)
        .take(limit)
        .toList();
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
  Future<List<Item>> recent(String sourceId, Kind kind, int limit) async => recentItems;

  List<ContinueItem> continuing = const [];
  List<Item> recentItems = const [];
  final cleared = <(bool, bool)>[];

  @override
  Future<List<ContinueItem>> continueWatching(String sourceId, int limit) async => continuing;

  @override
  Future<void> clearHistory(String sourceId, {bool recent = true, bool progress = true}) async {
    cleared.add((recent, progress));
    if (recent) recentItems = const [];
    if (progress) continuing = const [];
  }

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
  Future<Duration> open(String url, {Map<String, String> headers = const {}, Duration? start, bool live = false}) async {
    opened.add(url);
    openedLive.add(live);
    if (failNextOpens > 0) {
      failNextOpens--;
      throw TimeoutException('no picture');
    }
    return const Duration(milliseconds: 1);
  }

  @override
  Future<void> stop() async => stops++;
  int stops = 0;
  @override
  Future<void> togglePause() async => toggles++;
  @override
  Future<void> seek(Duration to) async => seeks.add(to);
  final seeks = <Duration>[];
  final openedLive = <bool>[];
  int timeshiftMb = 0;
  (Duration, Duration)? range;
  @override
  void setTimeshift(int megabytes, {String? dir}) => timeshiftMb = megabytes;
  @override
  Future<(Duration, Duration)?> seekableRange() async => range;
  @override
  Future<void> setVolume(double percent) async {}
  @override
  Future<void> selectTrack(TrackKind kind, String? id) async => selections.add((kind, id));

  final subtitlePositions = <int>[];
  final adjustments = <String, Object?>{};
  PlaybackStats nextStats = PlaybackStats.empty;
  @override
  Future<PlaybackStats> stats() async => nextStats;
  @override
  Future<void> setSubtitleDelay(double seconds) async => adjustments['subDelay'] = seconds;
  @override
  Future<void> setAudioDelay(double seconds) async => adjustments['audioDelay'] = seconds;
  @override
  Future<void> setSubtitleScale(double scale) async => adjustments['subScale'] = scale;
  @override
  Future<void> setAspect(String? aspect) async => adjustments['aspect'] = aspect;
  @override
  Future<void> setSpeed(double speed) async => adjustments['speed'] = speed;
  @override
  Future<void> addSubtitleFile(String path, {String? title, String? language}) async {
    adjustments['subFile'] = path;
    adjustments['subFileName'] = (title, language);
  }
  @override
  Future<void> setSubtitlePosition(int percent) async => subtitlePositions.add(percent);
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
    updates = UpdateService(
      check: () async => nextUpdate,
      download: () => Stream.fromIterable(downloadEvents),
      install: (path) async => installed.add(path),
      previous: () async => previousRelease,
      quit: () async => quits++,
    );
  }

  /// What the fake update feed offers, and what happened with it.
  UpdateInfo? nextUpdate;
  List<UpdateProgress> downloadEvents = const [];
  (String, String)? previousRelease;
  final List<String> installed = [];
  int quits = 0;
  late final UpdateService updates;

  final FakeLibrary library;
  final FakeEngine engine;
  late final AppState state;
  late final PlayerController player;
  late final EpgCache epg;

  Widget wrap(Widget child) => AppScope(state: state, player: player, library: library, epg: epg, updates: updates, child: child);
}
