import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/platform.dart';
import '../../l10n/l10n.dart';
import '../../mobile/controls.dart';
import '../tokens.dart';
import 'kd_focus.dart';
import 'kd_widgets.dart' show kdUpper;

enum KdButtonKind { neutral, primary, cta, danger, ghost }

/// `.btn` and its variants (app.css:100-110). [KdButtonKind.cta] is the
/// orange gradient KaradelikDev reserves for one primary action per screen.
class KdButton extends StatefulWidget {
  const KdButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.kind = KdButtonKind.neutral,
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
  State<KdButton> createState() => _KdButtonState();
}

class _KdButtonState extends State<KdButton> {
  bool _hover = false;
  bool _down = false;
  bool _focus = false;

  @override
  Widget build(BuildContext context) {
    if (androidUi) {
      return AndroidButton(
        label: widget.label,
        onPressed: widget.onPressed,
        kind: widget.kind,
        icon: widget.icon,
        large: widget.large,
        autofocus: widget.autofocus,
      );
    }
    final enabled = widget.onPressed != null;
    final kind = widget.kind;

    Color? bg;
    Gradient? gradient;
    Color border;
    Color fg;
    switch (kind) {
      case KdButtonKind.neutral:
        bg = _hover ? KdColors.buttonHoverBg : KdColors.bg3;
        border = _hover ? KdColors.buttonHoverBorder : KdColors.line;
        fg = KdColors.text;
      case KdButtonKind.primary:
        bg = _hover ? KdColors.accent2 : KdColors.accent;
        border = Colors.transparent;
        fg = KdColors.accentInk;
      case KdButtonKind.cta:
        gradient = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _hover ? const [KdColors.accent2, KdColors.accent] : const [KdColors.accent, KdColors.primaryGradientEnd],
        );
        border = Colors.transparent;
        fg = KdColors.accentInk;
      case KdButtonKind.danger:
        bg = _hover ? KdColors.err.withValues(alpha: 0.12) : KdColors.bg3;
        border = KdColors.err.withValues(alpha: 0.5);
        fg = const Color(0xFFFFB3B3);
      case KdButtonKind.ghost:
        bg = _hover ? KdColors.bg2 : Colors.transparent;
        border = Colors.transparent;
        fg = _hover ? KdColors.text : KdColors.muted;
    }
    if (_focus) border = KdColors.accent;

    final strong = kind == KdButtonKind.primary || kind == KdButtonKind.cta;
    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.icon != null) ...[Icon(widget.icon, size: widget.large ? 16 : 14, color: fg), const SizedBox(width: 6)],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: widget.large ? KdType.body : KdType.small,
              fontWeight: strong ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );

    return FocusableActionDetector(
      enabled: enabled,
      autofocus: widget.autofocus,
      mouseCursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onShowHoverHighlight: (v) => setState(() => _hover = v),
      onShowFocusHighlight: (v) => setState(() => _focus = v),
      actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => widget.onPressed?.call())},
      child: GestureDetector(
        onTap: widget.onPressed,
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        child: Opacity(
          opacity: enabled ? 1 : KdMotion.disabledOpacity,
          child: Transform.translate(
            // `.btn:active { transform: translateY(1px) }`
            offset: Offset(0, _down ? 1 : 0),
            child: Container(
              padding: widget.large
                  ? const EdgeInsets.symmetric(horizontal: 18, vertical: 9)
                  : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: bg,
                gradient: gradient,
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(KdRadius.control),
              ),
              child: content,
            ),
          ),
        ),
      ),
    );
  }
}

/// Text field in KaradelikDev style: `--bg-2` fill, 1 px line, accent focus.
///
/// On a TV the remote moves onto the field without typing in it (a focused
/// text field would bring up the on-screen keyboard at every pass); OK starts
/// typing, the keyboard's done or the up and down arrows end it.
class KdInput extends StatefulWidget {
  const KdInput({
    super.key,
    this.controller,
    this.hint,
    this.obscure = false,
    this.autofocus = false,
    this.onSubmitted,
    this.onChanged,
    this.prefix,
    this.focusNode,
    this.mono = false,
  });

  final TextEditingController? controller;
  final String? hint;
  final bool obscure;
  final bool autofocus;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final IconData? prefix;
  final FocusNode? focusNode;
  final bool mono;

  @override
  State<KdInput> createState() => _KdInputState();
}

class _KdInputState extends State<KdInput> {
  /// TV only: the frame the remote lands on, and the field's own node when
  /// the caller gave none.
  FocusNode? _frame;
  FocusNode? _own;

  FocusNode get _field => widget.focusNode ?? (_own ??= FocusNode(debugLabel: 'input'));

  @override
  void initState() {
    super.initState();
    if (isTv) {
      _frame = FocusNode(debugLabel: 'input-frame')..addListener(_changed);
      // Explicit focus requests (a dialog's first field) still type at once.
      _field.skipTraversal = true;
    }
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _frame?.dispose();
    _own?.dispose();
    super.dispose();
  }

  static const _leave = <ShortcutActivator, Intent>{
    SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up, ignoreTextFields: false),
    SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down, ignoreTextFields: false),
  };

  @override
  Widget build(BuildContext context) {
    final field = _textField();
    final frame = _frame;
    if (frame == null) return field;
    return Focus(
      focusNode: frame,
      onKeyEvent: (node, e) {
        final k = e.logicalKey;
        if (e is KeyDownEvent &&
            node.hasPrimaryFocus &&
            (k == LogicalKeyboardKey.select || k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter)) {
          _field.requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      },
      child: Shortcuts(
        shortcuts: _leave,
        child: KdFocusRing(focused: frame.hasPrimaryFocus, child: field),
      ),
    );
  }

  Widget _textField() {
    OutlineInputBorder border(Color c) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(KdRadius.control),
      borderSide: BorderSide(color: c),
    );
    final mono = widget.mono;
    final prefix = widget.prefix;
    return TextField(
      controller: widget.controller,
      focusNode: _frame == null ? widget.focusNode : _field,
      obscureText: widget.obscure,
      autofocus: widget.autofocus,
      onSubmitted: widget.onSubmitted,
      // TV: done on the on-screen keyboard hands the remote back to the frame.
      onEditingComplete: _frame == null ? null : () => _frame!.requestFocus(),
      onChanged: widget.onChanged,
      cursorColor: KdColors.accent,
      cursorWidth: androidUi ? 2 : 1.5,
      style: TextStyle(
        fontSize: KdType.body,
        color: KdColors.text,
        fontFamily: mono ? KdType.mono : null,
        fontFamilyFallback: mono ? KdType.monoFallback : null,
      ),
      decoration: androidUi
          ? androidInputDecoration(hint: widget.hint, prefix: prefix, mono: mono)
          : InputDecoration(
              isDense: true,
              hintText: widget.hint,
              hintStyle: const TextStyle(color: KdColors.muted, fontSize: KdType.body),
              filled: true,
              fillColor: KdColors.bg2,
              prefixIcon: prefix == null ? null : Icon(prefix, size: 15, color: KdColors.muted),
              prefixIconConstraints: const BoxConstraints(minWidth: 32, minHeight: 30),
              contentPadding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
              border: border(KdColors.line),
              enabledBorder: border(KdColors.line),
              focusedBorder: border(KdColors.accent),
            ),
    );
  }
}

/// `.chip` / project pill: 999 radius, selectable.
class KdPill extends StatefulWidget {
  const KdPill({super.key, required this.label, required this.selected, required this.onTap, this.trailing});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;

  @override
  State<KdPill> createState() => _KdPillState();
}

class _KdPillState extends State<KdPill> {
  @override
  Widget build(BuildContext context) {
    final sel = widget.selected;
    if (androidUi) return AndroidChip(label: widget.label, selected: sel, onTap: widget.onTap, trailing: widget.trailing);
    return KdTappable(
      onTap: widget.onTap,
      builder: (context, hover, focus) => KdFocusRing(
        focused: focus,
        radius: KdRadius.pill,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
          decoration: BoxDecoration(
            color: sel
                ? KdColors.accentAlpha(0.12)
                : hover
                ? KdColors.bg3
                : KdColors.bg2,
            border: Border.all(color: sel ? KdColors.accentAlpha(0.45) : KdColors.line),
            borderRadius: BorderRadius.circular(KdRadius.pill),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: KdType.small,
                  color: sel ? KdColors.accent2 : KdColors.text,
                  fontWeight: sel ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
              if (widget.trailing != null) ...[
                const SizedBox(width: 6),
                Text(
                  widget.trailing!,
                  style: const TextStyle(fontSize: KdType.chip, color: KdColors.muted, fontFeatures: [FontFeature.tabularFigures()]),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Native-feeling checkbox with label, like `accent-color` checkboxes.
class KdCheck extends StatelessWidget {
  const KdCheck({super.key, required this.value, required this.onChanged, required this.label, this.hint});

  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    if (androidUi) return AndroidSwitchRow(value: value, onChanged: onChanged, label: label, hint: hint);
    return KdTappable(
      onTap: () => onChanged(!value),
      builder: (context, hover, focus) => KdFocusRing(
        focused: focus,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 15,
                  height: 15,
                  decoration: BoxDecoration(
                    color: value ? KdColors.accent : KdColors.bg2,
                    border: Border.all(color: value ? KdColors.accent : KdColors.buttonHoverBorder),
                    borderRadius: BorderRadius.circular(3),
                  ),
                  child: value ? const Icon(LucideIcons.check, size: 12, color: KdColors.accentInk) : null,
                ),
                const SizedBox(width: 8),
                Flexible(child: Text(label)),
              ],
            ),
            if (hint != null)
              Padding(
                padding: const EdgeInsets.only(left: 23, top: 2),
                child: Text(
                  hint!,
                  style: const TextStyle(fontSize: KdType.hint, color: KdColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 2 px progress bar (live programme, resume position).
class KdProgress extends StatelessWidget {
  const KdProgress({super.key, required this.value, this.height = 2, this.color = KdColors.accent});

  final double value;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(KdRadius.bar),
      child: SizedBox(
        height: height,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: KdColors.line),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0, 1),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// KaradelikDev's indeterminate bar: a 30 % segment sweeping across
/// (`@keyframes indet`, 1.1 s ease-in-out).
class KdIndeterminate extends StatefulWidget {
  const KdIndeterminate({super.key, this.height = 2});

  final double height;

  @override
  State<KdIndeterminate> createState() => _KdIndeterminateState();
}

class _KdIndeterminateState extends State<KdIndeterminate> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: KdMotion.indeterminate)..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(KdRadius.bar),
      child: SizedBox(
        height: widget.height,
        child: LayoutBuilder(
          builder: (context, c) => AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeInOut.transform(_c.value);
              final w = c.maxWidth * 0.3;
              return Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: KdColors.line)),
                  Positioned(
                    left: -w + (c.maxWidth + w) * t,
                    width: w,
                    top: 0,
                    bottom: 0,
                    child: const ColoredBox(color: KdColors.accent),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Channel logo / poster with an initials fallback on `--bg-3`. Decodes at
/// the displayed size, so 50k logos never sit in memory at full resolution.
class KdArt extends StatelessWidget {
  const KdArt({
    super.key,
    required this.url,
    required this.label,
    required this.width,
    required this.height,
    this.radius = KdRadius.control,
    this.contain = false,
  });

  final String? url;
  final String label;
  final double width;
  final double height;
  final double radius;

  /// Logos are contained on a tile; posters cover.
  final bool contain;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final fallback = _Initials(label: label, size: width < height ? width : height);
    final u = url;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Container(
        width: width,
        height: height,
        color: KdColors.bg3,
        padding: contain ? EdgeInsets.all(width * 0.1) : null,
        child: u == null || u.isEmpty
            ? fallback
            : Image.network(
                u,
                fit: contain ? BoxFit.contain : BoxFit.cover,
                cacheWidth: (width * dpr).round(),
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                errorBuilder: (context, error, stack) => fallback,
                frameBuilder: (context, child, frame, sync) => frame == null && !sync ? fallback : child,
              ),
      ),
    );
  }
}

class _Initials extends StatelessWidget {
  const _Initials({required this.label, required this.size});

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) {
    final words = label.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    final text = words.take(2).map((w) => kdUpper(w.characters.first)).join();
    return Center(
      child: Text(
        text,
        style: TextStyle(color: KdColors.muted, fontWeight: FontWeight.w600, fontSize: (size * 0.32).clamp(9, 28)),
      ),
    );
  }
}

/// Centered logo + title + hint, like KaradelikDev's empty state.
class KdEmpty extends StatelessWidget {
  const KdEmpty({super.key, required this.title, this.hint, this.action, this.icon});

  final String title;
  final String? hint;
  final Widget? action;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) Icon(icon, size: 40, color: KdColors.muted) else Image.asset('assets/brand/logo.png', width: 56, height: 56),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontSize: KdType.heading, fontWeight: FontWeight.w600),
            ),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: KdColors.muted),
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}

/// Shortcut hint chip like `Ctrl K`.
class KdKbd extends StatelessWidget {
  const KdKbd(this.keys, {super.key});

  final String keys;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: KdColors.bg3,
        border: Border.all(color: KdColors.line),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        keys,
        style: const TextStyle(
          fontSize: KdType.tag,
          color: KdColors.muted,
          fontFamily: KdType.mono,
          fontFamilyFallback: KdType.monoFallback,
        ),
      ),
    );
  }
}

/// Formats seconds as "1 sa 05 dk" / "42 dk" ("1 h 05 min" / "42 min").
String kdDuration(int secs) {
  final h = secs ~/ 3600;
  final m = (secs % 3600) ~/ 60;
  if (h > 0) return l10n.durationHours(h, m.toString().padLeft(2, '0'));
  return l10n.durationMinutes(m);
}

/// "Bugün", "Dün" or "Sal 14 Eki" for a Unix timestamp, in local time.
String kdDay(int unixSecs) {
  final t = DateTime.fromMillisecondsSinceEpoch(unixSecs * 1000);
  final today = DateTime.now();
  final diff = DateTime(today.year, today.month, today.day).difference(DateTime(t.year, t.month, t.day)).inDays;
  if (diff == 0) return l10n.dayToday;
  if (diff == 1) return l10n.dayYesterday;
  return DateFormat('E d MMM', languageCode).format(t);
}

/// "az önce", "5 dk önce", "3 sa önce", "2 gün önce" for a Unix timestamp.
String kdAgo(int unixSecs) {
  final d = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(unixSecs * 1000));
  if (d.inMinutes < 1) return l10n.agoNow;
  if (d.inHours < 1) return l10n.agoMinutes(d.inMinutes);
  if (d.inDays < 1) return l10n.agoHours(d.inHours);
  return l10n.agoDays(d.inDays);
}

/// Formats a Unix timestamp as local HH:MM.
String kdClock(int unixSecs) {
  final t = DateTime.fromMillisecondsSinceEpoch(unixSecs * 1000);
  return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
