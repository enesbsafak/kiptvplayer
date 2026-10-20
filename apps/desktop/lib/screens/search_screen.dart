import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_widgets.dart';
import '../player/player_controller.dart';
import 'vod_screen.dart';

/// Search across live, movies and series as you type.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.onOpen});

  final void Function(Item item, Kind kind) onOpen;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  List<Item> _live = const [];
  List<Item> _movies = const [];
  List<Item> _series = const [];
  bool _searched = false;
  int _token = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 120), () => _run(v));
  }

  Future<void> _run(String q) async {
    final token = ++_token;
    if (q.trim().isEmpty) {
      setState(() {
        _live = _movies = _series = const [];
        _searched = false;
      });
      return;
    }
    final lib = context.library;
    final r = await Future.wait([
      lib.search(q, kind: Kind.live, limit: 40),
      lib.search(q, kind: Kind.movie, limit: 30),
      lib.search(q, kind: Kind.series, limit: 30),
    ]);
    if (!mounted || token != _token) return;
    setState(() {
      _live = r[0];
      _movies = r[1];
      _series = r[2];
      _searched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final empty = _searched && _live.isEmpty && _movies.isEmpty && _series.isEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
          child: KdInput(
            controller: _q,
            focusNode: _focus,
            hint: 'Kanal, film veya dizi ara',
            prefix: LucideIcons.search,
            onChanged: _changed,
          ),
        ),
        Expanded(
          child: !_searched
              ? const KdEmpty(icon: LucideIcons.search, title: 'Ne izlemek istersiniz?', hint: 'Yazmaya başlayın; Türkçe karakterler olmadan da bulur.')
              : empty
                  ? KdEmpty(icon: LucideIcons.search, title: '“${_q.text}” için sonuç yok')
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                      children: [
                        if (_live.isNotEmpty) ...[
                          KdSectionLabel('Kanallar · ${_live.length}'),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final c in _live)
                                _ChannelChip(item: c, onTap: () => context.player.play(c, Kind.live, queue: _live, view: PlayerView.full)),
                            ],
                          ),
                          const SizedBox(height: 22),
                        ],
                        if (_movies.isNotEmpty) ...[
                          KdSectionLabel('Filmler · ${_movies.length}'),
                          const SizedBox(height: 10),
                          _PosterWrap(items: _movies, onTap: (m) => widget.onOpen(m, Kind.movie)),
                          const SizedBox(height: 22),
                        ],
                        if (_series.isNotEmpty) ...[
                          KdSectionLabel('Diziler · ${_series.length}'),
                          const SizedBox(height: 10),
                          _PosterWrap(items: _series, onTap: (s) => widget.onOpen(s, Kind.series)),
                        ],
                      ],
                    ),
        ),
      ],
    );
  }
}

class _ChannelChip extends StatefulWidget {
  const _ChannelChip({required this.item, required this.onTap});

  final Item item;
  final VoidCallback onTap;

  @override
  State<_ChannelChip> createState() => _ChannelChipState();
}

class _ChannelChipState extends State<_ChannelChip> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: _hover ? KdColors.bg3 : KdColors.bg2,
            border: Border.all(color: _hover ? KdColors.buttonHoverBorder : KdColors.line),
            borderRadius: BorderRadius.circular(KdRadius.card),
          ),
          child: Row(
            children: [
              KdArt(url: widget.item.logo, label: widget.item.name, width: 30, height: 30, contain: true),
              const SizedBox(width: 9),
              Expanded(child: Text(widget.item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500))),
              Icon(LucideIcons.play, size: 13, color: _hover ? KdColors.accent : KdColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class _PosterWrap extends StatelessWidget {
  const _PosterWrap({required this.items, required this.onTap});

  final List<Item> items;
  final ValueChanged<Item> onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 14,
      runSpacing: 16,
      children: [for (final m in items) PosterCard(width: 128, item: m, onTap: () => onTap(m))],
    );
  }
}
