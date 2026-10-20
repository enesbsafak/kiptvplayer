// TMDB: key entry in settings, and what the detail screen takes from it.

import 'package:flutter/widgets.dart' show EditableText;
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/screens/settings_screen.dart';
import 'package:karadelik_player/screens/vod_screen.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

TmdbInfo _info() => const TmdbInfo(
  id: 603,
  title: 'Matris',
  originalTitle: 'The Matrix',
  tagline: 'Gerçek nedir?',
  overview: 'TMDB özeti: bir programcı gerçeğin bir simülasyon olduğunu öğrenir.',
  genres: ['Aksiyon', 'Bilim Kurgu'],
  year: 1999,
  runtimeMin: 136,
  rating: 8.2,
  voteCount: 25400,
  certification: '13+',
  trailer: 'vKQi3bBA1y8',
  cast: [TmdbPerson(name: 'Keanu Reeves', role: 'Neo'), TmdbPerson(name: 'Carrie-Anne Moss', role: 'Trinity')],
  makers: ['Lana Wachowski', 'Lilly Wachowski'],
  seasons: 0,
);

void main() {
  testWidgets('a rejected key shows TMDB’s reason and is not saved; a good one is', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()]);
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const TmdbSettings()));
    await tester.pumpAndSettle();
    expect(find.text('KAPALI'), findsOneWidget);

    await tester.enterText(find.byType(EditableText), 'yanlis');
    await tester.tap(find.text('Doğrula ve kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('TMDB anahtarı geçersiz'), findsOneWidget);
    expect(lib.tmdbKey, isNull);

    await tester.enterText(find.byType(EditableText), FakeLibrary.goodTmdbKey);
    await tester.tap(find.text('Doğrula ve kaydet'));
    await tester.pumpAndSettle();
    expect(find.text('AÇIK'), findsOneWidget);
    expect(find.text('Anahtar doğrulandı ve kaydedildi.'), findsOneWidget);
    expect(lib.tmdbKey, FakeLibrary.goodTmdbKey);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(lib.tmdbLanguage, 'en-US');
  });

  testWidgets('with TMDB the detail shows its overview, cast, rating and trailer', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()])
      ..tmdbKey = FakeLibrary.goodTmdbKey
      ..tmdb[7] = _info();
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, DetailView(item: FakeLibrary.item(7, 'TR: Matrix (1999) 4K'), kind: Kind.movie, onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Matris'), findsOneWidget);
    expect(find.text('The Matrix'), findsOneWidget);
    expect(find.textContaining('TMDB özeti'), findsOneWidget);
    expect(find.text('Sağlayıcının özeti.'), findsNothing);
    expect(find.text('Keanu Reeves'), findsOneWidget);
    expect(find.text('13+'), findsOneWidget);
    expect(find.text('Fragman'), findsOneWidget);
    expect(find.text('Lana Wachowski, Lilly Wachowski'), findsOneWidget);
    expect(find.textContaining('25,4 B oy'), findsOneWidget);
  });

  testWidgets('without a key the provider’s detail is shown as before', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()])..tmdb[7] = _info();
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, DetailView(item: FakeLibrary.item(7, 'Matrix'), kind: Kind.movie, onBack: () {})));
    await tester.pumpAndSettle();

    expect(find.text('Sağlayıcının özeti.'), findsOneWidget);
    expect(find.text('Oyuncu Bir, Oyuncu İki'), findsOneWidget);
    expect(find.text('Keanu Reeves'), findsNothing);
    expect(find.text('Bilgiler: TMDB'), findsNothing);
  });
}
