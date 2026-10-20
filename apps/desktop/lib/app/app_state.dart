import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'library.dart';

enum Section { home, live, guide, movies, series, search, favorites, settings }

/// App-wide state: sources, the active one, and where the user is.
class AppState extends ChangeNotifier {
  AppState(this.library);

  final LibraryApi library;

  List<SourceInfo> sources = const [];
  String? activeSourceId;
  Section section = Section.home;
  bool loaded = false;

  /// Bumped after a sync so screens reload their lists.
  int catalogVersion = 0;

  SourceInfo? get activeSource {
    for (final s in sources) {
      if (s.id == activeSourceId) return s;
    }
    return sources.isEmpty ? null : sources.first;
  }

  /// Region whose categories and channels come first (e.g. "TR").
  String? region;

  Future<void> load() async {
    final pref = await library.regionPreference();
    if (pref.chosen) {
      region = pref.region;
    } else {
      // First run: the OS locale decides (tr_TR → TR); changeable later.
      region = _localeRegion();
      await library.setRegionPreference(region);
    }
    sources = await library.sources();
    activeSourceId ??= sources.isEmpty ? null : sources.first.id;
    loaded = true;
    notifyListeners();
  }

  void go(Section s) {
    if (section == s) return;
    section = s;
    pendingDetail = null;
    notifyListeners();
  }

  /// Movie / series to show in its section's detail view, set by screens
  /// outside that section (home, search, favourites).
  Item? pendingDetail;
  int detailNonce = 0;

  void openDetail(Item item, Kind kind) {
    pendingDetail = item;
    detailNonce++;
    section = kind == Kind.series ? Section.series : Section.movies;
    notifyListeners();
  }

  void selectSource(String id) {
    activeSourceId = id;
    catalogVersion++;
    notifyListeners();
  }

  /// Called when an add/sync stream finished successfully.
  Future<void> sourceChanged(SourceInfo source) async {
    sources = await library.sources();
    activeSourceId = source.id;
    catalogVersion++;
    notifyListeners();
  }

  Future<void> setRegion(String? value) async {
    await library.setRegionPreference(value);
    region = value;
    catalogVersion++;
    notifyListeners();
  }

  Future<void> removeSource(String id) async {
    await library.removeSource(id);
    sources = await library.sources();
    if (activeSourceId == id) {
      activeSourceId = sources.isEmpty ? null : sources.first.id;
    }
    catalogVersion++;
    notifyListeners();
  }
}

String? _localeRegion() {
  // Platform.localeName looks like "tr_TR", "tr-TR" or "en_US.UTF-8".
  final parts = Platform.localeName.split(RegExp(r'[_\-.]'));
  if (parts.length < 2) return null;
  final country = parts[1].toUpperCase();
  return country.length == 2 ? (country == 'GB' ? 'UK' : country) : null;
}
