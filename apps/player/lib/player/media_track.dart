import 'dart:convert';

import '../l10n/l10n.dart';

enum TrackKind { audio, subtitle }

/// One audio or subtitle track as mpv reports it in `track-list`, with the
/// flags media_kit's own model drops (forced, SDH, selected).
class MediaTrack {
  const MediaTrack({
    required this.id,
    required this.kind,
    this.title,
    this.lang,
    this.codec,
    this.channels,
    this.isDefault = false,
    this.forced = false,
    this.hearingImpaired = false,
    this.external = false,
    this.selected = false,
  });

  final String id;
  final TrackKind kind;
  final String? title;
  final String? lang;
  final String? codec;
  final int? channels;
  final bool isDefault;
  final bool forced;
  final bool hearingImpaired;
  final bool external;
  final bool selected;

  /// Parses mpv's `track-list` JSON; video tracks and junk are skipped.
  static List<MediaTrack> parseTrackList(String json) {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      return const [];
    }
    if (decoded is! List) return const [];
    final out = <MediaTrack>[];
    for (final t in decoded) {
      if (t is! Map) continue;
      final kind = switch (t['type']) {
        'audio' => TrackKind.audio,
        'sub' => TrackKind.subtitle,
        _ => null,
      };
      final id = t['id'];
      if (kind == null || id == null) continue;
      String? str(String k) => switch (t[k]) {
        final String s when s.trim().isNotEmpty => s.trim(),
        _ => null,
      };
      bool flag(String k) => t[k] == true;
      out.add(MediaTrack(
        id: '$id',
        kind: kind,
        title: str('title'),
        lang: str('lang'),
        codec: str('codec'),
        channels: switch (t['demux-channel-count'] ?? t['audio-channels']) {
          final num n => n.toInt(),
          _ => null,
        },
        isDefault: flag('default'),
        forced: flag('forced'),
        hearingImpaired: flag('hearing-impaired'),
        external: flag('external'),
        selected: flag('selected'),
      ));
    }
    return out;
  }
}

/// A track's name and what tells it apart from its siblings.
class TrackLabel {
  const TrackLabel(this.name, this.detail);

  /// "Türkçe", or the provider's title when it names no language.
  final String name;

  /// "Zorunlu · SRT", "5.1 · AC-3"; empty when nothing to add.
  final String detail;
}

/// Labels for [tracks] of one kind, in order. Several tracks in the same
/// language ("TUR TUR TUR") get what differs between them (forced, SDH,
/// format, channels, the provider's title) and, as a last resort, a number.
List<TrackLabel> trackLabels(List<MediaTrack> tracks) {
  final raw = <(String, List<String>)>[];
  for (final (i, t) in tracks.indexed) {
    final language = languageName(t.lang);
    final title = t.title;
    // A title that only repeats the language ("Turkish", "TUR") adds nothing.
    final titleIsLanguage = title != null &&
        language != null &&
        (_norm(title) == _norm(language) || _norm(title) == _norm(t.lang ?? '') || languageName(title) == language);
    final name = language ?? title ?? l10n.trackN(i + 1);
    final detail = <String>[
      if (title != null && language != null && !titleIsLanguage) title,
      if (t.forced) l10n.trackForced,
      if (t.hearingImpaired) 'SDH',
      if (t.kind == TrackKind.audio && t.channels != null) _channels(t.channels!),
      ?_codecName(t.codec),
      if (t.external) l10n.trackExternal,
    ];
    raw.add((name, detail));
  }
  // Still identical? Number them within their group.
  final seen = <String, int>{};
  final counts = <String, int>{};
  for (final (n, d) in raw) {
    counts.update('$n|${d.join('|')}', (c) => c + 1, ifAbsent: () => 1);
  }
  return [
    for (final (n, d) in raw)
      () {
        final key = '$n|${d.join('|')}';
        if (counts[key]! < 2) return TrackLabel(n, d.join(' · '));
        final k = seen.update(key, (c) => c + 1, ifAbsent: () => 1);
        return TrackLabel(n, [...d, '#$k'].join(' · '));
      }(),
  ];
}

String _norm(String s) => s.trim().toLowerCase();

String _channels(int n) => switch (n) {
  1 => 'Mono',
  2 => 'Stereo',
  6 => '5.1',
  8 => '7.1',
  _ => l10n.trackChannels(n),
};

String? _codecName(String? codec) => switch (codec) {
  null => null,
  'aac' => 'AAC',
  'ac3' => 'AC-3',
  'eac3' => 'E-AC-3',
  'dts' => 'DTS',
  'truehd' => 'TrueHD',
  'mp3' => 'MP3',
  'mp2' => 'MP2',
  'opus' => 'Opus',
  'vorbis' => 'Vorbis',
  'flac' => 'FLAC',
  'subrip' => 'SRT',
  'ass' || 'ssa' => 'ASS',
  'webvtt' => 'WebVTT',
  'mov_text' => l10n.trackText,
  'hdmv_pgs_subtitle' => 'PGS',
  'dvd_subtitle' => 'VobSub',
  'dvb_subtitle' => 'DVB',
  'dvb_teletext' => 'Teletext',
  _ when codec.startsWith('pcm') => 'PCM',
  _ => codec.toUpperCase(),
};

/// The language's name in the UI language, for an ISO 639-1/-2 code
/// ("tur", "tr", "TUR") or an English or Turkish language name ("Turkish");
/// null when unknown.
String? languageName(String? code) {
  if (code == null) return null;
  final key = _norm(code);
  final names = _languages[_aliases[key] ?? key];
  if (names == null) return null;
  return languageCode == 'tr' ? names.$1 : names.$2;
}

/// ISO 639-2/B codes, 639-1 codes and names to one 639-2 key.
const _aliases = {
  'tr': 'tur', 'turkish': 'tur', 'türkçe': 'tur',
  'en': 'eng', 'english': 'eng', 'ingilizce': 'eng',
  'deu': 'ger', 'de': 'ger', 'german': 'ger',
  'fra': 'fre', 'fr': 'fre', 'french': 'fre',
  'es': 'spa', 'spanish': 'spa',
  'it': 'ita', 'italian': 'ita',
  'pt': 'por', 'portuguese': 'por',
  'ru': 'rus', 'russian': 'rus',
  'ar': 'ara', 'arabic': 'ara',
  'nld': 'dut', 'nl': 'dut', 'dutch': 'dut',
  'ja': 'jpn', 'japanese': 'jpn',
  'ko': 'kor', 'korean': 'kor',
  'zho': 'chi', 'zh': 'chi', 'chinese': 'chi',
  'ell': 'gre', 'el': 'gre', 'greek': 'gre',
  'pl': 'pol', 'polish': 'pol',
  'sv': 'swe', 'swedish': 'swe',
  'nob': 'nor', 'no': 'nor', 'norwegian': 'nor',
  'da': 'dan', 'danish': 'dan',
  'fi': 'fin', 'finnish': 'fin',
  'hu': 'hun', 'hungarian': 'hun',
  'ces': 'cze', 'cs': 'cze', 'czech': 'cze',
  'ron': 'rum', 'ro': 'rum', 'romanian': 'rum',
  'bg': 'bul', 'bulgarian': 'bul',
  'uk': 'ukr', 'ukrainian': 'ukr',
  'he': 'heb', 'hebrew': 'heb',
  'fas': 'per', 'fa': 'per', 'persian': 'per',
  'hi': 'hin', 'hindi': 'hin',
  'az': 'aze', 'azerbaijani': 'aze',
  'ku': 'kur', 'kurdish': 'kur',
  'sqi': 'alb', 'sq': 'alb', 'albanian': 'alb',
  'sr': 'srp', 'serbian': 'srp',
  'hr': 'hrv', 'croatian': 'hrv',
  'bs': 'bos', 'bosnian': 'bos',
};

const _languages = {
  'tur': ('Türkçe', 'Turkish'),
  'eng': ('İngilizce', 'English'),
  'ger': ('Almanca', 'German'),
  'fre': ('Fransızca', 'French'),
  'spa': ('İspanyolca', 'Spanish'),
  'ita': ('İtalyanca', 'Italian'),
  'por': ('Portekizce', 'Portuguese'),
  'rus': ('Rusça', 'Russian'),
  'ara': ('Arapça', 'Arabic'),
  'dut': ('Felemenkçe', 'Dutch'),
  'jpn': ('Japonca', 'Japanese'),
  'kor': ('Korece', 'Korean'),
  'chi': ('Çince', 'Chinese'),
  'gre': ('Yunanca', 'Greek'),
  'pol': ('Lehçe', 'Polish'),
  'swe': ('İsveççe', 'Swedish'),
  'nor': ('Norveççe', 'Norwegian'),
  'dan': ('Danca', 'Danish'),
  'fin': ('Fince', 'Finnish'),
  'hun': ('Macarca', 'Hungarian'),
  'cze': ('Çekçe', 'Czech'),
  'rum': ('Rumence', 'Romanian'),
  'bul': ('Bulgarca', 'Bulgarian'),
  'ukr': ('Ukraynaca', 'Ukrainian'),
  'heb': ('İbranice', 'Hebrew'),
  'per': ('Farsça', 'Persian'),
  'hin': ('Hintçe', 'Hindi'),
  'aze': ('Azerice', 'Azerbaijani'),
  'kur': ('Kürtçe', 'Kurdish'),
  'alb': ('Arnavutça', 'Albanian'),
  'srp': ('Sırpça', 'Serbian'),
  'hrv': ('Hırvatça', 'Croatian'),
  'bos': ('Boşnakça', 'Bosnian'),
  'und': ('Bilinmeyen dil', 'Unknown language'),
};
