// Ctrl+K command palette: commands, library results and channel numbers
// in one box, driven by the keyboard.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/app_state.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/shell/command_palette.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

Future<TestHarness> _open(WidgetTester tester) async {
  await setLargeWindow(tester);
  final lib = FakeLibrary(sources: [FakeLibrary.source(), FakeLibrary.source(id: 's2', name: 'Yedek')])
    ..items[Kind.live] = [
      Item(id: 10, uid: 10, name: 'TRT 1', adult: false, sort: 1, chno: 1, hasCatchup: false),
      Item(id: 11, uid: 11, name: 'Kanal D', adult: false, sort: 2, chno: 12, hasCatchup: false),
    ]
    ..items[Kind.movie] = [FakeLibrary.item(50, 'Dünya Filmi')];
  final h = TestHarness(lib);
  await h.state.load();
  await tester.pumpWidget(app(h, Builder(
    builder: (context) => TextButton(onPressed: () => showCommandPalette(context), child: const Text('palet')),
  )));
  await tester.tap(find.text('palet'));
  await tester.pumpAndSettle();
  return h;
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(const Duration(milliseconds: 150)); // debounce
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('commands match Turkish-insensitively and run on Enter', (tester) async {
    final h = await _open(tester);
    expect(find.text('KOMUTLAR'), findsOneWidget, reason: 'section labels are upper case');
    expect(find.text('Ana Sayfa'), findsOneWidget);

    await _type(tester, 'AYARLAR');
    expect(find.text('Ayarlar'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(CommandPalette), findsNothing);
    expect(h.state.section, Section.settings);
  });

  testWidgets('library results follow the commands; arrows pick one', (tester) async {
    final h = await _open(tester);
    await _type(tester, 'film');
    expect(find.text('Filmler'), findsWidgets, reason: 'the section command and the group');
    expect(find.text('Dünya Filmi'), findsOneWidget);
    // Commands first ("Filmler"), then the film.
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(h.state.section, Section.movies);
    expect(h.state.pendingDetail?.name, 'Dünya Filmi');
  });

  testWidgets('a number opens that channel; another source is one step away', (tester) async {
    final h = await _open(tester);
    await _type(tester, '12');
    expect(find.text('KANAL NUMARASI'), findsOneWidget);
    expect(find.text('Kanal D'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(h.engine.opened, hasLength(1));
    expect(h.player.now?.item.name, 'Kanal D');

    await tester.tap(find.text('palet'));
    await tester.pumpAndSettle();
    await _type(tester, 'yedek');
    await tester.tap(find.text('Kaynağa geç: Yedek'));
    await tester.pumpAndSettle();
    expect(h.state.activeSourceId, 's2');
  });
}
