import 'dart:io' show Platform;

import 'package:flutter/material.dart';

import 'tokens.dart';

/// [android]: the phone layout's behaviour (lib/mobile): Android scrolling
/// (the stretch overscroll), ripples on Material widgets, the predictive
/// back page transition, rounded sheets and dialogs, Android's switch.
ThemeData buildKdTheme({bool android = false}) {
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
    splashFactory: android ? (Platform.isAndroid ? InkSparkle.splashFactory : InkRipple.splashFactory) : NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: KdColors.bg2,
    visualDensity: android ? VisualDensity.standard : VisualDensity.compact,
    platform: android ? TargetPlatform.android : null,
    pageTransitionsTheme: android
        ? const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
              TargetPlatform.windows: PredictiveBackPageTransitionsBuilder(),
            },
          )
        : null,
    bottomSheetTheme: android ? const BottomSheetThemeData(backgroundColor: Colors.transparent, elevation: 0) : null,
    dialogTheme: android
        ? DialogThemeData(
            backgroundColor: KdColors.bg2,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28), side: const BorderSide(color: Color(0x1FFFFFFF))),
          )
        : null,
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? KdColors.accentInk : KdColors.muted),
      trackColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? KdColors.accent : const Color(0x14FFFFFF)),
      trackOutlineColor: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected) ? KdColors.accent : const Color(0x33FFFFFF)),
    ),
    tooltipTheme: android
        ? TooltipThemeData(
            decoration: BoxDecoration(color: KdColors.bg3, borderRadius: BorderRadius.circular(8)),
            textStyle: const TextStyle(color: KdColors.text, fontSize: KdType.small),
          )
        : null,
  );
}
