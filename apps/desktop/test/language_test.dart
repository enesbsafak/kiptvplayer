// Turkish / English: the choice reaches the strings, the formats and the core.

import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/app_state.dart';
import 'package:karadelik_player/design/widgets/kd_controls.dart';
import 'package:karadelik_player/design/widgets/kd_widgets.dart';
import 'package:karadelik_player/l10n/l10n.dart';
import 'package:karadelik_player/shell/sidebar.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

void main() {
  tearDown(() => setLanguage('tr'));

  testWidgets('English everywhere once chosen, and the core is told', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()]);
    final h = TestHarness(lib);
    await h.state.load();
    expect(h.state.language.value, 'tr');
    expect(lib.coreLanguage, 'tr');

    await h.state.setLanguage('en');
    await tester.pumpWidget(app(h, const Sidebar()));
    await tester.pumpAndSettle();
    expect(find.text('Live TV'), findsOneWidget);
    expect(find.text('LIBRARY'), findsOneWidget, reason: 'English upper case has no dotted İ');
    expect(lib.coreLanguage, 'en');
    expect(lib.uiLanguageChoice, 'en');
    expect(kdDuration(3900), '1 h 05 min');
    expect(kdUpper('list'), 'LIST');

    await h.state.setLanguage(null); // follow the system (tr_TR in tests)
    expect(h.state.language.value, 'tr');
    expect(lib.uiLanguageChoice, isNull);
    expect(kdDuration(3900), '1 sa 05 dk');
  });

  test('an English system starts in English, a stored choice wins over it', () async {
    final lib = FakeLibrary();
    final h = TestHarness(lib);
    AppState.systemLocale = () => 'en_US';
    await h.state.load();
    expect(languageCode, 'en');

    lib.uiLanguageChoice = 'tr';
    await TestHarness(lib).state.load();
    expect(languageCode, 'tr');
  });
}
