import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/app_state.dart';
import '../app/library.dart';
import '../app/paging.dart';
import '../app/scope.dart';
import '../design/layout.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_category_rail.dart';
import '../design/widgets/kd_controls.dart';
import '../l10n/l10n.dart';
import '../player/player_controller.dart';
import 'vod_screen.dart';
import '../design/widgets/kd_focus.dart';

/// Home: what to continue, what was watched, what is new.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpen});

  /// Opens a movie/series detail in its section.
  final void Function(Item item, Kind kind) onOpen;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<ContinueItem> _continue = const [];
  List<Item> _recent = const [];
  List<Item> _favs = const [];
  List<Item> _newMovies = const [];
  List<Item> _newSeries = const [];
  bool _loaded = false;
  String? _sourceId;
  int _version = -1;

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

  Future<void> _clear({bool recent = false, bool progress = false}) async {
    final sid = context.app.activeSource?.id;
    if (sid == null) return;
    await context.library.clearHistory(sid, recent: recent, progress: progress);
    await _load();
  }

  Future<void> _load() async {
    final sid = _sourceId;
    if (sid == null) return;
    final lib = context.library;
    final r = await Future.wait([
      lib.continueWatching(sid, 12),
      lib.recent(sid, Kind.live, 16),
      lib.favorites(sid, Kind.live),
      lib.recentlyAdded(sid, Kind.movie, 20),
      lib.recentlyAdded(sid, Kind.series, 20),
    ]);
    if (!mounted) return;
    setState(() {
      _continue = r[0] as List<ContinueItem>;
      _recent = r[1] as List<Item>;
      _favs = r[2] as List<Item>;
      _newMovies = r[3] as List<Item>;
      _newSeries = r[4] as List<Item>;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final source = context.app.activeSource;
    if (source == null) {
      return KdEmpty(title: l10n.sourceNone, hint: l10n.sourceNoneHint);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      children: [
        _SourceStatus(source: source),
        if (_loaded && _continue.isEmpty && _recent.isEmpty && _favs.isEmpty)
          _FirstSteps(onLive: () => context.app.go(Section.live)),
        if (_continue.isNotEmpty)
          _Shelf(
            title: l10n.homeContinue,
            height: 236,
            onClear: () => _clear(progress: true),
            children: [
              for (final c in _continue)
                PosterCard(
                  width: 128,
                  item: c.item,
                  progress: c.durationMs > 0 ? c.positionMs / c.durationMs : null,
                  onTap: () => widget.onOpen(c.item, c.kind),
                ),
            ],
          ),
        if (_recent.isNotEmpty)
          _Shelf(
            title: l10n.homeRecentChannels,
            height: 92,
            onClear: () => _clear(recent: true),
            children: [for (final c in _recent) _ChannelTile(item: c, queue: _recent)],
          ),
        if (_favs.isNotEmpty)
          _Shelf(
            title: l10n.homeFavoriteChannels,
            height: 92,
            children: [for (final c in _favs) _ChannelTile(item: c, queue: _favs)],
          ),
        if (_newMovies.isNotEmpty)
          _Shelf(
            title: l10n.homeNewMovies,
            height: 236,
            onMore: () => context.app.go(Section.movies),
            children: [for (final m in _newMovies) PosterCard(width: 128, item: m, onTap: () => widget.onOpen(m, Kind.movie))],
          ),
        if (_newSeries.isNotEmpty)
          _Shelf(
            title: l10n.homeNewSeries,
            height: 236,
            onMore: () => context.app.go(Section.series),
            children: [for (final s in _newSeries) PosterCard(width: 128, item: s, onTap: () => widget.onOpen(s, Kind.series))],
          ),
      ],
    );
  }
}

class _SourceStatus extends StatefulWidget {
  const _SourceStatus({required this.source});

  final SourceInfo source;

  @override
  State<_SourceStatus> createState() => _SourceStatusState();
}

class _SourceStatusState extends State<_SourceStatus> {
  String? _stage;
  StreamSubscription<SyncEvent>? _sub;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _sync() {
    setState(() => _stage = l10n.syncConnecting);
    _sub = context.library.syncSource(widget.source.id).listen((e) {
      if (!mounted) return;
      switch (e) {
        case SyncEvent_Downloading(:final what):
          setState(() => _stage = l10n.syncDownloading(what));
        case SyncEvent_Saving():
          setState(() => _stage = l10n.syncSaving);
        case SyncEvent_Done(:final source):
          setState(() => _stage = null);
          context.app.sourceChanged(source);
        case SyncEvent_Failed(:final message):
          setState(() => _stage = null);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        case SyncEvent_Connecting():
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    final parts = <String>[
      if (s.syncedAt != null) l10n.homeLastSync(_ago(s.syncedAt!)),
      if (s.expiresAt != null) l10n.homeAccountUntil(_date(s.expiresAt!)),
      if (s.maxConnections != null) l10n.homeConnections(s.maxConnections!),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting(), style: const TextStyle(fontSize: KdType.display, fontWeight: FontWeight.w600)),
              const SizedBox(height: 3),
              if (_stage != null)
                Row(
                  children: [
                    Text(_stage!, style: const TextStyle(fontSize: KdType.small, color: KdColors.muted)),
                    const SizedBox(width: 10),
                    const SizedBox(width: 120, child: KdIndeterminate()),
                  ],
                )
              else if (s.lastError != null)
                Text(s.lastError!, style: const TextStyle(fontSize: KdType.small, color: KdColors.err))
              else
                Text(parts.join('  ·  '), style: const TextStyle(fontSize: KdType.small, color: KdColors.muted)),
            ],
          ),
          ),
          const SizedBox(width: 12),
          KdButton(label: l10n.actionSync, icon: LucideIcons.refreshCw, onPressed: _stage == null ? _sync : null),
        ],
      ),
    );
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 6) return l10n.greetNight;
  if (h < 12) return l10n.greetMorning;
  if (h < 18) return l10n.greetDay;
  return l10n.greetEvening;
}

String _ago(int unix) => kdAgo(unix);

String _date(int unix) => DateFormat.yMd(languageCode).format(DateTime.fromMillisecondsSinceEpoch(unix * 1000));

class _Shelf extends StatelessWidget {
  const _Shelf({required this.title, required this.height, required this.children, this.onMore, this.onClear});

  final String title;
  final double height;
  final List<Widget> children;
  final VoidCallback? onMore;

  /// Forgets this shelf's history ("Temizle").
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: KdType.title, fontWeight: FontWeight.w600)),
              ),
              if (onClear != null) KdButton(label: l10n.historyClear, icon: LucideIcons.eraser, kind: KdButtonKind.ghost, onPressed: onClear),
              if (onMore != null) KdButton(label: l10n.actionAll, kind: KdButtonKind.ghost, onPressed: onMore),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: height,
            child: KdWheelScroll(
              builder: (controller) => ListView.separated(
                controller: controller,
                scrollDirection: Axis.horizontal,
                itemCount: children.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (_, i) => children[i],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChannelTile extends StatefulWidget {
  const _ChannelTile({required this.item, required this.queue});

  final Item item;
  final List<Item> queue;

  @override
  State<_ChannelTile> createState() => _ChannelTileState();
}

class _ChannelTileState extends State<_ChannelTile> {
  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final epg = context.epg..want(item.id);
    return KdTappable(
      onTap: () => context.player.play(item, Kind.live, queue: widget.queue, view: PlayerView.full),
      builder: (context, hover, focus) => KdFocusRing(
        focused: focus,
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: hover ? KdColors.bg3 : KdColors.bg2,
            border: Border.all(color: hover ? KdColors.buttonHoverBorder : KdColors.line),
            borderRadius: BorderRadius.circular(KdRadius.card),
          ),
          child: Row(
            children: [
              KdArt(url: item.logo, label: item.name, width: 48, height: 48, contain: true),
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
                        Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text(now?.title ?? l10n.liveShort, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted)),
                        if (now != null) ...[const SizedBox(height: 5), KdProgress(value: programmeProgress(now))],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FirstSteps extends StatelessWidget {
  const _FirstSteps({required this.onLive});

  final VoidCallback onLive;

  @override
  Widget build(BuildContext context) {
    Widget tip(IconData icon, String title, String hint) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: KdColors.bg2,
          border: Border.all(color: KdColors.line),
          borderRadius: BorderRadius.circular(KdRadius.card),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: KdColors.accent2),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 3),
            Text(hint, style: const TextStyle(fontSize: KdType.small, color: KdColors.muted)),
          ],
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The tips speak of keys (arrows, Ctrl+K): not for a phone.
          if (!isCompact(context))
            Row(
              children: [
                tip(LucideIcons.tv, l10n.navLive, l10n.tipLiveHint),
                const SizedBox(width: 12),
                tip(LucideIcons.star, l10n.navFavorites, l10n.tipFavoritesHint),
                const SizedBox(width: 12),
                tip(LucideIcons.search, l10n.tipSearchTitle, l10n.tipSearchHint),
              ],
            ),
          if (!isCompact(context)) const SizedBox(height: 14),
          KdButton(label: l10n.goToLive, icon: LucideIcons.tv, kind: KdButtonKind.cta, large: true, onPressed: onLive),
        ],
      ),
    );
  }
}
