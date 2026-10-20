import 'dart:convert';

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
    final name = language ?? title ?? 'Parça ${i + 1}';
    final detail = <String>[
      if (title != null && language != null && !titleIsLanguage) title,
      if (t.forced) 'Zorunlu',
      if (t.hearingImpaired) 'SDH',
      if (t.kind == TrackKind.audio && t.channels != null) _channels(t.channels!),
      ?_codecName(t.codec),
      if (t.external) 'Harici',
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
  _ => '$n kanal',
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
  'mov_text' => 'Metin',
  'hdmv_pgs_subtitle' => 'PGS',
  'dvd_subtitle' => 'VobSub',
  'dvb_subtitle' => 'DVB',
  'dvb_teletext' => 'Teletext',
  _ when codec.startsWith('pcm') => 'PCM',
  _ => codec.toUpperCase(),
};

/// Turkish name for an ISO 639-1/-2 code ("tur", "tr", "TUR") or an English
/// language name ("Turkish"); null when unknown.
String? languageName(String? code) {
  if (code == null) return null;
  return _languages[_norm(code)];
}

const _languages = {
  'tur': 'Türkçe', 'tr': 'Türkçe', 'turkish': 'Türkçe', 'türkçe': 'Türkçe',
  'eng': 'İngilizce', 'en': 'İngilizce', 'english': 'İngilizce',
  'ger': 'Almanca', 'deu': 'Almanca', 'de': 'Almanca', 'german': 'Almanca',
  'fre': 'Fransızca', 'fra': 'Fransızca', 'fr': 'Fransızca', 'french': 'Fransızca',
  'spa': 'İspanyolca', 'es': 'İspanyolca', 'spanish': 'İspanyolca',
  'ita': 'İtalyanca', 'it': 'İtalyanca', 'italian': 'İtalyanca',
  'por': 'Portekizce', 'pt': 'Portekizce', 'portuguese': 'Portekizce',
  'rus': 'Rusça', 'ru': 'Rusça', 'russian': 'Rusça',
  'ara': 'Arapça', 'ar': 'Arapça', 'arabic': 'Arapça',
  'dut': 'Felemenkçe', 'nld': 'Felemenkçe', 'nl': 'Felemenkçe', 'dutch': 'Felemenkçe',
  'jpn': 'Japonca', 'ja': 'Japonca', 'japanese': 'Japonca',
  'kor': 'Korece', 'ko': 'Korece', 'korean': 'Korece',
  'chi': 'Çince', 'zho': 'Çince', 'zh': 'Çince', 'chinese': 'Çince',
  'gre': 'Yunanca', 'ell': 'Yunanca', 'el': 'Yunanca', 'greek': 'Yunanca',
  'pol': 'Lehçe', 'pl': 'Lehçe', 'polish': 'Lehçe',
  'swe': 'İsveççe', 'sv': 'İsveççe', 'swedish': 'İsveççe',
  'nor': 'Norveççe', 'nob': 'Norveççe', 'no': 'Norveççe', 'norwegian': 'Norveççe',
  'dan': 'Danca', 'da': 'Danca', 'danish': 'Danca',
  'fin': 'Fince', 'fi': 'Fince', 'finnish': 'Fince',
  'hun': 'Macarca', 'hu': 'Macarca', 'hungarian': 'Macarca',
  'cze': 'Çekçe', 'ces': 'Çekçe', 'cs': 'Çekçe', 'czech': 'Çekçe',
  'rum': 'Rumence', 'ron': 'Rumence', 'ro': 'Rumence', 'romanian': 'Rumence',
  'bul': 'Bulgarca', 'bg': 'Bulgarca', 'bulgarian': 'Bulgarca',
  'ukr': 'Ukraynaca', 'uk': 'Ukraynaca', 'ukrainian': 'Ukraynaca',
  'heb': 'İbranice', 'he': 'İbranice', 'hebrew': 'İbranice',
  'per': 'Farsça', 'fas': 'Farsça', 'fa': 'Farsça', 'persian': 'Farsça',
  'hin': 'Hintçe', 'hi': 'Hintçe', 'hindi': 'Hintçe',
  'aze': 'Azerice', 'az': 'Azerice', 'azerbaijani': 'Azerice',
  'kur': 'Kürtçe', 'ku': 'Kürtçe', 'kurdish': 'Kürtçe',
  'alb': 'Arnavutça', 'sqi': 'Arnavutça', 'sq': 'Arnavutça', 'albanian': 'Arnavutça',
  'srp': 'Sırpça', 'sr': 'Sırpça', 'serbian': 'Sırpça',
  'hrv': 'Hırvatça', 'hr': 'Hırvatça', 'croatian': 'Hırvatça',
  'bos': 'Boşnakça', 'bs': 'Boşnakça', 'bosnian': 'Boşnakça',
  'und': 'Bilinmeyen dil',
};
