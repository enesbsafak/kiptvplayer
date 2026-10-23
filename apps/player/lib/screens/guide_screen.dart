import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/paging.dart';
import '../app/scope.dart';
import '../design/layout.dart';
import '../design/widgets/kd_icon_button.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_category_rail.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_widgets.dart';
import '../l10n/l10n.dart';
import '../player/player_controller.dart';
import 'parental.dart';
import '../design/widgets/kd_focus.dart';

/// EPG grid: sticky channel column, time ruler, programme tiles, now line.
/// Going back in time shows catch-up channels' archive; those tiles replay.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  static const _row = 58.0;
  static const _channelCol = 220.0;
  static const _ruler = 32.0;
  static const _pxPerMin = 4.0;
  static const _hours = 4;
  static const _step = 2 * 3600;

  /// How far back the guide goes: the longest archive windows are 7 days.
  static const _maxBack = 7 * 86400;

  List<Category> _categories = const [];
  final _categoryMenu = MenuController();
  int? _category;
  ItemPager? _pager;
  late int _windowStart;
  final _vLeft = ScrollController();
  final _vRight = ScrollController();
  final _h = ScrollController();
  bool _syncing = false;
  Timer? _tick;
  String? _sourceId;
  int _version = -1;

  @override
  void initState() {
    super.initState();
    _windowStart = _startOfWindow();
    _vLeft.addListener(() => _sync(_vLeft, _vRight));
    _vRight.addListener(() => _sync(_vRight, _vLeft));
    // Redraw the now line and progress every 30 s.
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.app;
    final sid = app.activeSource?.id;
    if (sid != _sourceId || app.catalogVersion != _version) {
      _sourceId = sid;
      _version = app.catalogVersion;
      _load();
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _pager?.dispose();
    _vLeft.dispose();
    _vRight.dispose();
    _h.dispose();
    super.dispose();
  }

  int _startOfWindow() {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now - now % 1800 - 1800;
  }

  void _sync(ScrollController from, ScrollController to) {
    if (_syncing || !to.hasClients) return;
    _syncing = true;
    if ((to.offset - from.offset).abs() > 0.5) to.jumpTo(from.offset);
    _syncing = false;
  }

  Future<void> _load() async {
    final sid = _sourceId;
    if (sid == null) return;
    final cats = await context.library.categories(sid, Kind.live);
    if (!mounted) return;
    setState(() => _categories = cats);
    _select(cats.isEmpty ? null : cats.first.uid);
  }

  void _select(int? uid) {
    final sid = _sourceId;
    if (sid == null) return;
    _pager?.dispose();
    final pager = ItemPager(library: context.library, sourceId: sid, kind: Kind.live, categoryUid: uid, pageSize: 150)
      ..addListener(() => setState(() {}));
    setState(() {
      _category = uid;
      _pager = pager;
    });
    pager.loadMore();
    if (_vLeft.hasClients) _vLeft.jumpTo(0);
  }

  void _toNow() => _shift(null);

  /// Moves the window by [by] seconds, or back to now with null.
  void _shift(int? by) {
    final home = _startOfWindow();
    setState(() => _windowStart = by == null ? home : (_windowStart + by).clamp(home - _maxBack, home + 86400));
    if (_h.hasClients) _h.jumpTo(0);
  }

  @override
  Widget build(BuildContext context) {
    if (_sourceId == null) {
      return KdEmpty(title: l10n.sourceNone, hint: l10n.sourceNoneHint);
    }
    final items = _pager?.items ?? const <Item>[];
    final width = _hours * 60 * _pxPerMin;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final nowX = (now - _windowStart) / 60 * _pxPerMin;

    final compact = isCompact(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Flexible(
                child: Text(l10n.navGuide, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: KdType.display, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(_dayLabel(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KdColors.muted))),
              if (compact) ...[
                KdIconButton(icon: LucideIcons.chevronLeft, tooltip: l10n.guideEarlier, extent: 40, onPressed: () => _shift(-_step)),
                KdIconButton(icon: LucideIcons.clock, tooltip: l10n.guideNow, extent: 40, onPressed: _toNow),
                KdIconButton(icon: LucideIcons.chevronRight, tooltip: l10n.guideLater, extent: 40, onPressed: () => _shift(_step)),
              ] else ...[
                KdButton(label: l10n.guideEarlier, icon: LucideIcons.chevronLeft, onPressed: () => _shift(-_step)),
                const SizedBox(width: 6),
                KdButton(label: l10n.guideNow, icon: LucideIcons.clock, onPressed: _toNow),
                const SizedBox(width: 6),
                KdButton(label: l10n.guideLater, icon: LucideIcons.chevronRight, onPressed: () => _shift(_step)),
              ],
            ],
          ),
        ),
        // The grid needs the width, so the category list (the same one as
        // Live TV) opens from a button instead of taking a column.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(
            alignment: Alignment.centerLeft,
            child: MenuAnchor(
              controller: _categoryMenu,
              style: const MenuStyle(
                backgroundColor: WidgetStatePropertyAll(KdColors.bg2),
                padding: WidgetStatePropertyAll(EdgeInsets.zero),
                side: WidgetStatePropertyAll(BorderSide(color: KdColors.line)),
                shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(KdRadius.card)))),
              ),
              menuChildren: [
                SizedBox(
                  width: 320,
                  height: 460,
                  child: KdCategoryRail(
                    title: l10n.guidePickCategory,
                    autofocusFilter: true,
                    selected: _category,
                    onSelect: (id) {
                      _categoryMenu.close();
                      _select(id);
                    },
                    entries: [for (final c in _categories) KdRailEntry(id: c.uid, name: c.name, count: c.count)],
                    footer: const LockedCategoriesRow(kind: Kind.live),
                  ),
                ),
              ],
              builder: (context, controller, _) => KdButton(
                label: _categories.where((c) => c.uid == _category).map((c) => c.name).firstOrNull ?? l10n.guidePickCategory,
                icon: LucideIcons.listFilter,
                onPressed: () => controller.isOpen ? controller.close() : controller.open(),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        const Divider(height: 1, color: KdColors.line),
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n.metrics.axis == Axis.vertical && n.metrics.extentAfter < 600) _pager?.loadMore();
              return false;
            },
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  // Narrower on a phone, so programmes keep most of the width.
                  width: compact ? 128 : _channelCol,
                  child: Column(
                    children: [
                      Container(
                        height: _ruler,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.only(left: 14),
                        child: KdSectionLabel(l10n.guideChannel),
                      ),
                      const Divider(height: 1, color: KdColors.line),
                      Expanded(
                        child: ListView.builder(
                          controller: _vLeft,
                          itemExtent: _row,
                          itemCount: items.length,
                          itemBuilder: (context, i) => _ChannelCell(item: items[i], index: i, onTap: () => _play(items, i)),
                        ),
                      ),
                    ],
                  ),
                ),
                const VerticalDivider(width: 1, thickness: 1, color: KdColors.line),
                Expanded(
                  child: Scrollbar(
                    controller: _h,
                    child: SingleChildScrollView(
                      controller: _h,
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: width,
                        child: Stack(
                          children: [
                            Column(
                              children: [
                                SizedBox(height: _ruler, child: _Ruler(start: _windowStart, hours: _hours, pxPerMin: _pxPerMin)),
                                const Divider(height: 1, color: KdColors.line),
                                Expanded(
                                  child: ListView.builder(
                                    controller: _vRight,
                                    itemExtent: _row,
                                    itemCount: items.length,
                                    itemBuilder: (context, i) => _Lane(
                                      item: items[i],
                                      windowStart: _windowStart,
                                      width: width,
                                      pxPerMin: _pxPerMin,
                                      // The full table is heavy: only when the user looks back.
                                      archive: items[i].hasCatchup && _windowStart < _startOfWindow(),
                                      onTap: (p) => _play(items, i, p),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (nowX > 0 && nowX < width)
                              Positioned(
                                left: nowX,
                                top: 0,
                                bottom: 0,
                                child: IgnorePointer(
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                        decoration: BoxDecoration(color: KdColors.accent, borderRadius: BorderRadius.circular(3)),
                                        child: Text(kdClock(now), style: const TextStyle(fontSize: KdType.tag, color: KdColors.accentInk, fontWeight: FontWeight.w600)),
                                      ),
                                      Expanded(child: Container(width: 1.5, color: KdColors.accent)),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// A past programme with a recording replays; anything else tunes in live.
  void _play(List<Item> items, int i, [Programme? p]) {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (p != null && p.start > now) {
      // Not on yet: what it is, a reminder, or the channel as it is now.
      showDialog<void>(
        context: context,
        builder: (_) => ProgrammeDialog(item: items[i], programme: p, onWatch: () => _play(items, i)),
      );
      return;
    }
    final replay = p != null && p.archive && p.stop <= now;
    context.player.play(items[i], Kind.live, queue: items, programme: replay ? p : null, view: PlayerView.full);
  }

  String _dayLabel() {
    final d = DateTime.fromMillisecondsSinceEpoch(_windowStart * 1000);
    return DateFormat('EEEE, d MMMM', languageCode).format(d);
  }
}

/// An upcoming programme: when, what, and a reminder to set or clear.
class ProgrammeDialog extends StatelessWidget {
  const ProgrammeDialog({super.key, required this.item, required this.programme, required this.onWatch});

  final Item item;
  final Programme programme;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final p = programme;
    final reminders = context.app.reminders;
    final day = DateFormat('EEEE d MMMM', languageCode).format(DateTime.fromMillisecondsSinceEpoch(p.start * 1000));
    return AlertDialog(
      backgroundColor: KdColors.bg2,
      shape: kdDialogShape,
      title: Text(p.title, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
      content: SizedBox(
        width: 440,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.name} · $day · ${kdClock(p.start)} – ${kdClock(p.stop)}',
              style: const TextStyle(color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()]),
            ),
            if (p.description.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(p.description.trim(), maxLines: 8, overflow: TextOverflow.ellipsis, style: const TextStyle(height: 1.5)),
            ],
          ],
        ),
      ),
      actions: [
        KdButton(
          label: l10n.actionWatchChannelNow,
          icon: LucideIcons.radio,
          onPressed: () {
            Navigator.pop(context);
            onWatch();
          },
        ),
        ListenableBuilder(
          listenable: reminders,
          builder: (context, _) {
            final on = reminders.isSet(item, p);
            return KdButton(
              label: on ? l10n.reminderRemove : l10n.reminderSet,
              icon: on ? LucideIcons.bellOff : LucideIcons.bellPlus,
              kind: on ? KdButtonKind.neutral : KdButtonKind.cta,
              onPressed: () async {
                await reminders.toggle(item, p);
                if (context.mounted) Navigator.pop(context);
              },
            );
          },
        ),
      ],
    );
  }
}

class _Ruler extends StatelessWidget {
  const _Ruler({required this.start, required this.hours, required this.pxPerMin});

  final int start;
  final int hours;
  final double pxPerMin;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        for (var m = 0; m < hours * 60; m += 30)
          Positioned(
            left: m * pxPerMin,
            top: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.only(left: 8),
              decoration: const BoxDecoration(border: Border(left: BorderSide(color: KdColors.line))),
              alignment: Alignment.centerLeft,
              child: Text(
                kdClock(start + m * 60),
                style: const TextStyle(fontSize: KdType.small, color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()]),
              ),
            ),
          ),
      ],
    );
  }
}

class _ChannelCell extends StatelessWidget {
  const _ChannelCell({required this.item, required this.index, required this.onTap});

  final Item item;
  final int index;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // A phone's narrow column keeps the logo and the name, not the number.
    final compact = isCompact(context);
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: KdColors.rowDivider))),
        child: Row(
          children: [
            if (!compact)
              SizedBox(
                width: 32,
                child: Text('${item.chno ?? index + 1}', style: const TextStyle(color: KdColors.muted, fontSize: KdType.small, fontFeatures: [FontFeature.tabularFigures()])),
              ),
            KdArt(url: item.logo, label: item.name, width: compact ? 28 : 34, height: compact ? 28 : 34, contain: true),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: compact ? KdType.small : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({
    required this.item,
    required this.windowStart,
    required this.width,
    required this.pxPerMin,
    required this.archive,
    required this.onTap,
  });

  final Item item;
  final int windowStart;
  final double width;
  final double pxPerMin;
  final bool archive;
  final void Function(Programme?) onTap;

  @override
  Widget build(BuildContext context) {
    final epg = context.epg..want(item.id, archive: archive);
    final reminders = context.app.reminders;
    return Container(
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: KdColors.rowDivider))),
      child: ListenableBuilder(
        listenable: Listenable.merge([epg, reminders]),
        builder: (context, _) {
          final list = epg.peek(item.id);
          if (list == null) return const SizedBox.shrink();
          if (list.isEmpty) {
            // _Tile is a Positioned: it must sit directly in a Stack.
            return Stack(
              children: [_Tile(title: l10n.guideNoData, time: '', left: 4, width: width - 8, muted: true, onTap: () => onTap(null))],
            );
          }
          final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          final end = windowStart + (width / pxPerMin * 60).round();
          return Stack(
            children: [
              for (final p in list)
                if (p.stop > windowStart && p.start < end)
                  _Tile(
                    title: p.title,
                    time: '${kdClock(p.start)} – ${kdClock(p.stop)}',
                    left: ((p.start - windowStart) / 60 * pxPerMin).clamp(0, width).toDouble() + 2,
                    width: (((p.stop.clamp(windowStart, end) - p.start.clamp(windowStart, end)) / 60) * pxPerMin - 4).clamp(8, width).toDouble(),
                    live: p.start <= now && p.stop > now,
                    progress: p.start <= now && p.stop > now ? programmeProgress(p) : null,
                    replay: p.archive && p.stop <= now,
                    muted: p.stop <= now && !p.archive,
                    reminded: p.start > now && reminders.isSet(item, p),
                    onTap: () => onTap(p),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _Tile extends StatefulWidget {
  const _Tile({
    required this.title,
    required this.time,
    required this.left,
    required this.width,
    required this.onTap,
    this.live = false,
    this.progress,
    this.muted = false,
    this.replay = false,
    this.reminded = false,
  });

  final String title;
  final String time;
  final double left;
  final double width;
  final bool live;
  final double? progress;
  final bool muted;

  /// Past, with a recording: plays from the start.
  final bool replay;

  /// Upcoming, with a reminder set.
  final bool reminded;
  final VoidCallback onTap;

  @override
  State<_Tile> createState() => _TileState();
}

class _TileState extends State<_Tile> {
  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: widget.left,
      top: 4,
      bottom: 4,
      width: widget.width,
      child: KdTappable(
        onTap: widget.onTap,
        builder: (context, hover, focus) => KdFocusRing(
          focused: focus,
          child: Container(
            padding: const EdgeInsets.fromLTRB(9, 6, 9, 5),
            decoration: BoxDecoration(
              color: widget.live ? KdColors.accentAlpha(0.08) : (hover ? KdColors.bg3 : KdColors.bg2),
              border: Border.all(color: widget.live ? KdColors.accentAlpha(0.45) : (hover ? KdColors.buttonHoverBorder : KdColors.line)),
              borderRadius: BorderRadius.circular(KdRadius.control),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (widget.replay && widget.width > 60) ...[
                      Icon(LucideIcons.history, size: 11, color: hover ? KdColors.accent2 : KdColors.muted),
                      const SizedBox(width: 4),
                    ],
                    if (widget.reminded && widget.width > 40) ...[
                      const Icon(LucideIcons.bellRing, size: 11, color: KdColors.accent),
                      const SizedBox(width: 4),
                    ],
                    Expanded(
                      child: Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w500, color: widget.muted ? KdColors.muted : KdColors.text, fontSize: KdType.small),
                      ),
                    ),
                  ],
                ),
                if (widget.time.isNotEmpty)
                  Text(widget.time, maxLines: 1, overflow: TextOverflow.clip, style: const TextStyle(fontSize: KdType.tag, color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()])),
                const Spacer(),
                if (widget.progress case final p?) KdProgress(value: p),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
