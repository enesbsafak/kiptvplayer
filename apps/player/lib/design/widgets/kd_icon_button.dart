import 'package:flutter/material.dart';

import '../tokens.dart';
import 'kd_focus.dart';

/// `.icon-btn`: 32x30, 16 px stroke icon, muted until hovered.
class KdIconButton extends StatefulWidget {
  const KdIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.color,
    this.extent,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  /// The icon's color at rest (an active section); muted otherwise.
  final Color? color;

  /// A square hit area instead of 32x30, for touch (44 px).
  final double? extent;

  @override
  State<KdIconButton> createState() => _KdIconButtonState();
}

class _KdIconButtonState extends State<KdIconButton> {
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    Widget button = KdTappable(
      onTap: widget.onPressed,
      builder: (context, hover, focus) => KdFocusRing(
        focused: focus,
        child: Opacity(
          opacity: enabled ? 1 : KdMotion.disabledOpacity,
          child: Container(
            width: widget.extent ?? KdSize.iconButtonW,
            height: widget.extent ?? KdSize.iconButtonH,
            decoration: BoxDecoration(
              color: (hover || focus) && enabled ? KdColors.bg3 : Colors.transparent,
              borderRadius: BorderRadius.circular(KdRadius.control),
            ),
            child: Icon(
              widget.icon,
              size: KdSize.icon,
              color: (hover || focus) && enabled ? KdColors.text : (widget.color ?? KdColors.muted),
            ),
          ),
        ),
      ),
    );
    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        waitDuration: const Duration(milliseconds: 500),
        child: button,
      );
    }
    return button;
  }
}
