import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/platform.dart';
import '../../app/text.dart';
import '../../l10n/l10n.dart';
import '../../mobile/sheet.dart';
import '../tokens.dart';
import 'kd_controls.dart';
import 'kd_widgets.dart';
import 'kd_focus.dart';

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
    this.footer,
    this.onContext,
  });

  final String title;
  final List<KdRailEntry> entries;
  final int? selected;
  final ValueChanged<int> onSelect;

  /// Category count from which the filter box appears.
  final int filterFrom;
  final bool autofocusFilter;

  /// Below the categories (the parental lock's "locked categories" row).
  final Widget? footer;

  /// Right-click on an entry, with the pointer's global position.
  final void Function(int id, Offset at)? onContext;

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
      onSecondaryTap: widget.onContext == null ? null : (at) => widget.onContext!(e.id, at),
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
              ?widget.footer,
            ],
          ),
        ),
      ],
    );
  }
}

/// The compact layout's category choice: the current category on a button,
/// the whole rail (pinned entries, filter, locked row) in a sheet.
class KdCategoryPicker extends StatelessWidget {
  const KdCategoryPicker({
    super.key,
    required this.title,
    required this.entries,
    required this.selected,
    required this.onSelect,
    this.footer,
    this.onContext,
  });

  final String title;
  final List<KdRailEntry> entries;
  final int? selected;
  final ValueChanged<int> onSelect;
  final Widget? footer;
  final void Function(int id, Offset at)? onContext;

  void _open(BuildContext context) {
    if (androidUi) {
      showKdSheet<void>(
        context,
        heightFactor: 0.7,
        builder: (sheet) => KdCategoryRail(
          title: title,
          entries: entries,
          selected: selected,
          footer: footer,
          onContext: onContext,
          onSelect: (id) {
            Navigator.of(sheet).pop();
            onSelect(id);
          },
        ),
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: KdColors.bg2,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(KdRadius.card * 2))),
      builder: (sheet) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(sheet).height * 0.75,
          child: KdCategoryRail(
            title: title,
            entries: entries,
            selected: selected,
            footer: footer,
            onContext: onContext,
            onSelect: (id) {
              Navigator.of(sheet).pop();
              onSelect(id);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = entries.where((e) => e.id == selected).firstOrNull ?? entries.firstOrNull;
    return Semantics(
      button: true,
      label: title,
      child: KdTappable(
        onTap: () => _open(context),
        radius: 18,
        builder: (context, hover, focus) => Container(
          height: androidUi ? 52 : 44,
          padding: EdgeInsets.symmetric(horizontal: androidUi ? 16 : 12),
          decoration: BoxDecoration(
            color: androidUi ? const Color(0x0FFFFFFF) : KdColors.bg2,
            border: Border.all(
              color: focus ? KdColors.accent : (androidUi ? const Color(0x1AFFFFFF) : KdColors.line),
              width: focus ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(androidUi ? 18 : KdRadius.card),
          ),
          child: Row(
            children: [
              Icon(current?.icon ?? LucideIcons.folder, size: 16, color: KdColors.accent2),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  current?.name ?? title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              if (current?.count case final n?)
                Text('$n', style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()])),
              const SizedBox(width: 8),
              const Icon(LucideIcons.chevronDown, size: 16, color: KdColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class KdCategoryRow extends StatefulWidget {
  const KdCategoryRow({
    super.key,
    required this.name,
    required this.count,
    required this.active,
    required this.onTap,
    this.icon,
    this.onSecondaryTap,
  });

  final String name;
  final int? count;
  final bool active;
  final VoidCallback onTap;
  final IconData? icon;
  final ValueChanged<Offset>? onSecondaryTap;

  @override
  State<KdCategoryRow> createState() => _KdCategoryRowState();
}

class _KdCategoryRowState extends State<KdCategoryRow> {
  @override
  Widget build(BuildContext context) {
    final a = widget.active;
    return KdTappable(
      onTap: widget.onTap,
      onContext: widget.onSecondaryTap,
      builder: (context, hover, focus) => KdFocusRing(
        focused: focus,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 9),
          decoration: BoxDecoration(
            color: a ? KdColors.accentAlpha(0.12) : (hover ? KdColors.bg2 : Colors.transparent),
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
