import 'package:flutter/material.dart';

import 'tokens.dart';

ThemeData buildKdTheme() {
  final base = TextStyle(
    fontFamily: KdType.family,
    fontFamilyFallback: KdType.fallback,
    fontSize: KdType.body,
    height: KdType.lineHeight,
    color: KdColors.text,
  );

  return ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: KdType.family,
    fontFamilyFallback: KdType.fallback,
    scaffoldBackgroundColor: KdColors.bg,
    canvasColor: KdColors.bg,
    dividerColor: KdColors.line,
    colorScheme: const ColorScheme.dark(
      surface: KdColors.bg,
      surfaceContainer: KdColors.bg2,
      surfaceContainerHigh: KdColors.bg3,
      primary: KdColors.accent,
      onPrimary: KdColors.accentInk,
      secondary: KdColors.accent2,
      error: KdColors.err,
      onSurface: KdColors.text,
      outline: KdColors.line,
    ),
    textTheme: TextTheme(
      bodyMedium: base,
      bodySmall: base.copyWith(fontSize: KdType.small, color: KdColors.muted),
      titleSmall: base.copyWith(
        fontSize: KdType.title,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: base.copyWith(
        fontSize: KdType.heading,
        fontWeight: FontWeight.w600,
      ),
      labelSmall: base.copyWith(
        fontSize: KdType.chip,
        color: KdColors.muted,
        letterSpacing: KdType.upperTracking,
      ),
    ),
    scrollbarTheme: ScrollbarThemeData(
      thumbColor: WidgetStateProperty.all(KdColors.line),
      radius: const Radius.circular(4),
      thickness: WidgetStateProperty.all(8),
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: KdColors.bg2,
    visualDensity: VisualDensity.compact,
  );
}
