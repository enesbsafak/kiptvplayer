import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/platform.dart';
import '../../mobile/glass.dart';
import '../tokens.dart';

/// Opens an item's context menu from the keyboard (the Menu key, Shift+F10)
/// or a TV remote's menu button.
class KdContextIntent extends Intent {
  const KdContextIntent();
}

/// Anything that is clicked, tapped or, with a keyboard or a TV remote,
/// focused and activated (Enter, Space, the remote's OK). [builder] gets the
/// hover and focus states so each widget draws its own; [KdFocusRing] is the
/// common focus outline.
///
/// The focus state is only true while keyboard-style navigation is in use
/// (FocusableActionDetector's highlight mode), so mouse and touch users never
/// see stray rings.
class KdTappable extends StatefulWidget {
  const KdTappable({
    super.key,
    required this.onTap,
    required this.builder,
    this.onDoubleTap,
    this.onContext,
    this.autofocus = false,
    this.focusNode,
    this.cursor = SystemMouseCursors.click,
    this.radius = 12,
  });

  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;

  /// Right click, long press or the menu key, with a global position for
  /// the menu (the item's centre for keys).
  final ValueChanged<Offset>? onContext;
  final bool autofocus;
  final FocusNode? focusNode;
  final MouseCursor cursor;
  final Widget Function(BuildContext context, bool hover, bool focus) builder;

  /// Android: the corner radius the touch ripple is clipped to.
  final double radius;

  @override
  State<KdTappable> createState() => _KdTappableState();
}

class _KdTappableState extends State<KdTappable> {
  bool _hover = false;
  bool _focus = false;

  static const _contextKeys = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.contextMenu): KdContextIntent(),
    SingleActivator(LogicalKeyboardKey.f10, shift: true): KdContextIntent(),
  };

  void _openContextFromKey() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    widget.onContext?.call(box.localToGlobal(box.size.center(Offset.zero)));
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final onContext = widget.onContext;
    return FocusableActionDetector(
      enabled: enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      mouseCursor: enabled ? widget.cursor : SystemMouseCursors.basic,
      shortcuts: onContext == null ? null : _contextKeys,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onTap?.call()),
        if (onContext != null) KdContextIntent: CallbackAction<KdContextIntent>(onInvoke: (_) => _openContextFromKey()),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onDoubleTap: widget.onDoubleTap,
        onSecondaryTapUp: onContext == null ? null : (d) => onContext(d.globalPosition),
        // Touch has no right button: a long press opens the same menu.
        onLongPressStart: onContext == null
            ? null
            : (d) {
                if (androidUi) Feedback.forLongPress(context);
                onContext(d.globalPosition);
              },
        child: androidUi && enabled
            ? KdRipple(borderRadius: BorderRadius.circular(widget.radius), child: widget.builder(context, _hover, _focus))
            : widget.builder(context, _hover, _focus && enabled),
      ),
    );
  }
}

/// The accent outline drawn over the focused item's edge, so it never shifts
/// the layout. [margin] is the item's own margin: the ring follows the visible
/// box, not the space around it.
class KdFocusRing extends StatelessWidget {
  const KdFocusRing({
    super.key,
    required this.focused,
    required this.child,
    this.radius = KdRadius.control,
    this.margin = EdgeInsets.zero,
  });

  final bool focused;
  final double radius;
  final EdgeInsetsGeometry margin;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ring = DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: focused ? Border.all(color: KdColors.accent, width: 2) : null,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: child,
    );
    return margin == EdgeInsets.zero ? ring : Padding(padding: margin, child: ring);
  }
}
