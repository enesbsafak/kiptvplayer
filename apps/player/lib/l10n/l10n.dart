import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// The app's strings in the chosen language, reachable from widgets and
/// from plain code (player, track labels, formatters) alike. The app root
/// rebuilds when the language changes, so every screen picks it up.
AppLocalizations get l10n => _current;
AppLocalizations _current = lookupAppLocalizations(const Locale('tr'));

/// "tr" or "en"; anything else falls back to English.
void setLanguage(String code) {
  _current = lookupAppLocalizations(Locale(code == 'tr' ? 'tr' : 'en'));
}

String get languageCode => _current.localeName;
