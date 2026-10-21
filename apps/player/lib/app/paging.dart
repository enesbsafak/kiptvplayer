import 'package:flutter/foundation.dart';

import 'library.dart';

/// Keyset-paged item list: loads [pageSize] rows at a time as the user
/// scrolls, so a 50k-channel category never loads at once.
class ItemPager extends ChangeNotifier {
  ItemPager({
    required this.library,
    required this.sourceId,
    required this.kind,
    this.categoryUid,
    this.pageSize = 400,
  });

  final LibraryApi library;
  final String sourceId;
  final Kind kind;
  final int? categoryUid;
  final int pageSize;

  final List<Item> items = [];
  bool loading = false;
  bool done = false;
  Object? error;
  bool _disposed = false;

  Future<void> loadMore() async {
    if (loading || done) return;
    loading = true;
    notifyListeners();
    try {
      final page = await library.page(
        sourceId,
        kind,
        categoryUid: categoryUid,
        afterSort: items.isEmpty ? null : items.last.sort,
        limit: pageSize,
      );
      if (_disposed) return;
      items.addAll(page);
      done = page.length < pageSize;
    } catch (e) {
      error = e;
      done = true;
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

/// Now/next per live channel, fetched lazily for rows on screen with at most
/// four requests in flight, so scrolling never floods the provider.
/// Catch-up channels can also carry their replayable past (`archive: true`).
class EpgCache extends ChangeNotifier {
  EpgCache(this.library);

  final LibraryApi library;
  final Map<int, List<Programme>> _data = {};
  final Set<int> _withArchive = {};
  final Set<int> _pending = {};
  final List<(int, bool)> _queue = [];
  int _inFlight = 0;
  static const _maxInFlight = 4;

  List<Programme>? peek(int itemId) => _data[itemId];

  /// Current programme, if known.
  Programme? now(int itemId) {
    final list = _data[itemId];
    if (list == null) return null;
    final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final p in list) {
      if (p.start <= t && p.stop > t) return p;
    }
    return null;
  }

  Programme? next(int itemId) {
    final list = _data[itemId];
    if (list == null) return null;
    final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final p in list) {
      if (p.start > t) return p;
    }
    return null;
  }

  /// Whether [itemId]'s archive has been loaded (see [want]).
  bool hasArchive(int itemId) => _withArchive.contains(itemId);

  /// Replayable past programmes, newest first (empty until loaded).
  List<Programme> archive(int itemId) {
    final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return [
      for (final p in (_data[itemId] ?? const <Programme>[]).reversed)
        if (p.archive && p.stop <= t) p,
    ];
  }

  void want(int itemId, {bool archive = false}) {
    final have = _data.containsKey(itemId) && (!archive || _withArchive.contains(itemId));
    if (have || _pending.contains(itemId)) return;
    _pending.add(itemId);
    _queue.add((itemId, archive));
    _pump();
  }

  /// Drops everything: a new guide was installed.
  void clear() {
    _data.clear();
    _withArchive.clear();
    notifyListeners();
  }

  /// Forces a refetch (e.g. the programme just ended).
  void refresh(int itemId) {
    final archive = _withArchive.remove(itemId);
    _data.remove(itemId);
    want(itemId, archive: archive);
  }

  void _pump() {
    while (_inFlight < _maxInFlight && _queue.isNotEmpty) {
      // Newest requests first: rows the user scrolled to most recently.
      final (id, archive) = _queue.removeLast();
      _inFlight++;
      _fetch(id, archive).then((list) {
        _data[id] = list;
        if (archive) _withArchive.add(id);
      }).catchError((_) {
        _data[id] = const [];
      }).whenComplete(() {
        _inFlight--;
        _pending.remove(id);
        notifyListeners();
        _pump();
      });
    }
  }

  /// Archive first: it refreshes the core's cache, so the EPG call after it
  /// is served locally. Merged oldest first, the archive's copy winning.
  Future<List<Programme>> _fetch(int id, bool archive) async {
    if (!archive) return tidyProgrammes(await library.epg(id));
    final past = await library.archive(id);
    final upcoming = await library.epg(id);
    final starts = {for (final p in past) p.start};
    return tidyProgrammes([...past.reversed, ...upcoming.where((p) => !starts.contains(p.start))]);
  }
}

/// One channel's programmes in order with no overlaps. Providers that merge
/// two guides send each show twice, 10-15 minutes apart ("Seksenler
/// 13:15-14:20" and "Seksenler 13:30-14:10"): copies with the same title
/// become one, and a show that runs into the next ends where the next starts.
List<Programme> tidyProgrammes(List<Programme> list) {
  final sorted = [...list]..sort((a, b) => a.start != b.start ? a.start.compareTo(b.start) : b.stop.compareTo(a.stop));
  String key(Programme p) => p.title.trim().toLowerCase();
  final out = <Programme>[];
  for (final p in sorted) {
    if (p.stop <= p.start) continue;
    final last = out.isEmpty ? null : out.last;
    if (last == null || p.start >= last.stop) {
      out.add(p);
    } else if (key(p) == key(last)) {
      out.last = Programme(
        start: last.start,
        stop: p.stop > last.stop ? p.stop : last.stop,
        title: last.title,
        description: last.description.isNotEmpty ? last.description : p.description,
        archive: last.archive || p.archive,
      );
    } else if (p.start == last.start) {
      // Same start, different show: the longer one (sorted first) stays.
      continue;
    } else {
      out.last = Programme(start: last.start, stop: p.start, title: last.title, description: last.description, archive: last.archive);
      out.add(p);
    }
  }
  return out;
}

/// 0..1 progress of [p] at the current time.
double programmeProgress(Programme p) {
  final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final len = p.stop - p.start;
  if (len <= 0) return 0;
  return ((t - p.start) / len).clamp(0, 1).toDouble();
}

/// Minutes left in [p].
int minutesLeft(Programme p) {
  final t = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  return ((p.stop - t) / 60).ceil().clamp(0, 1 << 30);
}
