import 'dart:async';

import 'package:flutter/foundation.dart';

import 'library.dart';

/// Programme reminders of the active source. One timer, set for the next
/// one due; when it fires, [due] holds the reminder until the banner is
/// dismissed (or the programme ends).
class Reminders extends ChangeNotifier {
  Reminders(this.library, {this.lead = const Duration(minutes: 1), DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final LibraryApi library;

  /// How long before the start the reminder shows.
  final Duration lead;
  final DateTime Function() _clock;

  /// Called when a reminder comes due (the taskbar button flashes).
  void Function(Reminder r)? onDue;

  String? _sourceId;
  List<Reminder> list = const [];
  Reminder? due;
  final _fired = <String>{};
  Timer? _timer;

  static String _key(int uid, int start) => '$uid:$start';

  int get _now => _clock().millisecondsSinceEpoch ~/ 1000;

  Future<void> load(String? sourceId) async {
    _sourceId = sourceId;
    list = sourceId == null ? const [] : await library.reminders(sourceId);
    _schedule();
    notifyListeners();
  }

  bool isSet(Item item, Programme p) => list.any((r) => r.item.uid == item.uid && r.start == p.start);

  Future<void> toggle(Item item, Programme p) async {
    final on = !isSet(item, p);
    await library.setReminder(item.id, p.start, p.stop, p.title, on: on);
    await load(_sourceId);
  }

  void dismiss() {
    due = null;
    notifyListeners();
  }

  void _schedule() {
    _timer?.cancel();
    final now = _now;
    if (due case final d? when d.stop <= now) due = null;
    for (final r in list) {
      if (_fired.contains(_key(r.item.uid, r.start)) || r.stop <= now) continue;
      final wait = Duration(seconds: r.start - now) - lead;
      _timer = Timer(wait.isNegative ? Duration.zero : wait, () => _fire(r));
      return;
    }
  }

  void _fire(Reminder r) {
    _fired.add(_key(r.item.uid, r.start));
    due = r;
    onDue?.call(r);
    notifyListeners();
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
