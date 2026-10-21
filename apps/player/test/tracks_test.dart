// Track labels: the "TUR TUR TUR / ENG ENG ENG" picker from a real stream.

import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/player/media_track.dart';

void main() {
  // What mpv's track-list looks like for a typical provider movie.
  const trackList = '''[
    {"id":1,"type":"video","codec":"h264","selected":true},
    {"id":1,"type":"audio","lang":"tur","codec":"eac3","demux-channel-count":6,"default":true,"selected":true},
    {"id":2,"type":"audio","lang":"eng","codec":"aac","demux-channel-count":2},
    {"id":1,"type":"sub","lang":"tur","codec":"subrip","forced":true},
    {"id":2,"type":"sub","lang":"tur","codec":"subrip"},
    {"id":3,"type":"sub","lang":"tur","codec":"hdmv_pgs_subtitle"},
    {"id":4,"type":"sub","lang":"eng","codec":"subrip","title":"English","selected":true},
    {"id":5,"type":"sub","lang":"eng","codec":"subrip","hearing-impaired":true},
    {"id":6,"type":"sub","lang":"eng","codec":"subrip","title":"Commentary"}
  ]''';

  test('parses audio and subtitle tracks with their flags, skipping video', () {
    final tracks = MediaTrack.parseTrackList(trackList);
    expect(tracks.where((t) => t.kind == TrackKind.audio), hasLength(2));
    expect(tracks.where((t) => t.kind == TrackKind.subtitle), hasLength(6));
    expect(tracks.firstWhere((t) => t.kind == TrackKind.audio).selected, isTrue);
    expect(tracks.firstWhere((t) => t.kind == TrackKind.subtitle).forced, isTrue);
    expect(MediaTrack.parseTrackList('not json'), isEmpty);
  });

  test('same-language tracks get what tells them apart', () {
    final tracks = MediaTrack.parseTrackList(trackList);
    String show(TrackKind k) =>
        trackLabels(tracks.where((t) => t.kind == k).toList()).map((l) => '${l.name} (${l.detail})').join(', ');
    expect(show(TrackKind.audio), 'Türkçe (5.1 · E-AC-3), İngilizce (Stereo · AAC)');
    expect(
      show(TrackKind.subtitle),
      'Türkçe (Zorunlu · SRT), Türkçe (SRT), Türkçe (PGS), '
      'İngilizce (SRT), İngilizce (SDH · SRT), İngilizce (Commentary · SRT)',
    );
  });

  test('truly identical tracks are numbered, unknown ones still named', () {
    const twins = MediaTrack(id: '1', kind: TrackKind.subtitle, lang: 'TUR');
    final labels = trackLabels([twins, twins, const MediaTrack(id: '3', kind: TrackKind.subtitle)]);
    expect(labels.map((l) => '${l.name}|${l.detail}'), ['Türkçe|#1', 'Türkçe|#2', 'Parça 3|']);
  });
}
