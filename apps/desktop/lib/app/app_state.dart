import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart' as l10n;
import 'library.dart';
import 'reminders.dart';

enum Section { home, live, guide, movies, series, search, favorites, settings }

/// App-wide state: sources, the active one, and where the user is.
class AppState extends ChangeNotifier {
  AppState(this.library);

  final LibraryApi library;

  /// Parental lock: whether a PIN exists and adult content is hidden.
  Parental parental = const Parental(pinSet: false, locked: false);

  Future<bool> unlockAdult(String pin) async {
    final ok = await library.unlockAdult(pin);
    if (ok) await _parentalChanged();
    return ok;
  }

  Future<void> lockAdult() async {
    await library.lockAdult();
    await _parentalChanged();
  }

  Future<void> setPin({String? current, String? pin}) async {
    await library.setParentalPin(current: current, pin: pin);
    await _parentalChanged();
  }

  /// Lists, shelves and search change with the lock: reload them.
  Future<void> _parentalChanged() async {
    parental = await library.parental();
    catalogVersion++;
    notifyListeners();
    unawaited(reminders.load(activeSource?.id));
  }

  /// Programme reminders of the active source.
  late final reminders = Reminders(library);

  List<SourceInfo> sources = const [];
  String? activeSourceId;
  Section section = Section.home;
  bool loaded = false;

  /// Bumped after a sync so screens reload their lists.
  int catalogVersion = 0;

  /// Bumped when an XMLTV guide was replaced: cached now/next is stale.
  int guideVersion = 0;

  /// Guides older than this are fetched again in the background at start.
  static const guideMaxAge = Duration(hours: 12);

  SourceInfo? get activeSource {
    for (final s in sources) {
      if (s.id == activeSourceId) return s;
    }
    return sources.isEmpty ? null : sources.first;
  }

  /// Region whose categories and channels come first (e.g. "TR").
  String? region;

  /// The language the user picked ("tr", "en"); null follows the system.
  String? languageChoice;

  /// The language in use; the app root rebuilds when it changes.
  final language = ValueNotifier<String>('tr');

  /// Test hook: the OS locale (e.g. "tr_TR", "en_US").
  static String Function() systemLocale = () => Platform.localeName;

  Future<void> setLanguage(String? choice) async {
    languageChoice = choice;
    await _applyLanguage();
    notifyListeners();
  }

  Future<void> _applyLanguage() async {
    final effective = languageChoice ?? (systemLocale().toLowerCase().startsWith('tr') ? 'tr' : 'en');
    l10n.setLanguage(effective);
    await library.setUiLanguage(languageChoice, effective);
    language.value = effective;
  }

  Future<void> load() async {
    languageChoice = await library.uiLanguage();
    await _applyLanguage();
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
    parental = await library.parental();
    loaded = true;
    notifyListeners();
    unawaited(reminders.load(activeSource?.id));
    _refreshStaleGuides();
  }

  /// One M3U source at a time, quietly: the old guide serves meanwhile.
  Future<void> _refreshStaleGuides() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    for (final s in sources) {
      final g = s.guide;
      final stale = g == null || now - g.at > guideMaxAge.inSeconds;
      if (s.kind != SourceType.m3U || s.epgUrl == null || !stale) continue;
      try {
        await library.refreshGuide(s.id);
        await guideUpdated();
      } catch (_) {
        // Recorded in the source's guide status; the next start retries.
      }
    }
  }

  /// Watch history was cleared: screens showing it reload.
  void historyCleared() {
    catalogVersion++;
    notifyListeners();
  }

  /// A guide was replaced (refresh button or background): reload sources
  /// and let screens fetch now/next again, without switching sources.
  Future<void> guideUpdated() async {
    sources = await library.sources();
    guideVersion++;
    catalogVersion++;
    notifyListeners();
  }

  /// Settings tab to open on the next visit ("about" from the update badge).
  String? settingsTab;

  void openSettings(String tab) {
    settingsTab = tab;
    section = Section.settings;
    pendingDetail = null;
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
    unawaited(reminders.load(id));
  }

  /// Called when an add/sync stream finished successfully.
  Future<void> sourceChanged(SourceInfo source) async {
    sources = await library.sources();
    activeSourceId = source.id;
    catalogVersion++;
    notifyListeners();
    unawaited(reminders.load(source.id));
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
  // The OS locale looks like "tr_TR", "tr-TR" or "en_US.UTF-8".
  final parts = AppState.systemLocale().split(RegExp(r'[_\-.]'));
  if (parts.length < 2) return null;
  final country = parts[1].toUpperCase();
  return country.length == 2 ? (country == 'GB' ? 'UK' : country) : null;
}
