// Programme reminders: set from the guide's dialog, fired a minute ahead
// on a virtual clock, shown as a banner that opens the channel.

import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:karadelik_player/app/library.dart';
import 'package:karadelik_player/app/reminders.dart';
import 'package:karadelik_player/screens/guide_screen.dart';
import 'package:karadelik_player/shell/reminder_banner.dart';

import 'fakes.dart';
import 'widgets_test.dart' show app, setLargeWindow;

void main() {
  final trt = FakeLibrary.item(10, 'TRT 1');

  test('a reminder fires a minute before the start, once', () {
    fakeAsync((async) {
      final clock = async.getClock(DateTime.utc(2026, 10, 21, 20));
      final now = clock.now().millisecondsSinceEpoch ~/ 1000;
      final lib = FakeLibrary();
      final reminders = Reminders(lib, clock: clock.now);
      final fired = <String>[];
      reminders.onDue = (r) => fired.add(r.title);

      reminders.load('s1');
      async.flushMicrotasks();
      final news = Programme(start: now + 600, stop: now + 2400, title: 'Haberler', description: '', archive: false);
      final film = Programme(start: now + 3600, stop: now + 9000, title: 'Film', description: '', archive: false);
      reminders.toggle(trt, news);
      async.flushMicrotasks();
      reminders.toggle(trt, film);
      async.flushMicrotasks();
      expect(reminders.isSet(trt, news), isTrue);

      async.elapse(const Duration(minutes: 8, seconds: 59));
      expect(fired, isEmpty);
      async.elapse(const Duration(seconds: 1)); // 9 min: one minute ahead
      expect(fired, ['Haberler']);
      expect(reminders.due?.title, 'Haberler');
      reminders.dismiss();
      expect(reminders.due, isNull);

      async.elapse(const Duration(minutes: 50));
      expect(fired, ['Haberler', 'Film'], reason: 'the next one, and the first only once');
      reminders.dispose();
    });
  });

  testWidgets('the guide dialog sets and clears a reminder', (tester) async {
    await setLargeWindow(tester);
    final lib = FakeLibrary(sources: [FakeLibrary.source()]);
    final h = TestHarness(lib);
    await h.state.load();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final p = Programme(start: now + 3600, stop: now + 7200, title: 'Maç Önü', description: 'Stüdyo programı.', archive: false);
    await tester.pumpWidget(app(h, Builder(
      builder: (context) => TextButton(
        onPressed: () => showDialog<void>(context: context, builder: (_) => ProgrammeDialog(item: trt, programme: p, onWatch: () {})),
        child: const Text('aç'),
      ),
    )));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.text('Stüdyo programı.'), findsOneWidget);

    await tester.tap(find.text('Hatırlat'));
    await tester.pumpAndSettle();
    expect(lib.reminderList.single.title, 'Maç Önü');
    expect(h.state.reminders.isSet(trt, p), isTrue);

    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hatırlatmayı kaldır'));
    await tester.pumpAndSettle();
    expect(lib.reminderList, isEmpty);
    h.state.reminders.dispose();
  });

  testWidgets('a due reminder shows a banner that opens the channel', (tester) async {
    await setLargeWindow(tester);
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final lib = FakeLibrary(sources: [FakeLibrary.source()])
      ..reminderList = [Reminder(item: trt, start: now + 30, stop: now + 1800, title: 'Akşam Haberleri')];
    final h = TestHarness(lib);
    await h.state.load();
    await tester.pumpWidget(app(h, const Align(alignment: Alignment.topRight, child: ReminderBanner())));
    await tester.pump(const Duration(milliseconds: 10));
    await tester.pump(const Duration(milliseconds: 10));
    expect(h.state.reminders.list, hasLength(1));
    expect(find.text('Akşam Haberleri'), findsOneWidget);
    expect(find.textContaining('başlıyor'), findsOneWidget);

    await tester.tap(find.text('İzle'));
    await tester.pump();
    expect(find.text('Akşam Haberleri'), findsNothing);
    expect(h.engine.opened, hasLength(1));
    h.state.reminders.dispose();
  });
}
