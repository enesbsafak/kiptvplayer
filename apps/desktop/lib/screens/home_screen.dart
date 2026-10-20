import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/app_state.dart';
import '../app/library.dart';
import '../app/paging.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../player/player_controller.dart';
import 'vod_screen.dart';

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
      return const KdEmpty(title: 'Kaynak yok', hint: 'Ayarlar › Kaynaklar bölümünden bir kaynak ekleyin.');
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      children: [
        _SourceStatus(source: source),
        if (_loaded && _continue.isEmpty && _recent.isEmpty && _favs.isEmpty)
          _FirstSteps(onLive: () => context.app.go(Section.live)),
        if (_continue.isNotEmpty)
          _Shelf(
            title: 'Devam et',
            height: 236,
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
            title: 'Son izlenen kanallar',
            height: 92,
            children: [for (final c in _recent) _ChannelTile(item: c, queue: _recent)],
          ),
        if (_favs.isNotEmpty)
          _Shelf(
            title: 'Favori kanallar',
            height: 92,
            children: [for (final c in _favs) _ChannelTile(item: c, queue: _favs)],
          ),
        if (_newMovies.isNotEmpty)
          _Shelf(
            title: 'Yeni eklenen filmler',
            height: 236,
            onMore: () => context.app.go(Section.movies),
            children: [for (final m in _newMovies) PosterCard(width: 128, item: m, onTap: () => widget.onOpen(m, Kind.movie))],
          ),
        if (_newSeries.isNotEmpty)
          _Shelf(
            title: 'Yeni eklenen diziler',
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
    setState(() => _stage = 'Bağlanılıyor…');
    _sub = context.library.syncSource(widget.source.id).listen((e) {
      if (!mounted) return;
      switch (e) {
        case SyncEvent_Downloading(:final what):
          setState(() => _stage = '$what indiriliyor…');
        case SyncEvent_Saving():
          setState(() => _stage = 'Kaydediliyor…');
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
      if (s.syncedAt != null) 'Son eşitleme ${_ago(s.syncedAt!)}',
      if (s.expiresAt != null) 'Hesap ${_date(s.expiresAt!)} tarihine kadar',
      if (s.maxConnections != null) '${s.maxConnections} bağlantı',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Column(
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
          const Spacer(),
          KdButton(label: 'Eşitle', icon: LucideIcons.refreshCw, onPressed: _stage == null ? _sync : null),
        ],
      ),
    );
  }
}

String _greeting() {
  final h = DateTime.now().hour;
  if (h < 6) return 'İyi geceler';
  if (h < 12) return 'Günaydın';
  if (h < 18) return 'İyi günler';
  return 'İyi akşamlar';
}

String _ago(int unix) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(unix * 1000));
  if (d.inMinutes < 1) return 'az önce';
  if (d.inHours < 1) return '${d.inMinutes} dk önce';
  if (d.inDays < 1) return '${d.inHours} sa önce';
  return '${d.inDays} gün önce';
}

String _date(int unix) {
  final d = DateTime.fromMillisecondsSinceEpoch(unix * 1000);
  return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
}

class _Shelf extends StatelessWidget {
  const _Shelf({required this.title, required this.height, required this.children, this.onMore});

  final String title;
  final double height;
  final List<Widget> children;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: const TextStyle(fontSize: KdType.title, fontWeight: FontWeight.w600)),
              const Spacer(),
              if (onMore != null) KdButton(label: 'Tümü', kind: KdButtonKind.ghost, onPressed: onMore),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: children.length,
              separatorBuilder: (_, _) => const SizedBox(width: 12),
              itemBuilder: (_, i) => children[i],
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
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final epg = context.epg..want(item.id);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.player.play(item, Kind.live, queue: widget.queue, view: PlayerView.full),
        child: Container(
          width: 250,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: _hover ? KdColors.bg3 : KdColors.bg2,
            border: Border.all(color: _hover ? KdColors.buttonHoverBorder : KdColors.line),
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
                        Text(now?.title ?? 'Canlı', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted)),
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
          Row(
            children: [
              tip(LucideIcons.tv, 'Canlı TV', '↑ ↓ ile kanal değiştirin, Enter ile tam ekrana geçin.'),
              const SizedBox(width: 12),
              tip(LucideIcons.star, 'Favoriler', 'Sık izlediğiniz kanalları yıldızlayın; ana sayfada görünür.'),
              const SizedBox(width: 12),
              tip(LucideIcons.search, 'Hızlı arama', 'Ctrl K ile kanal, film ve dizilerde arayın.'),
            ],
          ),
          const SizedBox(height: 14),
          KdButton(label: 'Canlı TV\'ye git', icon: LucideIcons.tv, kind: KdButtonKind.cta, large: true, onPressed: onLive),
        ],
      ),
    );
  }
}
