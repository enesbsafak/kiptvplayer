import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../app/app_state.dart';
import '../app/library.dart';
import '../app/scope.dart';
import '../design/tokens.dart';
import '../design/widgets/kd_icon_button.dart';
import '../design/widgets/kd_titlebar.dart';
import '../l10n/l10n.dart';
import '../player/player_controller.dart';
import '../screens/add_source.dart';
import '../screens/favorites_screen.dart';
import '../screens/guide_screen.dart';
import '../screens/home_screen.dart';
import '../screens/live_screen.dart';
import '../screens/player_screen.dart';
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
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
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
    const SingleActivator(LogicalKeyboardKey.keyK, control: true): () => app.go(Section.search),
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
        final hideChrome = full && _osFullscreen;
        return CallbackShortcuts(
          bindings: _shortcuts(app),
          child: Focus(
            autofocus: true,
            child: DecoratedBox(
              decoration: BoxDecoration(border: hideChrome ? null : Border.all(color: KdColors.line)),
              child: Column(
                children: [
                  if (!hideChrome)
                    KdTitlebar(
                      actions: [
                        if (app.sources.isNotEmpty)
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
                              if (full) const Positioned.fill(child: PlayerScreen()),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
  const _MiniPlayer();

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
        width: 336,
        height: 189,
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
