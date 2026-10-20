import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../player/player_controller.dart';
import 'vod_screen.dart';

/// Favourite channels, movies and series of the active source.
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key, required this.onOpen});

  final void Function(Item item, Kind kind) onOpen;

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  Kind _tab = Kind.live;
  List<Item> _items = const [];
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final sid = context.app.activeSource?.id;
    if (sid == null) return;
    final items = await context.library.favorites(sid, _tab);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loaded = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 12),
          child: Row(
            children: [
              const Text('Favoriler', style: TextStyle(fontSize: KdType.display, fontWeight: FontWeight.w600)),
              const SizedBox(width: 18),
              for (final (k, label) in const [(Kind.live, 'Kanallar'), (Kind.movie, 'Filmler'), (Kind.series, 'Diziler')]) ...[
                KdPill(
                  label: label,
                  selected: _tab == k,
                  onTap: () {
                    setState(() => _tab = k);
                    _load();
                  },
                ),
                const SizedBox(width: 6),
              ],
            ],
          ),
        ),
        Expanded(
          child: _loaded && _items.isEmpty
              ? const KdEmpty(icon: LucideIcons.star, title: 'Henüz favori yok', hint: 'Kanalları ve içerikleri favoriye ekleyerek burada toplayın.')
              : _tab == Kind.live
                  ? ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1, color: KdColors.rowDivider),
                      itemBuilder: (context, i) {
                        final c = _items[i];
                        return InkWell(
                          onTap: () => context.player.play(c, Kind.live, queue: _items, view: PlayerView.full),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                            child: Row(
                              children: [
                                KdArt(url: c.logo, label: c.name, width: 36, height: 36, contain: true),
                                const SizedBox(width: 12),
                                Expanded(child: Text(c.name, style: const TextStyle(fontWeight: FontWeight.w500))),
                                KdButton(
                                  label: 'Kaldır',
                                  kind: KdButtonKind.ghost,
                                  onPressed: () async {
                                    await context.library.setFavorite(c.id, false);
                                    _load();
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 170,
                        mainAxisSpacing: 18,
                        crossAxisSpacing: 14,
                        childAspectRatio: 0.58,
                      ),
                      itemCount: _items.length,
                      itemBuilder: (context, i) => PosterCard(item: _items[i], onTap: () => widget.onOpen(_items[i], _tab)),
                    ),
        ),
      ],
    );
  }
}
