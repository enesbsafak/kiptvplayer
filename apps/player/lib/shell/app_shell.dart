import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../app/app_state.dart';
import '../app/library.dart';
import '../app/platform.dart';
import '../app/scope.dart';
import '../app/updates.dart';
import '../design/layout.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart';
import '../design/widgets/kd_icon_button.dart';
import '../design/widgets/kd_titlebar.dart';
import '../l10n/l10n.dart';
import '../mobile/mobile_shell.dart';
import '../player/player_controller.dart';
import '../screens/add_source.dart';
import '../screens/favorites_screen.dart';
import '../screens/guide_screen.dart';
import '../screens/home_screen.dart';
import '../screens/live_screen.dart';
import '../screens/player_screen.dart';
import 'command_palette.dart';
import 'reminder_banner.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/vod_screen.dart';
import 'sidebar.dart';

/// Window frame: titlebar, sidebar, section content, player overlay,
/// mini player and global shortcuts.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with WindowListener {
  bool _osFullscreen = false;

  @override
  void initState() {
    super.initState();
    if (isDesktopOs) windowManager.addListener(this);
  }

  @override
  void dispose() {
    if (isDesktopOs) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowEnterFullScreen() => setState(() => _osFullscreen = true);

  @override
  void onWindowLeaveFullScreen() => setState(() => _osFullscreen = false);

  Map<ShortcutActivator, VoidCallback> _shortcuts(AppState app) => {
    const SingleActivator(LogicalKeyboardKey.digit1, control: true): () => app.go(Section.home),
    const SingleActivator(LogicalKeyboardKey.digit2, control: true): () => app.go(Section.live),
    const SingleActivator(LogicalKeyboardKey.digit3, control: true): () => app.go(Section.guide),
    const SingleActivator(LogicalKeyboardKey.digit4, control: true): () => app.go(Section.movies),
    const SingleActivator(LogicalKeyboardKey.digit5, control: true): () => app.go(Section.series),
    const SingleActivator(LogicalKeyboardKey.digit6, control: true): () => app.go(Section.favorites),
    const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => showCommandPalette(context),
    const SingleActivator(LogicalKeyboardKey.comma, control: true): () => app.go(Section.settings),
  };

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final player = context.player;
    return ListenableBuilder(
      listenable: Listenable.merge([app, player]),
      builder: (context, _) {
        if (!app.loaded) return const ColoredBox(color: KdColors.bg);
        final full = player.view == PlayerView.full;
        // Android's back: out of the player (PlayerScreen), then home, then out.
        return PopScope(
          canPop: !full && (app.section == Section.home || app.sources.isEmpty),
          onPopInvokedWithResult: (didPop, _) {
            // An open detail first, then the section.
            if (!didPop && !full && !app.popInner()) app.go(Section.home);
          },
          child: CallbackShortcuts(
            bindings: _shortcuts(app),
            child: Focus(
              // On a TV the sidebar's current section takes the focus.
              autofocus: !isTv,
              // It holds the shortcuts; the arrows never move onto it.
              skipTraversal: true,
              // A TV keeps the sidebar: a remote moves along a left rail far
              // better than along a bottom bar.
              child: isCompact(context) && !isTv
                  ? (androidUi ? MobileShell(content: _content) : _compact(app, player))
                  : _wide(app, player),
            ),
          ),
        );
      },
    );
  }

  /// Desktop, tablets held sideways and TVs: sidebar and content (and the
  /// titlebar on desktop).
  Widget _wide(AppState app, PlayerController player) {
    final full = player.view == PlayerView.full;
    final hideChrome = full && _osFullscreen;
    // A window of our own (titlebar, frame); a TV, even previewed on a
    // desktop with --kp-tv, is laid out like a tablet.
    final desktop = isDesktopOs && !isTv;
    final body = Column(
      children: [
        if (!hideChrome && desktop)
          KdTitlebar(
            actions: [
              if (app.sources.isNotEmpty)
                const _UpdateBadge(),
                KdIconButton(icon: LucideIcons.search, tooltip: l10n.tipSearch, onPressed: () => app.go(Section.search)),
              if (app.sources.isNotEmpty)
                KdIconButton(icon: LucideIcons.settings, tooltip: l10n.tipSettings, onPressed: () => app.go(Section.settings)),
            ],
          ),
        Expanded(
          child: app.sources.isEmpty
              ? const OnboardingScreen()
              : Stack(
                  fit: StackFit.expand,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Sidebar(),
                        const VerticalDivider(width: 1, thickness: 1, color: KdColors.line),
                        Expanded(child: _content(app)),
                      ],
                    ),
                    if (player.view == PlayerView.preview && app.section != Section.live)
                      const Positioned(right: 18, bottom: 18, child: _MiniPlayer()),
                    if (full && desktop) const Positioned.fill(child: PlayerScreen()),
                    const Positioned(top: 14, right: 18, child: ReminderBanner()),
                  ],
                ),
        ),
      ],
    );
    if (desktop) {
      return DecoratedBox(
        decoration: BoxDecoration(border: hideChrome ? null : Border.all(color: KdColors.line)),
        child: body,
      );
    }
    // A tablet: system bars around the app, the player over all of it.
    return Stack(
      fit: StackFit.expand,
      children: [
        SafeArea(child: body),
        if (full) const Positioned.fill(child: PlayerScreen()),
      ],
    );
  }

  /// Phones and tablets held upright: top bar, one pane, bottom bar.
  Widget _compact(AppState app, PlayerController player) {
    final full = player.view == PlayerView.full;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: [
            SafeArea(
              bottom: false,
              child: app.sources.isEmpty ? const SizedBox(height: 8) : _CompactTopBar(app: app),
            ),
            Expanded(
              child: app.sources.isEmpty
                  ? const SafeArea(top: false, child: OnboardingScreen())
                  : Stack(
                      fit: StackFit.expand,
                      children: [
                        _content(app),
                        if (player.view == PlayerView.preview)
                          const Positioned(right: 12, bottom: 12, child: _MiniPlayer(width: 208)),
                        const Positioned(top: 8, left: 12, right: 12, child: Center(child: ReminderBanner())),
                      ],
                    ),
            ),
            if (app.sources.isNotEmpty) const CompactNavBar(),
          ],
        ),
        if (full) const Positioned.fill(child: PlayerScreen()),
      ],
    );
  }

  Widget _content(AppState app) {
    void open(Item item, Kind kind) => app.openDetail(item, kind);
    final pending = app.pendingDetail;
    return switch (app.section) {
      Section.home => HomeScreen(onOpen: open),
      Section.live => const LiveScreen(),
      Section.guide => const GuideScreen(),
      Section.movies => VodScreen(
        key: ValueKey('movies-${app.detailNonce}'),
        kind: Kind.movie,
        initialDetail: pending,
      ),
      Section.series => VodScreen(
        key: ValueKey('series-${app.detailNonce}'),
        kind: Kind.series,
        initialDetail: pending,
      ),
      Section.favorites => FavoritesScreen(onOpen: open),
      Section.search => SearchScreen(onOpen: open),
      Section.settings => const SettingsScreen(),
    };
  }
}

/// Keeps a stream playing in a corner while the user browses elsewhere.
class _MiniPlayer extends StatefulWidget {
  const _MiniPlayer({this.width = 336});

  final double width;

  @override
  State<_MiniPlayer> createState() => _MiniPlayerState();
}

class _MiniPlayerState extends State<_MiniPlayer> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final player = context.player;
    final now = player.now;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Container(
        width: widget.width,
        height: widget.width * 9 / 16,
        decoration: BoxDecoration(
          color: Colors.black,
          border: Border.all(color: KdColors.line),
          borderRadius: BorderRadius.circular(KdRadius.card),
          boxShadow: const [BoxShadow(color: Color(0x99000000), blurRadius: 24, offset: Offset(0, 8))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              // Touch has no hover to reveal the buttons: a tap expands.
              onTap: isMobileOs ? () => player.setView(PlayerView.full) : null,
              onDoubleTap: () => player.setView(PlayerView.full),
              child: player.engine.surface(),
            ),
            AnimatedOpacity(
              opacity: _hover ? 1 : 0,
              duration: const Duration(milliseconds: 140),
              child: Container(
                color: const Color(0x990B0B10),
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(now?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        KdIconButton(icon: player.playing ? LucideIcons.pause : LucideIcons.play, tooltip: l10n.tipPlayPause, onPressed: player.togglePause),
                        KdIconButton(icon: LucideIcons.maximize, tooltip: l10n.tipExpand, onPressed: () => player.setView(PlayerView.full)),
                        KdIconButton(icon: LucideIcons.x, tooltip: l10n.tipClose, onPressed: player.stop),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The compact layout's top bar: the source, then the guide, search and
/// settings (the bottom bar holds the other sections).
class _CompactTopBar extends StatelessWidget {
  const _CompactTopBar({required this.app});

  final AppState app;

  @override
  Widget build(BuildContext context) {
    Widget icon(IconData i, String tip, Section s) => KdIconButton(
      icon: i,
      tooltip: tip,
      color: app.section == s ? KdColors.accent2 : null,
      extent: 44,
      onPressed: () => app.go(s),
    );
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: KdColors.line))),
      child: Row(
        children: [
          const Expanded(child: SourceSwitcher()),
          const SizedBox(width: 6),
          icon(LucideIcons.calendarRange, l10n.navGuide, Section.guide),
          icon(LucideIcons.search, l10n.navSearch, Section.search),
          icon(LucideIcons.settings, l10n.navSettings, Section.settings),
        ],
      ),
    );
  }
}


/// A quiet pill in the title bar while an update waits; opens Settings › About.
class _UpdateBadge extends StatelessWidget {
  const _UpdateBadge();

  @override
  Widget build(BuildContext context) {
    final u = context.updates;
    return ListenableBuilder(
      listenable: u,
      builder: (context, _) {
        final show = u.phase == UpdatePhase.available || u.phase == UpdatePhase.downloading || u.phase == UpdatePhase.ready;
        if (!show) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: KdButton(
            label: u.phase == UpdatePhase.ready ? l10n.updBadgeReady : l10n.updBadge,
            icon: LucideIcons.download,
            kind: KdButtonKind.ghost,
            onPressed: () => context.app.openSettings('about'),
          ),
        );
      },
    );
  }
}
