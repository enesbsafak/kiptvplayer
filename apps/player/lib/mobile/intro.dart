import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../design/tokens.dart';
import 'glass.dart';

/// The opening on Android. The system launch screen shows the mark on black
/// (res/values-v31/styles.xml, tools/make-icons.py); the app's first frame
/// draws the same mark at the same place and carries on: the disk flares,
/// then the event horizon opens from the middle of the screen, ringed by
/// light, and the app is inside it. Under a second, and the app is usable
/// underneath from the first frame; skipped when animations are off.
class KdIntro extends StatefulWidget {
  const KdIntro({super.key, required this.child});

  final Widget child;

  /// The mark's width on the launch screen (SPLASH_MARK_DP in make-icons.py).
  static const markSize = 160.0;

  static const duration = Duration(milliseconds: 950);

  @override
  State<KdIntro> createState() => _KdIntroState();
}

class _KdIntroState extends State<KdIntro> with SingleTickerProviderStateMixin {
  late final _t = AnimationController(vsync: this, duration: KdIntro.duration);
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _t.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) setState(() => _done = true);
    });
    _t.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context) && !_done) {
      _t.stop();
      _done = true;
    }
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        // Touches go to the app at once; the opening only paints.
        IgnorePointer(
          child: AnimatedBuilder(
            animation: _t,
            builder: (context, _) {
              final t = _t.value;
              // 0 → 0.3: the disk flares. 0.25 → 1: the horizon opens.
              final flare = Curves.easeOut.transform((t / 0.3).clamp(0, 1));
              final open = KdMotionM3.emphasized.transform(((t - 0.25) / 0.75).clamp(0, 1));
              final fall = Curves.easeIn.transform(((t - 0.25) / 0.4).clamp(0, 1));
              return Stack(
                fit: StackFit.expand,
                children: [
                  CustomPaint(painter: _HorizonPainter(open: open, flare: flare)),
                  Center(
                    child: Opacity(
                      opacity: 1 - fall,
                      child: Transform.scale(
                        // A little brighter and bigger, then the viewer falls in.
                        scale: 1 + 0.05 * flare + 1.2 * fall,
                        child: Image.asset('assets/brand/logo.png', width: KdIntro.markSize, height: KdIntro.markSize),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Black everywhere but a growing circle in the middle; light on its rim.
class _HorizonPainter extends CustomPainter {
  _HorizonPainter({required this.open, required this.flare});

  final double open;
  final double flare;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final reach = math.sqrt(size.width * size.width + size.height * size.height) / 2 + 24;
    final r = reach * open;
    final dark = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addOval(Rect.fromCircle(center: c, radius: r));
    canvas.drawPath(dark, Paint()..color = KdColors.bg);

    // The glow of the disk behind the mark while it flares.
    final glow = flare * (1 - open);
    if (glow > 0) {
      canvas.drawCircle(
        c,
        KdIntro.markSize * 0.75,
        Paint()
          ..shader = RadialGradient(colors: [KdColors.accent.withValues(alpha: 0.35 * glow), KdColors.accent.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: KdIntro.markSize * 0.75)),
      );
    }
    // The photon ring: bright while small, fading as it sweeps outward.
    if (open > 0 && open < 1) {
      final fade = 1 - open;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14
          ..color = KdColors.accent.withValues(alpha: 0.45 * fade)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = KdColors.accent2.withValues(alpha: 0.9 * fade),
      );
    }
  }

  @override
  bool shouldRepaint(_HorizonPainter old) => old.open != open || old.flare != flare;
}
