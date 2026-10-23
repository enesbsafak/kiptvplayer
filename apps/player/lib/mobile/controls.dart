import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../design/tokens.dart';
import '../design/widgets/kd_controls.dart' show KdButtonKind;
import '../design/widgets/kd_focus.dart';
import 'glass.dart';

/// The Android forms of the shared controls (design/widgets): finger-sized
/// (48 dp targets), pill-shaped, with ripples and Android's own switch. The
/// Kd widgets hand over to these when [androidUi] is set, so every screen
/// gets them without knowing.

/// A pill button: the CTA keeps KaradelikDev's orange gradient, the others
/// are tonal glass or text.
class AndroidButton extends StatelessWidget {
  const AndroidButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.kind,
    this.icon,
    this.large = false,
    this.autofocus = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final KdButtonKind kind;
  final IconData? icon;
  final bool large;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final strong = kind == KdButtonKind.primary || kind == KdButtonKind.cta;
    final (Color? bg, Gradient? gradient, Color fg, Color? rim) = switch (kind) {
      KdButtonKind.cta => (
        null,
        const LinearGradient(colors: [KdColors.accent, KdColors.primaryGradientEnd], begin: Alignment.topLeft, end: Alignment.bottomRight),
        KdColors.accentInk,
        null,
      ),
      KdButtonKind.primary => (KdColors.accent, null, KdColors.accentInk, null),
      KdButtonKind.neutral => (const Color(0x14FFFFFF), null, KdColors.text, const Color(0x1FFFFFFF)),
      KdButtonKind.danger => (KdColors.err.withValues(alpha: 0.14), null, const Color(0xFFFFB3B3), KdColors.err.withValues(alpha: 0.35)),
      KdButtonKind.ghost => (null, null, KdColors.accent2, null),
    };
    final radius = BorderRadius.circular(KdRadius.pill);
    return Semantics(
      button: true,
      enabled: enabled,
      child: Opacity(
        opacity: enabled ? 1 : KdMotion.disabledOpacity,
        child: KdTappable(
          onTap: onPressed,
          autofocus: autofocus,
          radius: KdRadius.pill,
          builder: (context, hover, focus) => Container(
            constraints: BoxConstraints(minHeight: large ? 52 : 44, minWidth: 64),
            padding: EdgeInsets.symmetric(horizontal: kind == KdButtonKind.ghost ? 14 : (large ? 24 : 18)),
            decoration: BoxDecoration(
              color: bg,
              gradient: gradient,
              borderRadius: radius,
              border: focus
                  ? Border.all(color: KdColors.accent, width: 2)
                  : rim == null
                      ? null
                      : Border.all(color: rim),
              boxShadow: kind == KdButtonKind.cta && enabled
                  // The orange glows a little, like the disk in the icon.
                  ? [BoxShadow(color: KdColors.accent.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 6))]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[Icon(icon, size: 18, color: fg), const SizedBox(width: 8)],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: fg, fontSize: KdType.body, fontWeight: strong ? FontWeight.w700 : FontWeight.w600, letterSpacing: 0.1),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A round 48 dp icon button.
class AndroidIconButton extends StatelessWidget {
  const AndroidIconButton({super.key, required this.icon, required this.onPressed, this.tooltip, this.color, this.extent = 48});

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double extent;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    Widget b = Semantics(
      button: true,
      label: tooltip,
      child: KdTappable(
        onTap: onPressed,
        radius: extent / 2,
        builder: (context, hover, focus) => Opacity(
          opacity: enabled ? 1 : KdMotion.disabledOpacity,
          child: Container(
            width: extent,
            height: extent,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: focus ? Border.all(color: KdColors.accent, width: 2) : null,
            ),
            child: Icon(icon, size: 22, color: color ?? KdColors.text),
          ),
        ),
      ),
    );
    // A long press names the button, as on any Android toolbar.
    if (tooltip != null) b = Tooltip(message: tooltip!, triggerMode: TooltipTriggerMode.longPress, child: b);
    return b;
  }
}

/// A filter chip: a check appears on the selected one.
class AndroidChip extends StatelessWidget {
  const AndroidChip({super.key, required this.label, required this.selected, required this.onTap, this.trailing});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: KdTappable(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        radius: KdRadius.pill,
        builder: (context, hover, focus) => AnimatedContainer(
          duration: KdMotionM3.short,
          curve: KdMotionM3.emphasized,
          height: 36,
          padding: EdgeInsets.only(left: selected ? 10 : 14, right: 14),
          decoration: BoxDecoration(
            color: selected ? KdColors.accentAlpha(0.18) : const Color(0x0FFFFFFF),
            border: Border.all(
              color: focus ? KdColors.accent : (selected ? KdColors.accentAlpha(0.5) : const Color(0x1FFFFFFF)),
              width: focus ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(KdRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[const Icon(LucideIcons.check, size: 15, color: KdColors.accent2), const SizedBox(width: 6)],
              Text(
                label,
                style: TextStyle(
                  fontSize: KdType.small,
                  color: selected ? KdColors.accent2 : KdColors.text,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                Text(trailing!, style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A settings row with Android's switch on the right.
class AndroidSwitchRow extends StatelessWidget {
  const AndroidSwitchRow({super.key, required this.value, required this.onChanged, required this.label, this.hint});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: KdTappable(
        onTap: () => onChanged(!value),
        builder: (context, hover, focus) => Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            border: focus ? Border.all(color: KdColors.accent, width: 2) : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(label),
                    if (hint != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(hint!, style: const TextStyle(fontSize: KdType.hint, color: KdColors.muted)),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Switch(value: value, onChanged: onChanged),
            ],
          ),
        ),
      ),
    );
  }
}

/// A filled text field, 52 dp tall, rounded, the accent outline only while
/// typing.
InputDecoration androidInputDecoration({String? hint, IconData? prefix, required bool mono}) {
  OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c, width: w),
  );
  return InputDecoration(
    isDense: false,
    hintText: hint,
    hintStyle: const TextStyle(color: KdColors.muted, fontSize: KdType.body),
    hintMaxLines: 1,
    filled: true,
    fillColor: const Color(0x0FFFFFFF),
    prefixIcon: prefix == null ? null : Icon(prefix, size: 20, color: KdColors.muted),
    prefixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 48),
    contentPadding: EdgeInsets.symmetric(horizontal: prefix == null ? 16 : 4, vertical: 15),
    border: border(const Color(0x1AFFFFFF)),
    enabledBorder: border(const Color(0x1AFFFFFF)),
    focusedBorder: border(KdColors.accent, 1.5),
  );
}
