import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/library.dart';
import '../app/paging.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_category_rail.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_widgets.dart';
import '../l10n/l10n.dart';
import '../player/player_controller.dart';

/// Movies or series: category rail + poster grid, detail on click.

/// Rail id of "all categories".
const _allCategories = -1;

class VodScreen extends StatefulWidget {
  const VodScreen({super.key, required this.kind, this.initialDetail});

  final Kind kind;

  /// Opens straight into this item's detail (from home or search).
  final Item? initialDetail;

  @override
  State<VodScreen> createState() => _VodScreenState();
}

class _VodScreenState extends State<VodScreen> {
  List<Category> _categories = const [];
  int? _category;
  ItemPager? _pager;
  Item? _detail;
  String? _sourceId;
  int _version = -1;

  @override
  void initState() {
    super.initState();
    _detail = widget.initialDetail;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = context.app;
    final sid = app.activeSource?.id;
    if (sid != _sourceId || app.catalogVersion != _version) {
      final first = _sourceId == null;
      _sourceId = sid;
      _version = app.catalogVersion;
      if (!first) _detail = null;
      _load();
    }
  }

  @override
  void didUpdateWidget(VodScreen old) {
    super.didUpdateWidget(old);
    if (old.kind != widget.kind) {
      _detail = null;
      _load();
    }
  }

  @override
  void dispose() {
    _pager?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sid = _sourceId;
    if (sid == null) return;
    final cats = await context.library.categories(sid, widget.kind);
    if (!mounted) return;
    setState(() => _categories = cats);
    _select(null);
  }

  void _select(int? uid) {
    final sid = _sourceId;
    if (sid == null) return;
    _pager?.dispose();
    final pager = ItemPager(library: context.library, sourceId: sid, kind: widget.kind, categoryUid: uid, pageSize: 300)
      ..addListener(() => setState(() {}));
    setState(() {
      _category = uid;
      _pager = pager;
    });
    pager.loadMore();
  }

  @override
  Widget build(BuildContext context) {
    if (_sourceId == null) {
      return KdEmpty(title: l10n.sourceNone, hint: l10n.sourceNoneHint);
    }
    final detail = _detail;
    if (detail != null) {
      return DetailView(item: detail, kind: widget.kind, onBack: () => setState(() => _detail = null));
    }
    final total = _categories.fold<int>(0, (a, c) => a + c.count);
    final pager = _pager;
    // Categories down the left like Live TV: providers list dozens or
    // hundreds, which a row of pills cannot show (nor scroll with a wheel).
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 230,
          child: KdCategoryRail(
            title: l10n.liveCategories,
            selected: _category ?? _allCategories,
            onSelect: (id) => _select(id == _allCategories ? null : id),
            entries: [
              KdRailEntry(
                id: _allCategories,
                name: l10n.categoryAll,
                count: total,
                icon: widget.kind == Kind.movie ? LucideIcons.clapperboard : LucideIcons.layers,
                pinned: true,
              ),
              for (final c in _categories) KdRailEntry(id: c.uid, name: c.name, count: c.count),
            ],
          ),
        ),
        const VerticalDivider(width: 1, thickness: 1, color: KdColors.line),
        Expanded(child: _grid(total, pager)),
      ],
    );
  }

  Widget _grid(int total, ItemPager? pager) {
    final name = _category == null ? null : _categories.where((c) => c.uid == _category).map((c) => c.name).firstOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
          child: Row(
            children: [
              Text(
                widget.kind == Kind.movie ? l10n.navMovies : l10n.navSeries,
                style: const TextStyle(fontSize: KdType.display, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 10),
              if (name != null)
                Flexible(
                  child: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: KdColors.muted),
                  ),
                )
              else
                Text(
                  '$total',
                  style: const TextStyle(color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()]),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        if (pager != null && pager.loading && pager.items.isEmpty)
          const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: KdIndeterminate()),
        Expanded(
          child: pager == null || (pager.items.isEmpty && !pager.loading)
              ? KdEmpty(icon: widget.kind == Kind.movie ? LucideIcons.clapperboard : LucideIcons.layers, title: l10n.vodEmptyCategory)
              : NotificationListener<ScrollNotification>(
                  onNotification: (n) {
                    if (n.metrics.extentAfter < 1200) pager.loadMore();
                    return false;
                  },
                  child: GridView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 170,
                      mainAxisSpacing: 18,
                      crossAxisSpacing: 14,
                      childAspectRatio: 0.58,
                    ),
                    itemCount: pager.items.length,
                    itemBuilder: (context, i) => PosterCard(item: pager.items[i], onTap: () => setState(() => _detail = pager.items[i])),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 2:3 poster with title, year and rating underneath.
class PosterCard extends StatefulWidget {
  const PosterCard({super.key, required this.item, required this.onTap, this.progress, this.width});

  final Item item;
  final VoidCallback onTap;
  final double? progress;
  final double? width;

  @override
  State<PosterCard> createState() => _PosterCardState();
}

class _PosterCardState extends State<PosterCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: SizedBox(
          width: widget.width,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 2 / 3,
                child: LayoutBuilder(
                  builder: (context, c) => Stack(
                    fit: StackFit.expand,
                    children: [
                      KdArt(url: item.logo, label: item.name, width: c.maxWidth, height: c.maxHeight, radius: KdRadius.card),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(KdRadius.card),
                          border: Border.all(color: _hover ? KdColors.accent : KdColors.line, width: _hover ? 1.5 : 1),
                        ),
                      ),
                      if (item.rating case final r? when r > 0)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(color: const Color(0xCC0B0B10), borderRadius: BorderRadius.circular(4)),
                            child: Text(
                              r.toStringAsFixed(1),
                              style: const TextStyle(fontSize: KdType.tag, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      if (widget.progress case final p?) Positioned(left: 8, right: 8, bottom: 8, child: KdProgress(value: p, height: 3)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(
                item.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w500, color: _hover ? KdColors.accent2 : KdColors.text),
              ),
              if (item.year != null)
                Text(
                  '${item.year}',
                  style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Movie / series page: backdrop, poster, facts, play, seasons/episodes.
class DetailView extends StatefulWidget {
  const DetailView({super.key, required this.item, required this.kind, required this.onBack});

  final Item item;
  final Kind kind;
  final VoidCallback onBack;

  @override
  State<DetailView> createState() => _DetailViewState();
}

class _DetailViewState extends State<DetailView> {
  ItemDetail? _d;
  Object? _error;
  int _season = 1;
  bool? _fav;

  /// TMDB's view, when a key is set and the title matched; loads beside the
  /// provider's detail and never holds it up.
  TmdbInfo? _tmdb;
  final Map<(int, int), TmdbEpisodeInfo> _tmdbEpisodes = {};
  final Set<int> _tmdbSeasons = {};

  @override
  void initState() {
    super.initState();
    _load();
    _loadTmdb();
  }

  Future<void> _load() async {
    try {
      final d = await context.library.detail(widget.item.id);
      if (!mounted) return;
      setState(() {
        _d = d;
        _fav = d.isFavorite;
        final seasons = d.episodes.map((e) => e.season).toSet();
        _season = seasons.isEmpty ? 1 : seasons.reduce((a, b) => a < b ? a : b);
      });
      _loadTmdbSeason();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadTmdb() async {
    try {
      final t = await context.library.tmdbDetail(widget.item.id);
      if (!mounted || t == null) return;
      setState(() => _tmdb = t);
      _loadTmdbSeason();
    } catch (_) {
      // TMDB is decoration: the provider's detail stands on its own.
    }
  }

  Future<void> _loadTmdbSeason() async {
    final season = _season;
    if (widget.kind != Kind.series || _tmdb == null || !_tmdbSeasons.add(season)) return;
    try {
      final list = await context.library.tmdbSeason(widget.item.id, season);
      if (!mounted) return;
      setState(() {
        for (final e in list) {
          _tmdbEpisodes[(e.season, e.number)] = e;
        }
      });
    } catch (_) {
      _tmdbSeasons.remove(season);
    }
  }

  void _play({EpisodeInfo? episode, bool fromStart = false}) {
    context.player.play(widget.item, widget.kind, episode: episode, view: PlayerView.full, fromStart: fromStart);
  }

  String? get _trailer => _tmdb?.trailer ?? _d?.trailer;

  @override
  Widget build(BuildContext context) {
    final d = _d;
    final t = _tmdb;
    final item = widget.item;
    final backdrop = t?.backdrop ?? d?.backdrop;
    final plot = t?.overview ?? d?.plot;
    final makers = t != null && t.makers.isNotEmpty ? t.makers.join(', ') : d?.director;
    return Stack(
      children: [
        if (backdrop != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 380,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Opacity(
                  opacity: 0.35,
                  child: Image.network(backdrop, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox()),
                ),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0x000B0B10), KdColors.bg],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ListView(
          padding: const EdgeInsets.fromLTRB(28, 16, 28, 32),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: KdButton(label: l10n.actionBack, icon: LucideIcons.arrowLeft, kind: KdButtonKind.ghost, onPressed: widget.onBack),
            ),
            const SizedBox(height: 40),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                KdArt(url: t?.poster ?? item.logo, label: item.name, width: 180, height: 270, radius: KdRadius.card),
                const SizedBox(width: 24),
                Expanded(child: _facts(d)),
              ],
            ),
            const SizedBox(height: 22),
            if (_error != null)
              Text(l10n.detailFailed(errorText(_error!)), style: const TextStyle(color: KdColors.err))
            else if (d == null)
              const SizedBox(width: 240, child: KdIndeterminate())
            else ...[
              if (plot != null) ...[
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: Text(plot, style: const TextStyle(height: 1.55)),
                ),
                const SizedBox(height: 14),
              ],
              if (makers != null) _fact(widget.kind == Kind.series ? l10n.detailCreator : l10n.detailDirector, makers),
              if (t != null && t.cast.isNotEmpty) ...[
                const SizedBox(height: 18),
                KdSectionLabel(l10n.detailCast),
                const SizedBox(height: 10),
                _CastRow(cast: t.cast),
              ] else if (d.cast != null)
                _fact(l10n.detailCast, d.cast!),
              if (widget.kind == Kind.series) ...[const SizedBox(height: 22), _episodes(d)],
              if (t != null) ...[
                const SizedBox(height: 24),
                Text(
                  l10n.detailSourceTmdb,
                  style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted),
                ),
              ],
            ],
          ],
        ),
      ],
    );
  }

  Widget _facts(ItemDetail? d) {
    final item = widget.item;
    final t = _tmdb;
    final runtime = t?.runtimeMin != null ? t!.runtimeMin! * 60 : d?.durationSecs;
    final genres = t != null && t.genres.isNotEmpty ? t.genres.take(3).join(', ') : d?.genre;
    final year = t?.year ?? item.year;
    final rating = t?.rating ?? item.rating;
    final meta = <String>[
      if (year != null) '$year',
      ?genres,
      if (runtime case final s? when s > 0 && widget.kind == Kind.movie) kdDuration(s),
      if (widget.kind == Kind.series && d != null) l10n.detailSeasons(d.episodes.map((e) => e.season).toSet().length),
    ];
    final progress = d?.progressMs;
    final original = t?.originalTitle;
    final title = t?.title ?? item.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600, height: 1.2)),
        if (original != null && original != title) ...[
          const SizedBox(height: 2),
          Text(original, style: const TextStyle(color: KdColors.muted)),
        ],
        if (t?.tagline case final tag? when tag.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            tag,
            style: const TextStyle(color: KdColors.muted, fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            if (t?.certification case final c? when c.isNotEmpty) ...[KdTag(c), const SizedBox(width: 10)],
            if (rating case final r? when r > 0) ...[
              const Icon(LucideIcons.star, size: 14, color: KdColors.accent),
              const SizedBox(width: 3),
              Text(r.toStringAsFixed(1), style: const TextStyle(fontWeight: FontWeight.w600)),
              if (t?.voteCount case final v? when v > 0)
                Text(
                  '  ${_votes(v)}',
                  style: const TextStyle(color: KdColors.muted, fontSize: KdType.small),
                ),
              const SizedBox(width: 12),
            ],
            Flexible(
              child: Text(meta.join('  ·  '), style: const TextStyle(color: KdColors.muted)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (widget.kind == Kind.movie)
              KdButton(
                label: progress != null && progress > 0 ? l10n.actionResume : l10n.actionPlay,
                icon: LucideIcons.play,
                kind: KdButtonKind.cta,
                large: true,
                onPressed: d == null ? null : () => _play(),
              ),
            if (widget.kind == Kind.movie && progress != null && progress > 0)
              KdButton(label: l10n.actionFromStart, large: true, onPressed: () => _play(fromStart: true)),
            if (widget.kind == Kind.series && d != null && d.episodes.isNotEmpty)
              KdButton(
                label: _resumeEpisode(d) == null ? l10n.actionPlayFirstEpisode : l10n.actionResume,
                icon: LucideIcons.play,
                kind: KdButtonKind.cta,
                large: true,
                onPressed: () => _play(episode: _resumeEpisode(d) ?? d.episodes.first),
              ),
            if (_trailer case final key?)
              KdButton(label: l10n.actionTrailer, icon: LucideIcons.clapperboard, large: true, onPressed: () => launchUrl(_youtube(key))),
            KdButton(
              label: _fav == true ? l10n.listIn : l10n.listAdd,
              icon: _fav == true ? LucideIcons.check : LucideIcons.plus,
              large: true,
              onPressed: _fav == null
                  ? null
                  : () async {
                      final v = !_fav!;
                      await context.library.setFavorite(widget.item.id, v);
                      if (mounted) setState(() => _fav = v);
                    },
            ),
          ],
        ),
      ],
    );
  }

  EpisodeInfo? _resumeEpisode(ItemDetail d) {
    for (final e in d.episodes) {
      if ((e.progressMs ?? 0) > 0) return e;
    }
    return null;
  }

  Widget _fact(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label, style: const TextStyle(color: KdColors.muted)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );

  Widget _episodes(ItemDetail d) {
    final seasons = d.episodes.map((e) => e.season).toSet().toList()..sort();
    final list = d.episodes.where((e) => e.season == _season).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            KdSectionLabel(l10n.detailEpisodes),
            const SizedBox(width: 14),
            for (final s in seasons) ...[
              KdPill(
                label: l10n.detailSeasonN(s),
                selected: s == _season,
                onTap: () {
                  setState(() => _season = s);
                  _loadTmdbSeason();
                },
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
        const SizedBox(height: 12),
        for (final e in list)
          _EpisodeRow(
            e: e,
            tmdb: _tmdbEpisodes[(e.season, e.number)],
            onTap: () => _play(episode: e),
          ),
      ],
    );
  }
}

/// A trailer key from TMDB or the provider: a YouTube id, or already a URL.
Uri _youtube(String key) =>
    key.startsWith('http') ? Uri.parse(key) : Uri.parse('https://www.youtube.com/watch?v=${Uri.encodeComponent(key)}');

String _votes(int v) => l10n.detailVotes(NumberFormat.compact(locale: languageCode).format(v));

/// Cast with photos, scrolling sideways.
class _CastRow extends StatelessWidget {
  const _CastRow({required this.cast});

  final List<TmdbPerson> cast;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: KdWheelScroll(
        builder: (controller) => ListView.separated(
          controller: controller,
          scrollDirection: Axis.horizontal,
          itemCount: cast.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) {
            final p = cast[i];
            return SizedBox(
              width: 92,
              child: Column(
                children: [
                  KdArt(url: p.photo, label: p.name, width: 84, height: 84, radius: 42),
                  const SizedBox(height: 8),
                  Text(
                    p.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: KdType.small, fontWeight: FontWeight.w500),
                  ),
                  if (p.role != null)
                    Text(
                      p.role!,
                      maxLines: 1,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _EpisodeRow extends StatefulWidget {
  const _EpisodeRow({required this.e, required this.onTap, this.tmdb});

  final EpisodeInfo e;

  /// TMDB's episode: a clean, localized name and overview, a still.
  final TmdbEpisodeInfo? tmdb;
  final VoidCallback onTap;

  @override
  State<_EpisodeRow> createState() => _EpisodeRowState();
}

class _EpisodeRowState extends State<_EpisodeRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final t = widget.tmdb;
    final title = t?.name ?? e.title;
    final plot = t?.overview ?? e.plot;
    final image = e.image ?? t?.still;
    final dur = e.durationSecs ?? (t?.runtimeMin != null ? t!.runtimeMin! * 60 : null);
    final progress = dur != null && dur > 0 && e.progressMs != null ? (e.progressMs! / 1000) / dur : null;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _hover ? KdColors.bg2 : Colors.transparent,
            border: Border.all(color: _hover ? KdColors.line : Colors.transparent),
            borderRadius: BorderRadius.circular(KdRadius.card),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 28,
                child: Text(
                  '${e.number}',
                  style: const TextStyle(color: KdColors.muted, fontSize: KdType.title, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ),
              Stack(
                children: [
                  KdArt(url: image, label: title, width: 160, height: 90),
                  if (_hover)
                    const Positioned.fill(
                      child: Center(child: Icon(LucideIcons.play, color: KdColors.text, size: 22)),
                    ),
                  if (progress != null) Positioned(left: 6, right: 6, bottom: 6, child: KdProgress(value: progress, height: 3)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        if (dur != null && dur > 0)
                          Text(
                            kdDuration(dur),
                            style: const TextStyle(fontSize: KdType.small, color: KdColors.muted),
                          ),
                      ],
                    ),
                    if (plot != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        plot,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: KdType.small, color: KdColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
