import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../app/platform.dart';
import '../design/tokens.dart';

/// The Android look: KaradelikDev's black and orange with frosted glass for
/// everything that floats (bars, sheets, the mini player). Depth comes from
/// translucency and a lit rim, not from shadows; orange stays for the one
/// action and the current place.
abstract final class KdGlassTokens {
  /// What the glass lets through: a dark tint, lifted by a faint white.
  static const tint = Color(0x8C12121A);
  static const sheen = Color(0x12FFFFFF);

  /// The rim, lit from above: bright on the top edge, faint at the bottom.
  static const rimTop = Color(0x33FFFFFF);
  static const rimBottom = Color(0x0AFFFFFF);

  /// Without the blur (low-RAM phones) the tint is denser so text stays
  /// legible over whatever scrolls behind.
  static const tintSolid = Color(0xF0151520);

  static const blur = 26.0;

  static const radiusBar = 28.0;
  static const radiusCard = 22.0;
  static const radiusSheet = 28.0;
}

/// Material 3's emphasized easing and the durations Android uses for it.
abstract final class KdMotionM3 {
  static const emphasized = Cubic(0.2, 0, 0, 1);
  static const emphasizedDecelerate = Cubic(0.05, 0.7, 0.1, 1);
  static const emphasizedAccelerate = Cubic(0.3, 0, 0.8, 0.15);
  static const short = Duration(milliseconds: 150);
  static const medium = Duration(milliseconds: 300);
  static const long = Duration(milliseconds: 450);
}

/// A frosted surface: what lies behind it blurred and a little more
/// saturated (posters bleed their colour through), a dark tint, a sheen and
/// a rim lit from above.
class KdGlass extends StatelessWidget {
  const KdGlass({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.all(Radius.circular(KdGlassTokens.radiusCard)),
    this.padding = EdgeInsets.zero,
    this.tint,
  });

  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  /// Replaces the default tint (the selected nav item, a warning).
  final Color? tint;

  static final _filter = ui.ImageFilter.compose(
    outer: const ColorFilter.matrix(_saturate),
    inner: ui.ImageFilter.blur(sigmaX: KdGlassTokens.blur, sigmaY: KdGlassTokens.blur, tileMode: TileMode.mirror),
  );

  /// 1.5x saturation (Rec. 709 luma weights).
  static const _saturate = <double>[
    1.393, -0.357, -0.036, 0, 0, //
    -0.107, 1.143, -0.036, 0, 0, //
    -0.107, -0.357, 1.464, 0, 0, //
    0, 0, 0, 1, 0, //
  ];

  @override
  Widget build(BuildContext context) {
    final surface = CustomPaint(
      foregroundPainter: _RimPainter(borderRadius),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tint ?? (glassBlur ? KdGlassTokens.tint : KdGlassTokens.tintSolid),
          borderRadius: borderRadius,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [KdGlassTokens.sheen, Color(0x00FFFFFF)],
          ),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
    return ClipRRect(
      borderRadius: borderRadius,
      child: glassBlur ? BackdropFilter.grouped(filter: _filter, child: surface) : surface,
    );
  }
}

class _RimPainter extends CustomPainter {
  _RimPainter(this.radius);

  final BorderRadius radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [KdGlassTokens.rimTop, KdGlassTokens.rimBottom],
      ).createShader(rect);
    canvas.drawRRect(radius.toRRect(rect.deflate(0.5)), paint);
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.radius != radius;
}

/// A card on the Android layout: a lighter layer of the same glass (no blur
/// of its own: lists hold many), rounded, the current one rimmed in orange.
BoxDecoration androidCard({bool active = false}) => BoxDecoration(
  color: const Color(0x0DFFFFFF),
  border: Border.all(color: active ? KdColors.accentAlpha(0.45) : const Color(0x1AFFFFFF)),
  borderRadius: BorderRadius.circular(KdGlassTokens.radiusCard),
);

/// The space behind the Android layout: the app's black with the icon's
/// violet core and a faint orange glow, as if light bent around the event
/// horizon. Painted once; the glass above has something to frost.
class KdAmbient extends StatelessWidget {
  const KdAmbient({super.key});

  @override
  Widget build(BuildContext context) {
    return const RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(color: KdColors.bg),
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.9, -1.05),
                  radius: 1.1,
                  colors: [Color(0x26FF8A1F), Color(0x00FF8A1F)],
                ),
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.8, 0.2),
                  radius: 1.2,
                  colors: [Color(0x401B1324), Color(0x001B1324)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Android's touch ripple, drawn over the widget it belongs to (an ink
/// splash drawn on the Material below would hide under opaque cards): a
/// circle grows from the finger and fades when it lifts.
class KdRipple extends StatefulWidget {
  const KdRipple({super.key, required this.child, this.borderRadius = BorderRadius.zero, this.color = const Color(0x1FFFFFFF)});

  final Widget child;
  final BorderRadius borderRadius;
  final Color color;

  @override
  State<KdRipple> createState() => _KdRippleState();
}

class _KdRippleState extends State<KdRipple> with TickerProviderStateMixin {
  late final _grow = AnimationController(vsync: this, duration: const Duration(milliseconds: 360));
  late final _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 220), value: 1);
  Offset? _origin;

  @override
  void dispose() {
    _grow.dispose();
    _fade.dispose();
    super.dispose();
  }

  void _down(PointerDownEvent e) {
    if (e.kind != ui.PointerDeviceKind.touch) return;
    _origin = e.localPosition;
    _fade.value = 1;
    _grow.forward(from: 0);
  }

  void _up([PointerEvent? _]) {
    if (_origin == null) return;
    // A quick tap still shows most of the circle before it fades.
    _grow.animateTo(1, duration: const Duration(milliseconds: 160), curve: Curves.easeOut);
    _fade.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      behavior: HitTestBehavior.translucent,
      child: CustomPaint(
        foregroundPainter: _RipplePainter(
          grow: _grow,
          fade: _fade,
          origin: () => _origin,
          radius: widget.borderRadius,
          color: widget.color,
        ),
        child: widget.child,
      ),
    );
  }
}

class _RipplePainter extends CustomPainter {
  _RipplePainter({required this.grow, required this.fade, required this.origin, required this.radius, required this.color})
      : super(repaint: Listenable.merge([grow, fade]));

  final Animation<double> grow;
  final Animation<double> fade;
  final Offset? Function() origin;
  final BorderRadius radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final o = origin();
    if (o == null || fade.value == 0 || grow.value == 0) return;
    final rect = Offset.zero & size;
    final far = [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight].map((c) => (c - o).distance).reduce((a, b) => a > b ? a : b);
    final r = far * KdMotionM3.emphasizedDecelerate.transform(grow.value);
    canvas.save();
    canvas.clipRRect(radius.toRRect(rect));
    canvas.drawCircle(o, r, Paint()..color = color.withValues(alpha: color.a * fade.value));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RipplePainter old) => old.color != color || old.radius != radius;
}
