// A channel's guide corrections from its right-click menu: shift in
// 15-minute steps and a hand-picked guide channel.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/screens/epg_settings.dart';
import 'package:karadelik_player/screens/live_screen.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

void main() {
  test('shifts read as hours and minutes', () {
    expect(shiftText(0), 'Kaydırma yok');
    expect(shiftText(90), '+1 sa 30 dk');
    expect(shiftText(-45), '−45 dk');
  });

  testWidgets('shift an hour later and pick another guide channel', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source(m3u: true)])..items[Kind.live] = [FakeLibrary.item(10, 'Kanal 1')];
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const LiveScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Kanal 1').first, buttons: kSecondaryButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yayın akışı ayarı…'));
    await tester.pumpAndSettle();
    expect(find.text('Otomatik: TRT 1'), findsOneWidget);

    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('+15'));
    }
    await tester.pump();
    expect(find.text('+1 sa'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, 'atv');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ATV'));
    await tester.pump();
    expect(find.text('Elle seçildi: ATV'), findsOneWidget);

    final version = h.state.guideVersion;
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(lib.epgOverrides[10], ('atv.tr', 60));
    expect(h.state.guideVersion, greaterThan(version), reason: 'cached now/next dropped');
  });
}
