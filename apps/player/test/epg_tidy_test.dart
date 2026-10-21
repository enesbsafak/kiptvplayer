// Guide data from providers that merge two guides: every show twice, a few
// minutes apart. The cache keeps one copy and no overlaps.

import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/app/paging.dart';

Programme _p(String from, String to, String title, {bool archive = false}) {
  int at(String hm) {
    final [h, m] = hm.split(':').map(int.parse).toList();
    return DateTime(2026, 10, 21, h, m).millisecondsSinceEpoch ~/ 1000;
  }

  return Programme(start: at(from), stop: at(to), title: title, description: '', archive: archive);
}

String _show(List<Programme> list) => list.map((p) {
      String hm(int t) {
        final d = DateTime.fromMillisecondsSinceEpoch(t * 1000);
        return '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
      }

      return '${hm(p.start)}-${hm(p.stop)} ${p.title}';
    }).join(' | ');

void main() {
  test('doubled shows merge and overlaps end where the next show starts', () {
    // TRT 1 as one provider sends it.
    final raw = [
      _p('07:15', '10:30', 'Kalk Gidelim', archive: true),
      _p('07:30', '10:30', 'Kalk Gidelim', archive: true),
      _p('10:30', '13:30', 'Alişan ile Hayata Gülümse'),
      _p('13:15', '14:20', 'Seksenler'),
      _p('13:30', '14:10', 'Seksenler'),
      _p('14:10', '17:45', 'Alparslan: Büyük Selçuklu'),
      _p('14:20', '17:30', 'Alparslan: Büyük Selçuklu'),
      _p('17:30', '18:55', 'Lingo Türkiye'),
      _p('17:45', '19:00', 'Lingo Türkiye'),
    ];
    final tidy = tidyProgrammes(raw);
    expect(
      _show(tidy),
      '07:15-10:30 Kalk Gidelim | 10:30-13:15 Alişan ile Hayata Gülümse | 13:15-14:10 Seksenler | '
      '14:10-17:30 Alparslan: Büyük Selçuklu | 17:30-19:00 Lingo Türkiye',
    );
    expect(tidy.first.archive, isTrue);
    for (var i = 1; i < tidy.length; i++) {
      expect(tidy[i].start, greaterThanOrEqualTo(tidy[i - 1].stop));
    }
  });

  test('a long show cut short by the next; same start keeps the longer; empty ones go', () {
    final tidy = tidyProgrammes([
      _p('12:00', '12:30', 'Akustik Sırlar'),
      _p('11:30', '13:00', 'Monet\'nin Nilüferleri'),
      _p('11:45', '12:00', 'Yeryüzleri'),
      _p('12:30', '13:00', 'Sinematograf'),
      _p('12:30', '12:40', 'Kısa'),
      _p('13:00', '13:00', 'Boş'),
    ]);
    expect(
      _show(tidy),
      '11:30-11:45 Monet\'nin Nilüferleri | 11:45-12:00 Yeryüzleri | 12:00-12:30 Akustik Sırlar | 12:30-13:00 Sinematograf',
    );
  });

  test('clean guides pass through unchanged', () {
    final clean = [_p('10:00', '11:00', 'A'), _p('11:00', '12:00', 'B'), _p('13:00', '14:00', 'C')];
    expect(tidyProgrammes(clean), clean);
  });
}
