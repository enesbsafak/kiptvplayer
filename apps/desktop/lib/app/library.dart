import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show AnyhowException;

import '../src/rust/api/library.dart' as rust;

export '../src/rust/api/library.dart'
    show
        Category,
        ContinueItem,
        EpisodeInfo,
        GuideInfo,
        Item,
        ItemDetail,
        Kind,
        NewSourceInput,
        Playback,
        Programme,
        RegionCount,
        RegionPreference,
        SourceInfo,
        SourceType,
        SyncEvent,
        SyncEvent_Connecting,
        SyncEvent_Done,
        SyncEvent_Downloading,
        SyncEvent_Failed,
        SyncEvent_Saving,
        TmdbEpisodeInfo,
        TmdbInfo,
        TmdbPerson,
        TmdbStatus;

/// A core error as a sentence for the UI: the Rust message, without the
/// exception wrapper ("AnyhowException(...)", "Exception: ...").
String errorText(Object e) => switch (e) {
  AnyhowException(:final message) => message.split('\n').first,
  _ => '$e'.replaceFirst(RegExp(r'^\w*Exception:\s*'), ''),
};

/// Everything screens may ask of the data core. Widget tests swap in a fake;
/// the app uses [RustLibrary].
abstract interface class LibraryApi {
  Future<List<rust.SourceInfo>> sources();
  Stream<rust.SyncEvent> addSource(rust.NewSourceInput input);
  Stream<rust.SyncEvent> syncSource(String sourceId);

  /// Downloads an M3U source's XMLTV guide again; the result's `guide`
  /// tells how it went.
  Future<rust.SourceInfo> refreshGuide(String sourceId);
  Future<void> removeSource(String sourceId);
  Future<List<rust.Category>> categories(String sourceId, rust.Kind kind);
  Future<List<rust.Item>> page(
    String sourceId,
    rust.Kind kind, {
    int? categoryUid,
    int? afterSort,
    int limit,
  });
  Future<List<rust.Item>> search(String query, {rust.Kind? kind, int limit});
  Future<List<rust.Item>> recentlyAdded(String sourceId, rust.Kind kind, int limit);
  Future<List<rust.Item>> favorites(String sourceId, rust.Kind kind);

  /// Backup streams of a live channel (same tvg-id or name).
  Future<List<rust.Item>> alternates(int itemId);
  Future<List<rust.Item>> recent(String sourceId, rust.Kind kind, int limit);
  Future<List<rust.ContinueItem>> continueWatching(String sourceId, int limit);

  /// Forgets recent channels and/or resume points; favorites stay.
  Future<void> clearHistory(String sourceId, {bool recent = true, bool progress = true});
  Future<void> setFavorite(int itemId, bool on);
  Future<bool> isFavorite(int itemId);
  Future<void> saveProgress(
    int itemId, {
    int? episodeId,
    required String title,
    required int positionMs,
    required int durationMs,
  });
  Future<rust.Playback> playback(int itemId, {int? episodeId, String? container});
  Future<rust.ItemDetail> detail(int itemId);
  Future<List<rust.Programme>> epg(int itemId);

  /// Past programmes of a catch-up channel that can be replayed, newest first.
  Future<List<rust.Programme>> archive(int itemId);
  Future<rust.Playback> catchupPlayback(int itemId, {required int start, required int stop});
  Future<rust.RegionPreference> regionPreference();
  Future<void> setRegionPreference(String? region);
  Future<List<rust.RegionCount>> sourceRegions(String sourceId);

  /// The app language the user chose; null follows the system.
  Future<String?> uiLanguage();

  /// Saves [choice] and switches core messages to [effective].
  Future<void> setUiLanguage(String? choice, String effective);

  Future<rust.TmdbStatus> tmdbStatus();

  /// Validates [key] with TMDB before saving it; null removes it.
  Future<void> setTmdbKey(String? key);
  Future<void> setTmdbLanguage(String language);
  Future<rust.TmdbInfo?> tmdbDetail(int itemId);
  Future<List<rust.TmdbEpisodeInfo>> tmdbSeason(int itemId, int season);
}

class RustLibrary implements LibraryApi {
  @override
  Future<List<rust.SourceInfo>> sources() => rust.listSources();
  @override
  Stream<rust.SyncEvent> addSource(rust.NewSourceInput input) =>
      rust.addSource(input: input);
  @override
  Stream<rust.SyncEvent> syncSource(String sourceId) =>
      rust.syncSource(sourceId: sourceId);
  @override
  Future<rust.SourceInfo> refreshGuide(String sourceId) => rust.refreshGuide(sourceId: sourceId);
  @override
  Future<void> removeSource(String sourceId) =>
      rust.removeSource(sourceId: sourceId);
  @override
  Future<List<rust.Category>> categories(String sourceId, rust.Kind kind) =>
      rust.categories(sourceId: sourceId, kind: kind);
  @override
  Future<List<rust.Item>> page(
    String sourceId,
    rust.Kind kind, {
    int? categoryUid,
    int? afterSort,
    int limit = 200,
  }) => rust.itemsPage(
    sourceId: sourceId,
    kind: kind,
    categoryUid: categoryUid,
    afterSort: afterSort,
    limit: limit,
  );
  @override
  Future<List<rust.Item>> search(
    String query, {
    rust.Kind? kind,
    int limit = 100,
  }) => rust.search(query: query, kind: kind, limit: limit);
  @override
  Future<List<rust.Item>> recentlyAdded(
    String sourceId,
    rust.Kind kind,
    int limit,
  ) => rust.recentlyAdded(sourceId: sourceId, kind: kind, limit: limit);
  @override
  Future<List<rust.Item>> alternates(int itemId) => rust.alternates(itemId: itemId);
  @override
  Future<List<rust.Item>> favorites(String sourceId, rust.Kind kind) =>
      rust.favorites(sourceId: sourceId, kind: kind);
  @override
  Future<List<rust.Item>> recent(String sourceId, rust.Kind kind, int limit) =>
      rust.recent(sourceId: sourceId, kind: kind, limit: limit);
  @override
  Future<void> clearHistory(String sourceId, {bool recent = true, bool progress = true}) =>
      rust.clearHistory(sourceId: sourceId, recent: recent, progress: progress);
  @override
  Future<List<rust.ContinueItem>> continueWatching(String sourceId, int limit) =>
      rust.continueWatching(sourceId: sourceId, limit: limit);
  @override
  Future<void> setFavorite(int itemId, bool on) =>
      rust.setFavorite(itemId: itemId, on_: on);
  @override
  Future<bool> isFavorite(int itemId) => rust.isFavorite(itemId: itemId);
  @override
  Future<void> saveProgress(
    int itemId, {
    int? episodeId,
    required String title,
    required int positionMs,
    required int durationMs,
  }) => rust.saveProgress(
    itemId: itemId,
    episodeId: episodeId,
    title: title,
    positionMs: positionMs,
    durationMs: durationMs,
  );
  @override
  Future<rust.Playback> playback(
    int itemId, {
    int? episodeId,
    String? container,
  }) => rust.playback(
    itemId: itemId,
    episodeId: episodeId,
    container: container,
  );
  @override
  Future<rust.ItemDetail> detail(int itemId) => rust.detail(itemId: itemId);
  @override
  Future<List<rust.Programme>> epg(int itemId) => rust.epg(itemId: itemId);
  @override
  Future<List<rust.Programme>> archive(int itemId) => rust.archive(itemId: itemId);
  @override
  Future<rust.Playback> catchupPlayback(int itemId, {required int start, required int stop}) =>
      rust.catchupPlayback(itemId: itemId, start: start, stop: stop);
  @override
  Future<rust.RegionPreference> regionPreference() => rust.regionPreference();
  @override
  Future<void> setRegionPreference(String? region) =>
      rust.setRegionPreference(region: region);
  @override
  Future<List<rust.RegionCount>> sourceRegions(String sourceId) =>
      rust.sourceRegions(sourceId: sourceId);
  @override
  Future<String?> uiLanguage() => rust.uiLanguage();
  @override
  Future<void> setUiLanguage(String? choice, String effective) =>
      rust.setUiLanguage(choice: choice, effective: effective);
  @override
  Future<rust.TmdbStatus> tmdbStatus() => rust.tmdbStatus();
  @override
  Future<void> setTmdbKey(String? key) => rust.setTmdbKey(key: key);
  @override
  Future<void> setTmdbLanguage(String language) => rust.setTmdbLanguage(language: language);
  @override
  Future<rust.TmdbInfo?> tmdbDetail(int itemId) => rust.tmdbDetail(itemId: itemId);
  @override
  Future<List<rust.TmdbEpisodeInfo>> tmdbSeason(int itemId, int season) =>
      rust.tmdbSeason(itemId: itemId, season: season);
}
