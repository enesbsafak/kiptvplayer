import 'package:flutter_rust_bridge/flutter_rust_bridge.dart' show AnyhowException;

import '../src/rust/api/library.dart' as rust;

export '../src/rust/api/library.dart'
    show
        BackupCounts,
        Category,
        ContinueItem,
        EpisodeInfo,
        EpgSettings,
        GuideEntry,
        GuideInfo,
        HiddenItems,
        Item,
        ItemDetail,
        Kind,
        NewSourceInput,
        Parental,
        Playback,
        Programme,
        RegionCount,
        RegionPreference,
        RestoreResult,
        Reminder,
        SourceHealth,
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

  /// The user's edits: hidden / renamed channels and categories, category
  /// order, custom groups (uid = group id). Kept across syncs.
  Future<void> hideChannel(int itemId, {required bool hidden});
  Future<void> renameChannel(int itemId, String? name);
  Future<void> hideCategory(String sourceId, int uid, {required bool hidden});
  Future<void> renameCategory(String sourceId, int uid, String? name);
  Future<void> moveCategory(String sourceId, rust.Kind kind, int uid, int delta);
  Future<rust.HiddenItems> hiddenItems(String sourceId);
  Future<String?> originalName(String sourceId, int uid, {required bool category});
  Future<List<rust.Category>> userGroups(String sourceId, rust.Kind kind);
  Future<int> createGroup(String sourceId, rust.Kind kind, String name);
  Future<void> renameGroup(int groupId, String name);
  Future<void> deleteGroup(int groupId);
  Future<void> moveGroup(int groupId, int delta);
  Future<void> addToGroup(int groupId, int itemId);
  Future<void> removeFromGroup(int groupId, int itemId);
  Future<void> moveInGroup(int groupId, int itemId, int delta);
  Future<List<rust.Item>> groupItems(int groupId);

  /// Encrypted backup of everything the user made, and restoring it.
  Future<rust.BackupCounts> exportBackup(String path, String password);
  Future<rust.RestoreResult> importBackup(String path, String password);

  /// A live channel's guide corrections: shift and hand-picked match.
  Future<rust.EpgSettings> epgSettings(int itemId);
  Future<void> setEpgSettings(int itemId, {String? forced, required int shiftMinutes});
  Future<List<rust.GuideEntry>> findGuideChannels(String sourceId, String query);

  /// Parental lock (PIN) state, and its changes.
  Future<rust.Parental> parental();
  Future<rust.Parental> setParentalPin({String? current, String? pin});
  Future<bool> unlockAdult(String pin);
  Future<void> lockAdult();
  Future<int> lockedCategories(String sourceId, rust.Kind kind);

  /// App preferences stored with the library (null when unset).
  Future<String?> appSetting(String key);
  Future<void> setAppSetting(String key, String? value);

  /// Programme reminders not over yet, soonest first.
  Future<List<rust.Reminder>> reminders(String sourceId);
  Future<void> setReminder(int itemId, int start, int stop, String title, {required bool on});

  /// One light, timed request to the provider (never opens a stream).
  Future<rust.SourceHealth> checkSource(String sourceId);
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
  Future<rust.SourceHealth> checkSource(String sourceId) => rust.checkSource(sourceId: sourceId);
  @override
  Future<List<rust.Reminder>> reminders(String sourceId) => rust.reminders(sourceId: sourceId);
  @override
  Future<void> hideChannel(int itemId, {required bool hidden}) => rust.hideChannel(itemId: itemId, hidden: hidden);
  @override
  Future<void> renameChannel(int itemId, String? name) => rust.renameChannel(itemId: itemId, name: name);
  @override
  Future<void> hideCategory(String sourceId, int uid, {required bool hidden}) =>
      rust.hideCategory(sourceId: sourceId, uid: uid, hidden: hidden);
  @override
  Future<void> renameCategory(String sourceId, int uid, String? name) => rust.renameCategory(sourceId: sourceId, uid: uid, name: name);
  @override
  Future<void> moveCategory(String sourceId, rust.Kind kind, int uid, int delta) =>
      rust.moveCategory(sourceId: sourceId, kind: kind, uid: uid, delta: delta);
  @override
  Future<rust.HiddenItems> hiddenItems(String sourceId) => rust.hiddenItems(sourceId: sourceId);
  @override
  Future<String?> originalName(String sourceId, int uid, {required bool category}) =>
      rust.originalName(sourceId: sourceId, uid: uid, category: category);
  @override
  Future<List<rust.Category>> userGroups(String sourceId, rust.Kind kind) => rust.userGroups(sourceId: sourceId, kind: kind);
  @override
  Future<int> createGroup(String sourceId, rust.Kind kind, String name) => rust.createGroup(sourceId: sourceId, kind: kind, name: name);
  @override
  Future<void> renameGroup(int groupId, String name) => rust.renameGroup(groupId: groupId, name: name);
  @override
  Future<void> deleteGroup(int groupId) => rust.deleteGroup(groupId: groupId);
  @override
  Future<void> moveGroup(int groupId, int delta) => rust.moveGroup(groupId: groupId, delta: delta);
  @override
  Future<void> addToGroup(int groupId, int itemId) => rust.addToGroup(groupId: groupId, itemId: itemId);
  @override
  Future<void> removeFromGroup(int groupId, int itemId) => rust.removeFromGroup(groupId: groupId, itemId: itemId);
  @override
  Future<void> moveInGroup(int groupId, int itemId, int delta) => rust.moveInGroup(groupId: groupId, itemId: itemId, delta: delta);
  @override
  Future<List<rust.Item>> groupItems(int groupId) => rust.groupItems(groupId: groupId);
  @override
  Future<rust.BackupCounts> exportBackup(String path, String password) => rust.exportBackup(path: path, password: password);
  @override
  Future<rust.RestoreResult> importBackup(String path, String password) => rust.importBackup(path: path, password: password);
  @override
  Future<rust.EpgSettings> epgSettings(int itemId) => rust.epgSettings(itemId: itemId);
  @override
  Future<void> setEpgSettings(int itemId, {String? forced, required int shiftMinutes}) =>
      rust.setEpgSettings(itemId: itemId, forced: forced, shiftMinutes: shiftMinutes);
  @override
  Future<List<rust.GuideEntry>> findGuideChannels(String sourceId, String query) =>
      rust.findGuideChannels(sourceId: sourceId, query: query);
  @override
  Future<rust.Parental> parental() => rust.parental();
  @override
  Future<rust.Parental> setParentalPin({String? current, String? pin}) => rust.setParentalPin(current: current, new_: pin);
  @override
  Future<bool> unlockAdult(String pin) => rust.unlockAdult(pin: pin);
  @override
  Future<void> lockAdult() => rust.lockAdult();
  @override
  Future<int> lockedCategories(String sourceId, rust.Kind kind) => rust.lockedCategories(sourceId: sourceId, kind: kind);
  @override
  Future<String?> appSetting(String key) => rust.appSetting(key: key);
  @override
  Future<void> setAppSetting(String key, String? value) => rust.setAppSetting(key: key, value: value);
  @override
  Future<void> setReminder(int itemId, int start, int stop, String title, {required bool on}) =>
      rust.setReminder(itemId: itemId, start: start, stop: stop, title: title, on_: on);
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
