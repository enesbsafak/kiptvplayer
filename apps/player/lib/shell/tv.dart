import 'package:flutter/widgets.dart';

/// Everything is drawn this much larger on a TV: the desktop type scale
/// (13 px body) is meant for a screen at arm's length, a TV is across the
/// room. The layout then sees a 800x450 screen on a 960x540 dp (1080p) TV
/// and uses its one-pane, compact screens beside the sidebar.
const tvScale = 1.2;

/// Kept clear on every edge: some TVs crop the picture (overscan), and
/// Android TV's guidelines keep content off the edges anyway. Given to the
/// app as the screen's padding, so the shell's and the player's SafeAreas
/// apply it.
const tvOverscan = EdgeInsets.symmetric(horizontal: 32, vertical: 18);

/// The app as laid out for a TV ([isTv] in app/platform.dart): scaled up by
/// [tvScale], with [tvOverscan] as the safe area.
class TvFrame extends StatelessWidget {
  const TvFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final size = mq.size / tvScale;
    return FittedBox(
      fit: BoxFit.fill,
      alignment: Alignment.topLeft,
      child: SizedBox.fromSize(
        size: size,
        child: MediaQuery(
          data: mq.copyWith(
            size: size,
            devicePixelRatio: mq.devicePixelRatio * tvScale,
            padding: tvOverscan,
            viewPadding: tvOverscan,
            viewInsets: mq.viewInsets / tvScale,
          ),
          child: child,
        ),
      ),
    );
  }
}
