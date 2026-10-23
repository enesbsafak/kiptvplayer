import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../app/app_state.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_focus.dart';
import '../design/widgets/kd_widgets.dart';
import '../l10n/l10n.dart';
import '../player/player_controller.dart';
import '../screens/add_source.dart';
import '../screens/player_screen.dart';
import '../shell/reminder_banner.dart';
import '../shell/sidebar.dart' show mainNav, NavEntry;
import 'controls.dart';
import 'glass.dart';
import 'sheet.dart';

/// The Android phone layout: the sections between a glass top bar and a
/// floating glass navigation bar, over the ambient space of the icon.
/// Sections cross-fade (Material's fade through), the system back gesture
/// shrinks the screen as it is dragged (the predictive back), the player
/// rises from the bottom and the playing stream waits in a glass bar above
/// the navigation while the user browses.
class MobileShell extends StatefulWidget {
  const MobileShell({super.key, required this.content});

  /// The current section's screen (the same screens as every layout).
  final Widget Function(AppState app) content;

  static const topBarHeight = 60.0;
  static const navHeight = 66.0;
  static const miniHeight = 64.0;

  @override
  State<MobileShell> createState() => _MobileShellState();
}

class _MobileShellState extends State<MobileShell> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  /// Progress of a predictive back gesture, 0 (none) to 1 (fully dragged).
  late final _back = AnimationController(vsync: this, duration: KdMotionM3.medium);
  SwipeEdge _edge = SwipeEdge.left;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _back.dispose();
    super.dispose();
  }

  // ---- the predictive back --------------------------------------------
  //
  // Android only sends the gesture to the app while something in it can go
  // back (a PopScope that cannot pop: a section other than home, an open
  // detail). Routes on top (a sheet, a dialog) and the player animate their
  // own way, so the shell leaves those alone.

  @override
  bool handleStartBackGesture(PredictiveBackEvent e) {
    if (!mounted || context.player.view == PlayerView.full) return false;
    if (Navigator.maybeOf(context)?.canPop() ?? false) return false;
    _edge = e.swipeEdge;
    _back.value = 0;
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent e) => _back.value = e.progress;

  @override
  void handleCommitBackGesture() {
    _back.animateBack(0, curve: KdMotionM3.emphasized);
    // The same path as the back button: the PopScopes decide where it goes.
    Navigator.maybeOf(context)?.maybePop();
  }

  @override
  void handleCancelBackGesture() => _back.animateBack(0, curve: KdMotionM3.emphasizedDecelerate);

  /// Android's in-app back animation: the screen shrinks to 90 %, slides a
  /// little away from the edge the finger came from and rounds its corners.
  Widget _shrinkable(Widget child) {
    return AnimatedBuilder(
      animation: _back,
      child: child,
      builder: (context, child) {
        final t = _back.value;
        if (t == 0) return child!;
        final width = MediaQuery.sizeOf(context).width;
        final shift = (width / 20 - 8) * t * (_edge == SwipeEdge.left ? 1 : -1);
        return Transform.translate(
          offset: Offset(shift, 0),
          child: Transform.scale(
            scale: 1 - 0.1 * t,
            child: ClipRRect(borderRadius: BorderRadius.circular(32 * t), child: child),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final player = context.player;
    final full = player.view == PlayerView.full;
    if (app.sources.isEmpty) {
      return const Stack(
        fit: StackFit.expand,
        children: [
          KdAmbient(),
          SafeArea(child: OnboardingScreen()),
        ],
      );
    }
    final mq = MediaQuery.of(context);
    final mini = player.view == PlayerView.preview && player.now != null;
    // While typing the keyboard takes the bottom: the bars step aside, as in
    // Android's own apps.
    final typing = View.of(context).viewInsets.bottom > 0;
    final navBottom = math.max(mq.padding.bottom, 10.0) + 6;
    // What floats over the bottom of the content: lists end above it.
    final overlay = typing ? 8.0 : navBottom + MobileShell.navHeight + (mini ? MobileShell.miniHeight + 8 : 0) + 8;
    final top = mq.padding.top + MobileShell.topBarHeight;
    return Stack(
      fit: StackFit.expand,
      children: [
        const KdAmbient(),
        BackdropGroup(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                top: top,
                child: _shrinkable(
                  MediaQuery(
                    data: mq.copyWith(
                      padding: mq.padding.copyWith(top: 0, bottom: overlay),
                      viewPadding: mq.viewPadding.copyWith(top: 0, bottom: overlay),
                    ),
                    child: _SectionSwitcher(section: app.section, child: widget.content(app)),
                  ),
                ),
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _TopBar(app: app, height: top),
              ),
              if (!typing)
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: navBottom,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedSize(
                        duration: KdMotionM3.medium,
                        curve: KdMotionM3.emphasized,
                        alignment: Alignment.bottomCenter,
                        child: mini
                            ? Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _MiniBar(player: player),
                              )
                            : const SizedBox(width: double.infinity),
                      ),
                      _NavBar(app: app),
                    ],
                  ),
                ),
              Positioned(
                top: top + 8,
                left: 12,
                right: 12,
                child: const Center(child: ReminderBanner()),
              ),
            ],
          ),
        ),
        if (full) const Positioned.fill(child: _Rise(child: PlayerScreen())),
      ],
    );
  }
}

/// Fade through: the old section fades out quickly, the new one fades in
/// growing from 96 %, as Android moves between top-level destinations.
class _SectionSwitcher extends StatelessWidget {
  const _SectionSwitcher({required this.section, required this.child});

  final Section section;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: KdMotionM3.medium,
      switchInCurve: const Interval(0.3, 1, curve: KdMotionM3.emphasizedDecelerate),
      switchOutCurve: const Interval(0.7, 1, curve: Curves.easeOut),
      layoutBuilder: (current, previous) => Stack(fit: StackFit.expand, children: [...previous, ?current]),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: ScaleTransition(scale: Tween(begin: 0.96, end: 1.0).animate(a), child: child),
      ),
      child: KeyedSubtree(key: ValueKey(section), child: child),
    );
  }
}

/// The player comes up from below.
class _Rise extends StatelessWidget {
  const _Rise({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: KdMotionM3.medium,
      curve: KdMotionM3.emphasizedDecelerate,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 48 * (1 - t)), child: child),
      ),
    );
  }
}

/// The source (tap to switch), then the guide, search and settings. Glass
/// from the very top of the screen, under the status bar.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.app, required this.height});

  final AppState app;
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget action(IconData icon, String tip, Section s) => AndroidIconButton(
      icon: icon,
      tooltip: tip,
      color: app.section == s ? KdColors.accent2 : KdColors.text,
      onPressed: () {
        HapticFeedback.selectionClick();
        app.go(s);
      },
    );
    return KdGlass(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(KdGlassTokens.radiusBar)),
      child: SizedBox(
        height: height,
        child: Padding(
          padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top, left: 8, right: 4),
          child: Row(
            children: [
              Expanded(child: _SourceTitle(app: app)),
              action(LucideIcons.calendarRange, l10n.navGuide, Section.guide),
              action(LucideIcons.search, l10n.navSearch, Section.search),
              action(LucideIcons.settings, l10n.navSettings, Section.settings),
            ],
          ),
        ),
      ),
    );
  }
}

/// The glowing mark and the active source; a sheet switches sources.
class _SourceTitle extends StatelessWidget {
  const _SourceTitle({required this.app});

  final AppState app;

  Future<void> _switch(BuildContext context) async {
    final sources = app.sources;
    final picked = await showKdActionSheet(
      context,
      title: l10n.navLibrary,
      entries: [
        for (final s in sources) (s.id == app.activeSource?.id ? LucideIcons.circleCheck : LucideIcons.circle, s.name),
        null,
        (LucideIcons.plus, l10n.sourceAddEllipsis),
      ],
    );
    if (picked == null) return;
    if (picked < sources.length) {
      app.selectSource(sources[picked].id);
    } else {
      app.go(Section.settings);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = app.activeSource;
    return Semantics(
      button: true,
      label: s?.name,
      child: KdTappable(
        onTap: () => _switch(context),
        radius: 20,
        builder: (context, hover, focus) => Container(
          height: 44,
          padding: const EdgeInsets.only(left: 4, right: 8),
          decoration: BoxDecoration(
            border: focus ? Border.all(color: KdColors.accent, width: 2) : null,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: KdColors.accent.withValues(alpha: 0.35), blurRadius: 16)],
                ),
                child: Image.asset('assets/brand/logo.png', width: 34, height: 34),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s?.name ?? l10n.sourceNone,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: KdType.title, fontWeight: FontWeight.w700, height: 1.15),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        KdStatusDot(running: s != null && s.lastError == null),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            s?.lastError != null ? l10n.sourceSyncError : l10n.navLibrary,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: KdType.chip,
                              color: s?.lastError != null ? KdColors.err : KdColors.muted,
                              height: 1.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Icon(LucideIcons.chevronDown, size: 16, color: KdColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}

/// The floating navigation: five sections in a glass capsule; a lit pill
/// slides to the current one.
class _NavBar extends StatelessWidget {
  const _NavBar({required this.app});

  final AppState app;

  static List<NavEntry> get entries => mainNav.where((e) => e.section != Section.guide).toList();

  @override
  Widget build(BuildContext context) {
    final items = entries;
    final index = items.indexWhere((e) => e.section == app.section);
    return KdGlass(
      borderRadius: BorderRadius.circular(KdGlassTokens.radiusBar + 6),
      child: SizedBox(
        height: MobileShell.navHeight,
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth / items.length;
            return Stack(
              children: [
                // The lit pill: under the current section, gone on the
                // guide, search and settings (reached from the top bar).
                AnimatedPositioned(
                  duration: KdMotionM3.long,
                  curve: KdMotionM3.emphasized,
                  left: (index < 0 ? 0 : index) * w + 6,
                  top: 6,
                  width: w - 12,
                  height: MobileShell.navHeight - 12,
                  child: AnimatedOpacity(
                    duration: KdMotionM3.short,
                    opacity: index < 0 ? 0 : 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(KdGlassTokens.radiusBar),
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [KdColors.accentAlpha(0.24), KdColors.accentAlpha(0.10)],
                        ),
                        border: Border.all(color: KdColors.accentAlpha(0.35)),
                        boxShadow: [BoxShadow(color: KdColors.accentAlpha(0.22), blurRadius: 18)],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final e in items)
                      Expanded(
                        child: _NavItem(
                          entry: e,
                          active: e.section == app.section,
                          onTap: () {
                            if (e.section != app.section) HapticFeedback.selectionClick();
                            app.go(e.section);
                          },
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({required this.entry, required this.active, required this.onTap});

  final NavEntry entry;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? KdColors.accent2 : KdColors.muted;
    return Semantics(
      button: true,
      selected: active,
      child: KdTappable(
        onTap: onTap,
        radius: KdGlassTokens.radiusBar,
        builder: (context, hover, focus) => Container(
          decoration: BoxDecoration(
            border: focus ? Border.all(color: KdColors.accent, width: 2) : null,
            borderRadius: BorderRadius.circular(KdGlassTokens.radiusBar),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedScale(
                scale: active ? 1.08 : 1,
                duration: KdMotionM3.medium,
                curve: KdMotionM3.emphasized,
                child: Icon(entry.icon, size: 22, color: color),
              ),
              const SizedBox(height: 3),
              Text(
                entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: KdType.chip, height: 1.1, color: color, fontWeight: active ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The stream playing while the user browses: a glass bar above the
/// navigation. A tap (or a swipe up) opens the player.
class _MiniBar extends StatelessWidget {
  const _MiniBar({required this.player});

  final PlayerController player;

  @override
  Widget build(BuildContext context) {
    final now = player.now!;
    final programme = now.isLive ? context.epg.now(now.item.id) : null;
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -200) player.setView(PlayerView.full);
      },
      child: KdGlass(
        borderRadius: BorderRadius.circular(KdGlassTokens.radiusCard),
        child: KdTappable(
          onTap: () => player.setView(PlayerView.full),
          radius: KdGlassTokens.radiusCard,
          builder: (context, hover, focus) => SizedBox(
            height: MobileShell.miniHeight,
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 85,
                      height: 48,
                      child: ColoredBox(color: Colors.black, child: player.engine.surface()),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        now.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          if (now.isLive) ...[KdTag(l10n.tagLive), const SizedBox(width: 6)],
                          Flexible(
                            child: Text(
                              programme?.title ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: KdType.small, color: KdColors.muted),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                AndroidIconButton(
                  icon: player.playing ? LucideIcons.pause : LucideIcons.play,
                  tooltip: l10n.tipPlayPause,
                  onPressed: player.togglePause,
                ),
                AndroidIconButton(icon: LucideIcons.x, tooltip: l10n.tipClose, color: KdColors.muted, onPressed: player.stop),
                const SizedBox(width: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
