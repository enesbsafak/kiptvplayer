import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/text.dart';
import '../../l10n/l10n.dart';
import '../tokens.dart';
import 'kd_controls.dart';
import 'kd_widgets.dart';

/// One row of a [KdCategoryRail]: a pinned entry ("All", "Favorites") or a
/// provider category.
class KdRailEntry {
  const KdRailEntry({required this.id, required this.name, this.count, this.icon, this.pinned = false});

  final int id;
  final String name;
  final int? count;
  final IconData? icon;

  /// Pinned entries stay on top and are never filtered out.
  final bool pinned;
}

/// The category list of Live TV, Movies and Series: pinned entries, a rule,
/// then the provider's categories in their order. Long lists (real
/// providers have hundreds) get a filter box.
class KdCategoryRail extends StatefulWidget {
  const KdCategoryRail({
    super.key,
    required this.title,
    required this.entries,
    required this.selected,
    required this.onSelect,
    this.filterFrom = 12,
    this.autofocusFilter = false,
  });

  final String title;
  final List<KdRailEntry> entries;
  final int? selected;
  final ValueChanged<int> onSelect;

  /// Category count from which the filter box appears.
  final int filterFrom;
  final bool autofocusFilter;

  @override
  State<KdCategoryRail> createState() => _KdCategoryRailState();
}

class _KdCategoryRailState extends State<KdCategoryRail> {
  final _filter = TextEditingController();

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pinned = widget.entries.where((e) => e.pinned).toList();
    final cats = widget.entries.where((e) => !e.pinned).toList();
    final q = foldText(_filter.text.trim());
    final shown = q.isEmpty ? cats : cats.where((c) => foldText(c.name).contains(q)).toList();
    Widget row(KdRailEntry e) => KdCategoryRow(
      name: e.name,
      count: e.count,
      icon: e.icon,
      active: widget.selected == e.id,
      onTap: () => widget.onSelect(e.id),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 8), child: KdSectionLabel(widget.title)),
        if (cats.length >= widget.filterFrom)
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: KdInput(
              controller: _filter,
              hint: l10n.railFilterHint,
              prefix: LucideIcons.search,
              autofocus: widget.autofocusFilter,
              onChanged: (_) => setState(() {}),
            ),
          ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 12),
            children: [
              for (final e in pinned) row(e),
              if (pinned.isNotEmpty && cats.isNotEmpty)
                const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(height: 1, color: KdColors.line)),
              for (final e in shown) row(e),
              if (q.isNotEmpty && shown.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Text(l10n.railNoMatch, style: const TextStyle(color: KdColors.muted, fontSize: KdType.small)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class KdCategoryRow extends StatefulWidget {
  const KdCategoryRow({super.key, required this.name, required this.count, required this.active, required this.onTap, this.icon});

  final String name;
  final int? count;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  State<KdCategoryRow> createState() => _KdCategoryRowState();
}

class _KdCategoryRowState extends State<KdCategoryRow> {
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

/// A horizontal list a mouse wheel can scroll: Flutter only moves
/// horizontal scrollables on horizontal deltas (trackpads, Shift+wheel),
/// so an ordinary wheel did nothing on desktop.
class KdWheelScroll extends StatefulWidget {
  const KdWheelScroll({super.key, required this.builder});

  /// Builds the horizontal scrollable with the given controller.
  final Widget Function(ScrollController controller) builder;

  @override
  State<KdWheelScroll> createState() => _KdWheelScrollState();
}

class _KdWheelScrollState extends State<KdWheelScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSignal(PointerSignalEvent e) {
    if (e is! PointerScrollEvent || !_controller.hasClients) return;
    final d = e.scrollDelta;
    // Horizontal input already works; translate the vertical wheel only.
    if (d.dx != 0 || d.dy == 0) return;
    final p = _controller.position;
    final to = (p.pixels + d.dy).clamp(p.minScrollExtent, p.maxScrollExtent);
    if (to == p.pixels) return;
    GestureBinding.instance.pointerSignalResolver.register(e, (_) => _controller.jumpTo(to));
  }

  @override
  Widget build(BuildContext context) {
    return Listener(onPointerSignal: _onSignal, child: widget.builder(_controller));
  }
}
