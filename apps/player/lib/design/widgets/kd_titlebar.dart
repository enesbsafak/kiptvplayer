import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';

import '../tokens.dart';

/// KaradelikDev's 44 px titlebar (lokaldev `index.html:11-35`): glowing logo,
/// title, free drag space, trailing actions, then the window buttons.
class KdTitlebar extends StatefulWidget {
  const KdTitlebar({super.key, this.title, this.actions = const []});

  final Widget? title;
  final List<Widget> actions;

  @override
  State<KdTitlebar> createState() => _KdTitlebarState();
}

/// Native caption channel (windows/runner/window_chrome.cpp): Dart reports
/// where the maximize button is, the runner answers HTMAXBUTTON there so
/// Windows 11 shows Snap Layouts, and sends hover / press back.
const _chrome = MethodChannel('karadelik/window');

/// Flashes the taskbar button while another window has the focus.
Future<void> flashTaskbar() => _chrome.invokeMethod<void>('flash').catchError((_) {});

class _KdTitlebarState extends State<KdTitlebar> with WindowListener {
  bool _maximized = false;
  final _maxKey = GlobalKey();
  final _maxHover = ValueNotifier(false);
  final _maxPressed = ValueNotifier(false);
  Rect? _sentRect;

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows) {
      _chrome.setMethodCallHandler((call) async {
        switch (call.method) {
          case 'maxHover':
            _maxHover.value = call.arguments == true;
          case 'maxPressed':
            _maxPressed.value = call.arguments == true;
        }
      });
    }
    windowManager.addListener(this);
    windowManager
        .isMaximized()
        .then((v) => mounted ? setState(() => _maximized = v) : null)
        .catchError((Object _) {}); // no window plugin in widget tests
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    if (Platform.isWindows) {
      _chrome.setMethodCallHandler(null);
      // The titlebar is gone (e.g. fullscreen player): nothing to snap.
      _chrome
          .invokeMethod('setMaxButtonRect', {'left': 0.0, 'top': 0.0, 'right': 0.0, 'bottom': 0.0})
          .catchError((Object _) {});
    }
    _maxHover.dispose();
    _maxPressed.dispose();
    super.dispose();
  }

  /// Sends the maximize button's window-relative rectangle after layout.
  void _reportMaxButton() {
    final box = _maxKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect == _sentRect) return;
    _sentRect = rect;
    _chrome.invokeMethod('setMaxButtonRect', {
      'left': rect.left,
      'top': rect.top,
      'right': rect.right,
      'bottom': rect.bottom,
    }).catchError((Object _) {}); // runner without the channel (tests)
  }

  @override
  void onWindowMaximize() => setState(() => _maximized = true);

  @override
  void onWindowUnmaximize() => setState(() => _maximized = false);

  @override
  Widget build(BuildContext context) {
    // macOS keeps its traffic lights; leave room for them on the left.
    final macos = Platform.isMacOS;
    if (Platform.isWindows) WidgetsBinding.instance.addPostFrameCallback((_) => _reportMaxButton());
    return Container(
      height: KdSize.titlebar,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [KdColors.titlebarTop, KdColors.titlebarBottom],
        ),
        border: Border(bottom: BorderSide(color: KdColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(width: macos ? 88 : 12),
          Expanded(
            child: DragToMoveArea(
              child: Row(
                children: [
                  const _GlowLogo(size: 26),
                  const SizedBox(width: 10),
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                    ),
                    child: widget.title ?? const Text('Karadelik IPTV Player'),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
          ...widget.actions,
          if (!macos) ...[
            const SizedBox(width: 4),
            _WindowButton(
              icon: LucideIcons.minus,
              onPressed: windowManager.minimize,
            ),
            // Mouse input over this button goes to the native window (for
            // Snap Layouts), so its hover and press come from the runner.
            ListenableBuilder(
              listenable: Listenable.merge([_maxHover, _maxPressed]),
              builder: (context, _) => _WindowButton(
                key: _maxKey,
                icon: _maximized ? LucideIcons.copy : LucideIcons.square,
                forcedHover: _maxHover.value,
                pressed: _maxPressed.value,
                onPressed: () => _maximized ? windowManager.unmaximize() : windowManager.maximize(),
              ),
            ),
            _WindowButton(
              icon: LucideIcons.x,
              onPressed: windowManager.close,
              danger: true,
            ),
          ],
        ],
      ),
    );
  }
}

class _GlowLogo extends StatelessWidget {
  const _GlowLogo({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    // app.css:43 — drop-shadow(0 0 6px rgba(255,138,31,.45)).
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: KdColors.accentAlpha(0.45), blurRadius: 6),
        ],
      ),
      child: Image.asset(
        'assets/brand/logo.png',
        width: size,
        height: size,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

class _WindowButton extends StatefulWidget {
  const _WindowButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.danger = false,
    this.forcedHover = false,
    this.pressed = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;
  final bool forcedHover;
  final bool pressed;

  @override
  State<_WindowButton> createState() => _WindowButtonState();
}

class _WindowButtonState extends State<_WindowButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hoverBg = widget.danger ? KdColors.windowsCloseHover : KdColors.bg3;
    final hover = _hover || widget.forcedHover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: KdSize.windowButton,
          height: KdSize.titlebar,
          color: widget.pressed ? KdColors.buttonHoverBg : (hover ? hoverBg : Colors.transparent),
          child: Icon(
            widget.icon,
            size: 15,
            color: hover ? KdColors.text : KdColors.muted,
          ),
        ),
      ),
    );
  }
}
