import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/paging.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_widgets.dart';
import '../l10n/l10n.dart';
import '../player/player_controller.dart';
import '../player/reconnect_banner.dart';

/// Live TV: categories · channel list · preview with now/next.
/// Click previews in place, double-click or Enter goes full screen,
/// ↑/↓ zap through the list.
class LiveScreen extends StatefulWidget {
  const LiveScreen({super.key});

  @override
  State<LiveScreen> createState() => _LiveScreenState();
}

/// Sentinel category ids.
const _all = -1;
const _favorites = -2;

class _LiveScreenState extends State<LiveScreen> {
  static const _rowHeight = 50.0;

  List<Category> _categories = const [];
  int _category = _all;
  ItemPager? _pager;
  List<Item> _favoriteItems = const [];
  int _selected = -1;
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'channels');
  final _filter = TextEditingController();
  String? _sourceId;
  int _version = -1;

  PlayerController? _player;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _player ??= context.player..addListener(_followPlayer);
    final app = context.app;
    final sid = app.activeSource?.id;
    if (sid != _sourceId || app.catalogVersion != _version) {
      _sourceId = sid;
      _version = app.catalogVersion;
      _loadCategories();
    }
  }

  /// The highlighted row follows the playing channel, however it was tuned.
  void _followPlayer() {
    final id = _player?.now?.item.id;
    if (id == null) return;
    final i = _items.indexWhere((c) => c.id == id);
    if (i >= 0 && i != _selected) {
      setState(() => _selected = i);
      _ensureVisible(i);
    }
  }

  @override
  void dispose() {
    _player?.removeListener(_followPlayer);
    _pager?.dispose();
    _scroll.dispose();
    _focus.dispose();
    _filter.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    final sid = _sourceId;
    if (sid == null) return;
    final lib = context.library;
    final cats = await lib.categories(sid, Kind.live);
    final favs = await lib.favorites(sid, Kind.live);
    if (!mounted) return;
    setState(() {
      _categories = cats;
      _favoriteItems = favs;
    });
    _selectCategory(_category);
  }

  void _selectCategory(int uid) {
    final sid = _sourceId;
    if (sid == null) return;
    _pager?.dispose();
    _pager = null;
    setState(() {
      _category = uid;
      _selected = -1;
    });
    if (uid != _favorites) {
      final pager = ItemPager(
        library: context.library,
        sourceId: sid,
        kind: Kind.live,
        categoryUid: uid == _all ? null : uid,
      )..addListener(() => setState(() {}));
      _pager = pager;
      pager.loadMore();
    }
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  List<Item> get _items {
    final base = _category == _favorites ? _favoriteItems : (_pager?.items ?? const <Item>[]);
    final q = _filter.text.trim().toLowerCase();
    if (q.isEmpty) return base;
    return base.where((i) => i.name.toLowerCase().contains(q)).toList();
  }

  void _play(int index, {bool full = false}) {
    final items = _items;
    if (index < 0 || index >= items.length) return;
    setState(() => _selected = index);
    _ensureVisible(index);
    context.player.play(
      items[index],
      Kind.live,
      queue: items,
      view: full ? PlayerView.full : PlayerView.preview,
    );
  }

  void _ensureVisible(int index) {
    if (!_scroll.hasClients) return;
    final top = index * _rowHeight;
    final view = _scroll.position.viewportDimension;
    if (top < _scroll.offset) {
      _scroll.jumpTo(top);
    } else if (top + _rowHeight > _scroll.offset + view) {
      _scroll.jumpTo(top + _rowHeight - view);
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    final n = _items.length;
    if (n == 0) return KeyEventResult.ignored;
    if (k == LogicalKeyboardKey.arrowDown) {
      _play((_selected + 1).clamp(0, n - 1));
    } else if (k == LogicalKeyboardKey.arrowUp) {
      _play((_selected - 1).clamp(0, n - 1));
    } else if (k == LogicalKeyboardKey.pageDown) {
      _play((_selected + 10).clamp(0, n - 1));
    } else if (k == LogicalKeyboardKey.pageUp) {
      _play((_selected - 10).clamp(0, n - 1));
    } else if (digitOf(k) case final d? when context.player.now?.isLive ?? false) {
      context.player.typeDigit(d);
    } else if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (context.player.zapDigits.isNotEmpty) {
        context.player.commitDigits();
      } else {
        _play(_selected < 0 ? 0 : _selected, full: true);
      }
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    if (_sourceId == null) {
      return KdEmpty(title: l10n.sourceNone, hint: l10n.sourceNoneHint);
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 210, child: _categoryPane()),
        const VerticalDivider(width: 1, thickness: 1, color: KdColors.line),
        SizedBox(width: 380, child: _channelPane()),
        const VerticalDivider(width: 1, thickness: 1, color: KdColors.line),
        const Expanded(child: _PreviewPane()),
      ],
    );
  }

  Widget _categoryPane() {
    final total = _categories.fold<int>(0, (a, c) => a + c.count);
    Widget row(int uid, String name, int? count, {IconData? icon}) => _CategoryRow(
      name: name,
      count: count,
      icon: icon,
      active: _category == uid,
      onTap: () => _selectCategory(uid),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 8), child: KdSectionLabel(l10n.liveCategories)),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              row(_all, l10n.liveAllChannels, total, icon: LucideIcons.tv),
              row(_favorites, l10n.navFavorites, _favoriteItems.length, icon: LucideIcons.star),
              const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: KdColors.line)),
              for (final c in _categories) row(c.uid, c.name, c.count),
            ],
          ),
        ),
      ],
    );
  }

  Widget _channelPane() {
    final items = _items;
    final pager = _pager;
    return Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
            child: KdInput(
              controller: _filter,
              hint: l10n.liveFilterHint,
              prefix: LucideIcons.search,
              onChanged: (_) => setState(() => _selected = -1),
            ),
          ),
          if (pager != null && pager.loading && pager.items.isEmpty)
            const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: KdIndeterminate()),
          Expanded(
            child: items.isEmpty && !(pager?.loading ?? false)
                ? KdEmpty(
                    icon: _category == _favorites ? LucideIcons.star : LucideIcons.tv,
                    title: _category == _favorites ? l10n.liveNoFavorites : l10n.liveNoChannels,
                    hint: _category == _favorites ? l10n.liveNoFavoritesHint : null,
                  )
                : NotificationListener<ScrollNotification>(
                    onNotification: (n) {
                      if (n.metrics.extentAfter < 800) pager?.loadMore();
                      return false;
                    },
                    child: ListView.builder(
                      controller: _scroll,
                      itemExtent: _rowHeight,
                      itemCount: items.length,
                      itemBuilder: (context, i) => _ChannelRow(
                        item: items[i],
                        index: i,
                        selected: i == _selected,
                        onTap: () {
                          _focus.requestFocus();
                          _play(i);
                        },
                        onDoubleTap: () => _play(i, full: true),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatefulWidget {
  const _CategoryRow({required this.name, required this.count, required this.active, required this.onTap, this.icon});

  final String name;
  final int? count;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<_CategoryRow> createState() => _CategoryRowState();
}

class _CategoryRowState extends State<_CategoryRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 32,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: a ? KdColors.accentAlpha(0.12) : (_hover ? KdColors.bg2 : Colors.transparent),
            borderRadius: BorderRadius.circular(KdRadius.control),
          ),
          child: Row(
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 14, color: a ? KdColors.accent2 : KdColors.muted),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  widget.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: a ? KdColors.accent2 : KdColors.text,
                    fontWeight: a ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (widget.count != null)
                Text(
                  '${widget.count}',
                  style: const TextStyle(
                    fontSize: KdType.chip,
                    color: KdColors.muted,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChannelRow extends StatefulWidget {
  const _ChannelRow({required this.item, required this.index, required this.selected, required this.onTap, required this.onDoubleTap});

  final Item item;
  final int index;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  State<_ChannelRow> createState() => _ChannelRowState();
}

class _ChannelRowState extends State<_ChannelRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final epg = context.epg..want(item.id);
    final sel = widget.selected;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: sel ? KdColors.accentAlpha(0.12) : (_hover ? KdColors.bg2 : Colors.transparent),
            borderRadius: BorderRadius.circular(KdRadius.control),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 34,
                child: Text(
                  '${item.chno ?? widget.index + 1}',
                  style: const TextStyle(
                    color: KdColors.muted,
                    fontSize: KdType.small,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              KdArt(url: item.logo, label: item.name, width: 34, height: 34, contain: true),
              const SizedBox(width: 10),
              Expanded(
                child: ListenableBuilder(
                  listenable: epg,
                  builder: (context, _) {
                    final now = epg.now(item.id);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: sel ? KdColors.accent2 : KdColors.text,
                            fontWeight: sel ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        if (now != null) ...[
                          const SizedBox(height: 1),
                          Text(
                            now.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted),
                          ),
                          const SizedBox(height: 3),
                          SizedBox(width: 120, child: KdProgress(value: programmeProgress(now))),
                        ],
                      ],
                    );
                  },
                ),
              ),
              if (item.hasCatchup)
                Tooltip(
                  message: l10n.liveHasArchive,
                  child: const Icon(LucideIcons.history, size: 13, color: KdColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Embedded preview, programme info and actions for the playing channel.
class _PreviewPane extends StatelessWidget {
  const _PreviewPane();

  @override
  Widget build(BuildContext context) {
    final player = context.player;
    final epg = context.epg;
    return ListenableBuilder(
      listenable: Listenable.merge([player, epg]),
      builder: (context, _) {
        final now = player.now;
        final live = now != null && now.isLive && player.view == PlayerView.preview;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(KdRadius.card),
                  child: DecoratedBox(
                    decoration: const BoxDecoration(color: Colors.black),
                    child: live
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              GestureDetector(
                                onDoubleTap: () => player.setView(PlayerView.full),
                                child: player.engine.surface(),
                              ),
                              Positioned(top: 10, right: 10, child: ZapDigits(player: player)),
                              if (player.reconnecting)
                                Center(child: ReconnectBanner(player: player, compact: true))
                              else if (player.opening || player.buffering)
                                const Align(alignment: Alignment.bottomCenter, child: KdIndeterminate()),
                            ],
                          )
                        : Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(LucideIcons.tvMinimal, size: 30, color: KdColors.muted),
                                const SizedBox(height: 8),
                                Text(l10n.livePickChannel, style: const TextStyle(color: KdColors.muted)),
                                const SizedBox(height: 4),
                                Text(l10n.livePickChannelHint, style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted)),
                              ],
                            ),
                          ),
                  ),
                ),
              ),
              if (now != null && now.isLive) ...[
                const SizedBox(height: 14),
                _ChannelInfo(now: now),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ChannelInfo extends StatefulWidget {
  const _ChannelInfo({required this.now});

  final NowPlaying now;

  @override
  State<_ChannelInfo> createState() => _ChannelInfoState();
}

class _ChannelInfoState extends State<_ChannelInfo> {
  bool? _fav;
  int? _for;

  @override
  Widget build(BuildContext context) {
    final item = widget.now.item;
    if (_for != item.id) {
      _for = item.id;
      _fav = null;
      context.library.isFavorite(item.id).then((v) {
        if (mounted && _for == item.id) setState(() => _fav = v);
      });
    }
    final epg = context.epg;
    final now = epg.now(item.id);
    final next = epg.next(item.id);
    final player = context.player;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            KdArt(url: item.logo, label: item.name, width: 40, height: 40, contain: true),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      KdTag(l10n.tagLive),
                      if (player.videoHeight case final h? when h > 0) ...[
                        const SizedBox(width: 6),
                        KdTag(_res(h), ok: true),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            KdButton(
              label: _fav == true ? l10n.favOn : l10n.favOff,
              icon: _fav == true ? LucideIcons.check : LucideIcons.star,
              onPressed: _fav == null
                  ? null
                  : () async {
                      final v = !(_fav!);
                      await context.library.setFavorite(item.id, v);
                      if (mounted) setState(() => _fav = v);
                    },
            ),
            const SizedBox(width: 8),
            KdButton(
              label: l10n.actionFullscreen,
              icon: LucideIcons.maximize,
              kind: KdButtonKind.cta,
              onPressed: () => player.setView(PlayerView.full),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (now == null && next == null)
          Text(l10n.liveNoGuide, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small))
        else ...[
          if (now != null) _ProgrammeCard(p: now, label: l10n.guideNow, live: true),
          if (next != null) ...[const SizedBox(height: 8), _ProgrammeCard(p: next, label: l10n.guideNext)],
        ],
        if (item.hasCatchup) ...[
          const SizedBox(height: 22),
          _ArchiveList(key: ValueKey(item.id), item: item, queue: widget.now.queue),
        ],
      ],
    );
  }
}

/// Past programmes of a catch-up channel, newest first, grouped by day.
/// A click replays the programme from its start.
class _ArchiveList extends StatefulWidget {
  const _ArchiveList({super.key, required this.item, required this.queue});

  final Item item;
  final List<Item> queue;

  @override
  State<_ArchiveList> createState() => _ArchiveListState();
}

class _ArchiveListState extends State<_ArchiveList> {
  static const _page = 12;
  int _shown = _page;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final epg = context.epg..want(item.id, archive: true);
    final loaded = epg.hasArchive(item.id);
    final past = epg.archive(item.id);
    final rows = <Widget>[];
    String? day;
    for (final p in past.take(_shown)) {
      final d = kdDay(p.start);
      if (d != day) {
        day = d;
        rows.add(Padding(
          padding: EdgeInsets.only(top: rows.isEmpty ? 0 : 10, bottom: 4, left: 2),
          child: Text(d, style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted, fontWeight: FontWeight.w600)),
        ));
      }
      rows.add(_ArchiveRow(
        p: p,
        onTap: () => context.player.play(item, Kind.live, queue: widget.queue, programme: p, view: PlayerView.full),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(LucideIcons.history, size: 13, color: KdColors.accent2),
            const SizedBox(width: 6),
            KdSectionLabel(l10n.livePastBroadcasts),
            const Spacer(),
            if (past.isNotEmpty)
              Text(l10n.liveProgrammeCount(past.length), style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted)),
          ],
        ),
        const SizedBox(height: 8),
        if (!loaded)
          const KdIndeterminate()
        else if (past.isEmpty)
          Text(l10n.liveNoArchive, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small))
        else ...[
          ...rows,
          if (past.length > _shown) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: KdButton(
                label: l10n.liveOlderBroadcasts,
                icon: LucideIcons.chevronDown,
                kind: KdButtonKind.ghost,
                onPressed: () => setState(() => _shown += _page * 2),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

class _ArchiveRow extends StatefulWidget {
  const _ArchiveRow({required this.p, required this.onTap});

  final Programme p;
  final VoidCallback onTap;

  @override
  State<_ArchiveRow> createState() => _ArchiveRowState();
}

class _ArchiveRowState extends State<_ArchiveRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: _hover ? KdColors.bg2 : Colors.transparent,
            borderRadius: BorderRadius.circular(KdRadius.control),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 46,
                child: Text(
                  kdClock(p.start),
                  style: const TextStyle(fontSize: KdType.small, color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
              Expanded(
                child: Text(
                  p.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _hover ? KdColors.accent2 : KdColors.text),
                ),
              ),
              const SizedBox(width: 10),
              Text(kdDuration(p.stop - p.start), style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted)),
              const SizedBox(width: 10),
              Icon(LucideIcons.play, size: 13, color: _hover ? KdColors.accent2 : KdColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

String _res(int h) => h >= 2000 ? '4K' : h >= 1000 ? 'FHD' : h >= 700 ? 'HD' : 'SD';

class _ProgrammeCard extends StatelessWidget {
  const _ProgrammeCard({required this.p, required this.label, this.live = false});

  final Programme p;
  final String label;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: KdColors.bg2,
        border: Border.all(color: KdColors.line),
        borderRadius: BorderRadius.circular(KdRadius.card),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KdSectionLabel(label),
              const SizedBox(width: 8),
              Text(
                '${kdClock(p.start)} – ${kdClock(p.stop)}',
                style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()]),
              ),
              const Spacer(),
              if (live) Text(l10n.liveMinutesLeft(minutesLeft(p)), style: const TextStyle(fontSize: KdType.chip, color: KdColors.accent2)),
            ],
          ),
          const SizedBox(height: 6),
          Text(p.title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: KdType.small, color: KdColors.muted)),
          ],
          if (live) ...[const SizedBox(height: 8), KdProgress(value: programmeProgress(p))],
        ],
      ),
    );
  }
}
