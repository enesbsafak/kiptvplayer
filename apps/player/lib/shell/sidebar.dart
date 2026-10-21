import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/app_state.dart';
import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_widgets.dart';
import '../l10n/l10n.dart';

class NavEntry {
  const NavEntry(this.section, this.icon, this.label, [this.shortcut]);
  final Section section;
  final IconData icon;
  final String label;
  final String? shortcut;
}

List<NavEntry> get mainNav => [
  NavEntry(Section.home, LucideIcons.house, l10n.navHome, 'Ctrl 1'),
  NavEntry(Section.live, LucideIcons.tv, l10n.navLive, 'Ctrl 2'),
  NavEntry(Section.guide, LucideIcons.calendarRange, l10n.navGuide, 'Ctrl 3'),
  NavEntry(Section.movies, LucideIcons.clapperboard, l10n.navMovies, 'Ctrl 4'),
  NavEntry(Section.series, LucideIcons.layers, l10n.navSeries, 'Ctrl 5'),
  NavEntry(Section.favorites, LucideIcons.star, l10n.navFavorites, 'Ctrl 6'),
];

/// Left navigation: source switcher, sections, settings. 216 px wide.
class Sidebar extends StatelessWidget {
  const Sidebar({super.key});

  static const width = 216.0;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return Container(
      width: width,
      color: KdColors.bg,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(10, 10, 10, 6), child: SourceSwitcher()),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: KdSectionLabel(l10n.navLibrary),
          ),
          for (final e in mainNav)
            _NavItem(entry: e, active: app.section == e.section, onTap: () => app.go(e.section)),
          const Spacer(),
          _NavItem(
            entry: NavEntry(Section.search, LucideIcons.search, l10n.navSearch, 'Ctrl K'),
            active: app.section == Section.search,
            onTap: () => app.go(Section.search),
          ),
          _NavItem(
            entry: NavEntry(Section.settings, LucideIcons.settings, l10n.navSettings, 'Ctrl ,'),
            active: app.section == Section.settings,
            onTap: () => app.go(Section.settings),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// The compact layout's bottom bar: the five most used sections. The guide,
/// search and settings sit in the top bar.
class CompactNavBar extends StatelessWidget {
  const CompactNavBar({super.key});

  static const height = 58.0;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final entries = mainNav.where((e) => e.section != Section.guide);
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: KdColors.bg,
        border: Border(top: BorderSide(color: KdColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (final e in entries)
                Expanded(
                  child: Semantics(
                    button: true,
                    selected: app.section == e.section,
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => app.go(e.section),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(e.icon, size: 20, color: app.section == e.section ? KdColors.accent2 : KdColors.muted),
                          const SizedBox(height: 4),
                          Text(
                            e.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: KdType.chip,
                              color: app.section == e.section ? KdColors.accent2 : KdColors.muted,
                              fontWeight: app.section == e.section ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({required this.entry, required this.active, required this.onTap});

  final NavEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          height: 34,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active
                ? KdColors.accentAlpha(0.12)
                : _hover
                    ? KdColors.bg2
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(KdRadius.control),
          ),
          child: Row(
            children: [
              Icon(
                widget.entry.icon,
                size: 16,
                color: active ? KdColors.accent2 : (_hover ? KdColors.text : KdColors.muted),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.entry.label,
                  style: TextStyle(
                    color: active ? KdColors.accent2 : KdColors.text,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
              if (_hover && widget.entry.shortcut != null) KdKbd(widget.entry.shortcut!),
            ],
          ),
        ),
      ),
    );
  }
}

/// Active source card; opens a menu to switch or add sources.
class SourceSwitcher extends StatelessWidget {
  const SourceSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.activeSource;
    return MenuAnchor(
      style: const MenuStyle(
        backgroundColor: WidgetStatePropertyAll(KdColors.bg2),
        side: WidgetStatePropertyAll(BorderSide(color: KdColors.line)),
        shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(KdRadius.card)))),
      ),
      menuChildren: [
        for (final src in app.sources)
          MenuItemButton(
            onPressed: () => app.selectSource(src.id),
            leadingIcon: Icon(
              src.id == s?.id ? LucideIcons.check : LucideIcons.dot,
              size: 14,
              color: src.id == s?.id ? KdColors.accent : KdColors.muted,
            ),
            child: Text(src.name),
          ),
        const Divider(height: 1, color: KdColors.line),
        MenuItemButton(
          onPressed: () => app.go(Section.settings),
          leadingIcon: const Icon(LucideIcons.plus, size: 14, color: KdColors.muted),
          child: Text(l10n.sourceAddEllipsis),
        ),
      ],
      builder: (context, controller, _) => _SourceCard(
        source: s,
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}

class _SourceCard extends StatefulWidget {
  const _SourceCard({required this.source, required this.onTap});

  final SourceInfo? source;
  final VoidCallback onTap;

  @override
  State<_SourceCard> createState() => _SourceCardState();
}

class _SourceCardState extends State<_SourceCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.source;
    final healthy = s != null && s.lastError == null;
    final total = s == null ? 0 : (s.liveCount + s.movieCount + s.seriesCount).toInt();
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
          decoration: BoxDecoration(
            color: _hover ? KdColors.bg3 : KdColors.bg2,
            border: Border.all(color: KdColors.line),
            borderRadius: BorderRadius.circular(KdRadius.card),
          ),
          child: Row(
            children: [
              KdStatusDot(running: healthy),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s?.name ?? l10n.sourceNone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      s == null
                          ? l10n.sourceAddOne
                          : s.lastError != null
                              ? l10n.sourceSyncError
                              : l10n.sourceItemCount(_thousands(total)),
                      style: TextStyle(
                        fontSize: KdType.chip,
                        color: s?.lastError != null ? KdColors.err : KdColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(LucideIcons.chevronsUpDown, size: 14, color: KdColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

String _thousands(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(l10n.thousandsSeparator);
    b.write(s[i]);
  }
  return b.toString();
}

/// Kind for the movies / series sections.
Kind kindOf(Section s) => switch (s) {
  Section.movies => Kind.movie,
  Section.series => Kind.series,
  _ => Kind.live,
};
