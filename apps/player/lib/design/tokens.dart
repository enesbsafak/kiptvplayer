import 'dart:io' show Platform;

import 'package:flutter/painting.dart';

/// KaradelikDev design tokens, ported from lokaldev `ui/css/app.css:1-16`.
/// Dark only, like KaradelikDev.
abstract final class KdColors {
  static const bg = Color(0xFF0B0B10);
  static const bg2 = Color(0xFF12121A);
  static const bg3 = Color(0xFF1A1A24);
  static const line = Color(0xFF262633);
  static const text = Color(0xFFE9E7EF);
  static const muted = Color(0xFF8D8A9C);
  static const accent = Color(0xFFFF8A1F);
  static const accent2 = Color(0xFFFFB347);
  static const accentInk = Color(0xFF1A0D00);
  static const ok = Color(0xFF3DDC84);
  static const warn = Color(0xFFFFCC4D);
  static const err = Color(0xFFFF5D5D);

  // Literal values app.css uses outside the token block.
  static const titlebarTop = Color(0xFF14141D);
  static const titlebarBottom = Color(0xFF0F0F16);
  static const buttonHoverBorder = Color(0xFF3A3A4C);
  static const buttonHoverBg = Color(0xFF22222E);
  static const rowDivider = Color(0xFF1C1C26);
  static const idleDot = Color(0xFF3A3A48);
  static const windowsCloseHover = Color(0xFFC42B1C);
  static const primaryGradientEnd = Color(0xFFFF5F1F);

  /// Accent tints: notice background, active item, notice border, tag border.
  static Color accentAlpha(double opacity) => accent.withValues(alpha: opacity);
}

abstract final class KdRadius {
  static const card = 8.0;
  static const control = 6.0;
  static const pill = 999.0;
  static const bar = 2.0;
}

abstract final class KdSize {
  static const titlebar = 44.0;
  static const windowButton = 44.0;
  static const iconButtonW = 32.0;
  static const iconButtonH = 30.0;
  static const icon = 16.0;
}

abstract final class KdType {
  /// System UI font, like KaradelikDev: Segoe UI Variable on Windows,
  /// SF Pro on macOS.
  static String get family =>
      Platform.isMacOS ? '.AppleSystemUIFont' : 'Segoe UI Variable Text';
  static const fallback = ['Segoe UI', 'system-ui'];
  static const mono = 'Cascadia Mono';
  static const monoFallback = ['Consolas', 'SF Mono', 'Menlo'];

  static const tag = 10.5;
  static const chip = 11.0;
  static const hint = 11.5;
  static const small = 12.0;
  static const body = 13.0;
  static const title = 14.0;
  static const heading = 15.0;
  static const display = 17.0;

  static const lineHeight = 1.4;
  static const upperTracking = 0.8;
}

abstract final class KdMotion {
  static const progress = Duration(milliseconds: 200);
  static const indeterminate = Duration(milliseconds: 1100);
  static const disabledOpacity = 0.45;
}
