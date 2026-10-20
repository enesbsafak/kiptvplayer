import '../src/rust/api/library.dart' as rust;

export '../src/rust/api/library.dart'
    show
        Category,
        ContinueItem,
        EpisodeInfo,
        Item,
        ItemDetail,
        Kind,
        NewSourceInput,
        Playback,
        Programme,
        RegionCount,
        RegionPreference,
        SourceInfo,
        SyncEvent,
        SyncEvent_Connecting,
        SyncEvent_Done,
        SyncEvent_Downloading,
        SyncEvent_Failed,
        SyncEvent_Saving;

/// Everything screens may ask of the data core. Widget tests swap in a fake;
/// the app uses [RustLibrary].
abstract interface class LibraryApi {
  Future<List<rust.SourceInfo>> sources();
  Stream<rust.SyncEvent> addSource(rust.NewSourceInput input);
  Stream<rust.SyncEvent> syncSource(String sourceId);
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
  Future<List<rust.Item>> recent(String sourceId, rust.Kind kind, int limit);
  Future<List<rust.ContinueItem>> continueWatching(String sourceId, int limit);
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
  Future<List<rust.Item>> favorites(String sourceId, rust.Kind kind) =>
      rust.favorites(sourceId: sourceId, kind: kind);
  @override
  Future<List<rust.Item>> recent(String sourceId, rust.Kind kind, int limit) =>
      rust.recent(sourceId: sourceId, kind: kind, limit: limit);
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
}
