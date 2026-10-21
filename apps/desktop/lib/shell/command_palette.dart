import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/app_state.dart';
import '../app/library.dart';
import '../app/scope.dart';
import '../app/text.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_widgets.dart';
import '../l10n/l10n.dart';
import '../player/player_controller.dart';

/// The app's navigator: dialogs opened from outside the widget tree
/// (screen captures).
final rootNavigator = GlobalKey<NavigatorState>();

/// Ctrl+K: one box for going anywhere and doing anything. Commands match
/// as you type (Turkish-insensitive), channels, films and series come from
/// the library search, a bare number opens that channel.
Future<void> showCommandPalette(BuildContext context, {String query = ''}) => showDialog<void>(
  context: context,
  barrierColor: const Color(0x99000000),
  builder: (_) => CommandPalette(initialQuery: query),
);

class PaletteEntry {
  const PaletteEntry({required this.icon, required this.label, required this.run, this.detail, this.shortcut, this.keywords = ''});

  final IconData icon;
  final String label;
  final String? detail;
  final String? shortcut;

  /// Extra words that find it ("dil language" for the language switch).
  final String keywords;
  final VoidCallback run;
}

class CommandPalette extends StatefulWidget {
  const CommandPalette({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  State<CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<CommandPalette> {
  final _q = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  int _token = 0;
  int _selected = 0;
  List<Item> _live = const [];
  List<Item> _movies = const [];
  List<Item> _series = const [];
  Item? _byNumber;

  static const _row = 40.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.isNotEmpty) {
      _q.text = widget.initialQuery;
      WidgetsBinding.instance.addPostFrameCallback((_) => _search(widget.initialQuery));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed(String v) {
    setState(() => _selected = 0);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 100), () => _search(v));
  }

  Future<void> _search(String q) async {
    final token = ++_token;
    final lib = context.library;
    final query = q.trim();
    if (query.isEmpty) {
      setState(() => _live = _movies = _series = const []);
      _byNumber = null;
      return;
    }
    final number = int.tryParse(query);
    final sid = context.app.activeSource?.id;
    final r = await Future.wait([
      lib.search(query, kind: Kind.live, limit: 6),
      lib.search(query, kind: Kind.movie, limit: 4),
      lib.search(query, kind: Kind.series, limit: 4),
    ]);
    Item? byNumber;
    if (number != null && sid != null) {
      final page = await lib.page(sid, Kind.live, limit: 5000);
      byNumber = page.where((c) => c.chno == number).firstOrNull ?? (number >= 1 && number <= page.length ? page[number - 1] : null);
    }
    if (!mounted || token != _token) return;
    setState(() {
      _live = r[0];
      _movies = r[1];
      _series = r[2];
      _byNumber = byNumber;
    });
  }

  /// Everything the app can do from here, before filtering.
  List<PaletteEntry> _commands(AppState app, PlayerController player) {
    final sections = [
      (Section.home, LucideIcons.house, l10n.navHome, 'Ctrl 1'),
      (Section.live, LucideIcons.tv, l10n.navLive, 'Ctrl 2'),
      (Section.guide, LucideIcons.calendarRange, l10n.navGuide, 'Ctrl 3'),
      (Section.movies, LucideIcons.clapperboard, l10n.navMovies, 'Ctrl 4'),
      (Section.series, LucideIcons.layers, l10n.navSeries, 'Ctrl 5'),
      (Section.favorites, LucideIcons.star, l10n.navFavorites, 'Ctrl 6'),
      (Section.search, LucideIcons.search, l10n.navSearch, null),
      (Section.settings, LucideIcons.settings, l10n.navSettings, 'Ctrl ,'),
    ];
    final active = app.activeSource;
    return [
      for (final (s, icon, label, keys) in sections)
        PaletteEntry(icon: icon, label: label, detail: l10n.paletteGoTo, shortcut: keys, run: () => app.go(s)),
      if (player.now != null) ...[
        PaletteEntry(
          icon: LucideIcons.maximize,
          label: l10n.paletteFullPlayer,
          detail: player.now!.title,
          run: () => player.setView(PlayerView.full),
        ),
        PaletteEntry(
          icon: LucideIcons.subtitles,
          label: l10n.keyTracks,
          shortcut: 'A',
          keywords: 'altyazı ses subtitle audio',
          run: () {
            player.setView(PlayerView.full);
            player.tracksPanelRequest.value = true;
          },
        ),
        PaletteEntry(icon: LucideIcons.square, label: l10n.paletteStop, keywords: 'kapat stop', run: player.stop),
      ],
      for (final s in app.sources)
        if (s.id != active?.id)
          PaletteEntry(icon: LucideIcons.arrowLeftRight, label: l10n.paletteSwitchSource(s.name), keywords: 'kaynak source', run: () => app.selectSource(s.id)),
      PaletteEntry(
        icon: LucideIcons.languages,
        label: languageCode == 'tr' ? 'English' : 'Türkçe',
        detail: l10n.paletteLanguage,
        keywords: 'dil language',
        run: () => app.setLanguage(languageCode == 'tr' ? 'en' : 'tr'),
      ),
      PaletteEntry(icon: LucideIcons.keyboard, label: l10n.setShortcuts, keywords: 'klavye keyboard', run: () => app.openSettings('shortcuts')),
      PaletteEntry(icon: LucideIcons.refreshCw, label: l10n.paletteUpdates, keywords: 'güncelle update', run: () => app.openSettings('about')),
      PaletteEntry(icon: LucideIcons.circlePlus, label: l10n.paletteAddSource, keywords: 'kaynak ekle add source', run: () => app.openSettings('sources')),
      for (final r in app.reminders.list)
        PaletteEntry(
          icon: LucideIcons.bellRing,
          label: r.title,
          detail: '${r.item.name} · ${kdClock(r.start)}',
          keywords: 'hatırlatma reminder',
          run: () => player.play(r.item, Kind.live, queue: [r.item], view: PlayerView.full),
        ),
    ];
  }

  List<(String, List<PaletteEntry>)> _groups(AppState app, PlayerController player) {
    final q = foldText(_q.text.trim());
    final commands = _commands(app, player).where((e) {
      if (q.isEmpty) return true;
      return foldText('${e.label} ${e.detail ?? ''} ${e.keywords}').contains(q);
    }).toList();
    PaletteEntry live(Item c) => PaletteEntry(
      icon: LucideIcons.tv,
      label: c.name,
      detail: c.chno == null ? null : '${c.chno}',
      run: () => player.play(c, Kind.live, queue: _live, view: PlayerView.full),
    );
    return [
      if (_byNumber case final c?)
        (l10n.paletteChannelNumber, [
          PaletteEntry(icon: LucideIcons.hash, label: c.name, detail: '${c.chno ?? _q.text.trim()}', run: () => player.play(c, Kind.live, queue: [c], view: PlayerView.full)),
        ]),
      if (commands.isNotEmpty) (l10n.paletteCommands, q.isEmpty ? commands.take(12).toList() : commands),
      if (_live.isNotEmpty) (l10n.kindChannels, [for (final c in _live) live(c)]),
      if (_movies.isNotEmpty)
        (l10n.navMovies, [
          for (final m in _movies) PaletteEntry(icon: LucideIcons.clapperboard, label: m.name, detail: m.year?.toString(), run: () => app.openDetail(m, Kind.movie)),
        ]),
      if (_series.isNotEmpty)
        (l10n.navSeries, [
          for (final s in _series) PaletteEntry(icon: LucideIcons.layers, label: s.name, detail: s.year?.toString(), run: () => app.openDetail(s, Kind.series)),
        ]),
    ];
  }

  void _run(PaletteEntry e) {
    Navigator.of(context).pop();
    e.run();
  }

  KeyEventResult _onKey(List<PaletteEntry> flat, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (k == LogicalKeyboardKey.arrowDown || k == LogicalKeyboardKey.arrowUp) {
      if (flat.isEmpty) return KeyEventResult.handled;
      final down = k == LogicalKeyboardKey.arrowDown;
      setState(() => _selected = (_selected.clamp(0, flat.length - 1) + (down ? 1 : -1)) % flat.length);
      _reveal(down);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      if (flat.isNotEmpty) _run(flat[_selected.clamp(0, flat.length - 1)]);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Keeps the selected row in view, scrolling only as far as needed.
  void _reveal(bool down) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _selectedKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 80),
        alignmentPolicy: down ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      );
    });
  }

  final _selectedKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final player = context.player;
    final groups = _groups(app, player);
    final flat = [for (final (_, list) in groups) ...list];
    final selected = flat.isEmpty ? -1 : _selected.clamp(0, flat.length - 1);
    var index = 0;
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 90, left: 16, right: 16),
        child: Material(
          color: KdColors.bg2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(KdRadius.card), side: const BorderSide(color: KdColors.line)),
          clipBehavior: Clip.antiAlias,
          elevation: 12,
          shadowColor: Colors.black,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620, maxHeight: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Focus(
                  onKeyEvent: (_, e) => _onKey(flat, e),
                  child: TextField(
                    controller: _q,
                    autofocus: true,
                    onChanged: _changed,
                    style: const TextStyle(fontSize: KdType.title),
                    decoration: InputDecoration(
                      hintText: l10n.paletteHint,
                      prefixIcon: const Icon(LucideIcons.search, size: 16, color: KdColors.muted),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
                const Divider(height: 1, color: KdColors.line),
                Flexible(
                  child: flat.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(l10n.paletteNothing, style: const TextStyle(color: KdColors.muted)),
                        )
                      : ListView(
                          controller: _scroll,
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          children: [
                            for (final (title, list) in groups) ...[
                              Padding(padding: const EdgeInsets.fromLTRB(16, 10, 16, 4), child: KdSectionLabel(title)),
                              for (final e in list)
                                () {
                                  final i = index++;
                                  return _Row(
                                    key: i == selected ? _selectedKey : null,
                                    entry: e,
                                    height: _row,
                                    selected: i == selected,
                                    onHover: () => setState(() => _selected = i),
                                    onTap: () => _run(e),
                                  );
                                }(),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({super.key, required this.entry, required this.height, required this.selected, required this.onHover, required this.onTap});

  final PaletteEntry entry;
  final double height;
  final bool selected;
  final VoidCallback onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => onHover(),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: height,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? KdColors.accentAlpha(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(KdRadius.control),
          ),
          child: Row(
            children: [
              Icon(entry.icon, size: 15, color: selected ? KdColors.accent : KdColors.muted),
              const SizedBox(width: 12),
              // Label and detail take the free width; the shortcut keeps the edge.
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: selected ? KdColors.accent2 : KdColors.text, fontWeight: selected ? FontWeight.w600 : FontWeight.w400),
                      ),
                    ),
                    if (entry.detail case final d?) ...[
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(d, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small)),
                      ),
                    ],
                  ],
                ),
              ),
              if (entry.shortcut case final s?)
                Text(s, style: const TextStyle(color: KdColors.muted, fontSize: KdType.tag, fontFamily: KdType.mono, fontFamilyFallback: KdType.monoFallback)),
            ],
          ),
        ),
      ),
    );
  }
}
