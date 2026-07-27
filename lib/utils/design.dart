// FontFeature comes from dart:ui, re-exported by material.
import 'package:flutter/material.dart';

/// Design tokens. Screens should use these instead of raw literals.
///
/// Font size migration mapping (old hardcoded value -> token):
/// 9,10 -> micro · 11,12 -> caption · 13 -> label · 14,15 -> body ·
/// 16,17,18 -> headline · 20,22,24,26,28 -> title · 32,36 -> display

class AppSpacing {
  static const double xs = 4, sm = 8, md = 12, lg = 16, xl = 24, xxl = 32;
}

class AppRadius {
  static const double sm = 8; // chips, progress bars
  static const double md = 14; // cards, tiles, inputs, buttons
  static const double lg = 24; // hero, sheets, nav

  static BorderRadius get smAll => BorderRadius.circular(sm);
  static BorderRadius get mdAll => BorderRadius.circular(md);
  static BorderRadius get lgAll => BorderRadius.circular(lg);
}

class AppDuration {
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration base = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
}

class AppElevation {
  static List<BoxShadow> low(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.40 : 0.05),
      blurRadius: 8,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> high(bool isDark) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.10),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];
}

class AppType {
  /// Hook for a bundled face later; null = platform default.
  static const String? fontFamily = null;

  static const double display = 32,
      title = 22,
      headline = 17,
      body = 15,
      label = 13,
      caption = 11,
      micro = 10;

  /// Fixed-width digits so money columns stay aligned as values change.
  static const List<FontFeature> tabular = [FontFeature.tabularFigures()];

  static TextTheme textTheme({
    required Color onSurface,
    required Color muted,
  }) {
    TextStyle s(
      double size,
      FontWeight weight,
      double height,
      double spacing,
      Color color,
    ) => TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      height: height,
      letterSpacing: spacing,
      color: color,
    );

    final displayStyle = s(display, FontWeight.w700, 1.10, -0.5, onSurface);
    final titleStyle = s(title, FontWeight.w700, 1.20, -0.2, onSurface);
    // 1.30 leading: dense ledger UI, and it keeps compact phones off overflow.
    final bodyStyle = s(body, FontWeight.w400, 1.30, 0, onSurface);

    return TextTheme(
      displayLarge: displayStyle,
      displayMedium: displayStyle,
      displaySmall: displayStyle,
      headlineLarge: titleStyle,
      headlineMedium: titleStyle,
      headlineSmall: titleStyle,
      titleLarge: titleStyle,
      titleMedium: s(headline, FontWeight.w600, 1.25, -0.1, onSurface),
      titleSmall: s(body, FontWeight.w600, 1.30, 0, onSurface),
      bodyLarge: bodyStyle,
      bodyMedium: bodyStyle,
      bodySmall: s(label, FontWeight.w400, 1.30, 0, muted),
      labelLarge: s(label, FontWeight.w600, 1.30, 0.1, onSurface),
      labelMedium: s(caption, FontWeight.w500, 1.30, 0.2, muted),
      labelSmall: s(micro, FontWeight.w600, 1.20, 0.3, muted),
    );
  }
}
