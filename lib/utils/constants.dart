import 'package:flutter/material.dart';

/// Category hues shared by the built-in category model and group avatars.
/// Screen theming lives in [Scheme] / [SchemeTheme] (see theme.dart).
class AppColors {
  // Category Colors — vibrant enough for both modes
  static const Color food = Color(0xFFE07B6A); // Soft terracotta
  static const Color transport = Color(0xFF29B6F6); // Sky blue (brighter)
  static const Color shopping = Color(0xFF26C6DA); // Bright cyan
  static const Color health = Color(0xFF4CAF7D); // Mint green
  static const Color entertainment = Color(0xFFF4A639); // Amber
  static const Color bills = Color(0xFFAB7FE8); // Soft purple (brighter)
  static const Color other = Color(0xFF90A4AE); // Light slate (brighter)

  static const List<Color> categoryColors = [
    food,
    transport,
    shopping,
    health,
    entertainment,
    bills,
    other,
  ];
}

/// New redesign palette (plan §0.2). ADDITIVE — existing [AppColors] stays.
///
/// Contrast (WCAG) notes, computed 2026-10-04:
/// - dark muted #9AA6C2 vs deep navy-black remains comfortably above 4.5:1
/// - dark ink #E9EDF5 remains high-contrast on the deep navy-black base
/// - light primary #3F72AF vs light bg 4.64:1, vs white 4.96:1
/// - dark primary/focus #9AB8EE remains high-contrast on the dark base
/// - dark CTA text #00021A on ink fill; white on light CTA (#3F72AF) 4.96:1
/// - Semantic trio: dark success #4ADE80 11.11 / warning #FBBF24 11.59 /
///   error #F87171 7.00 vs #010736; light success #1B7A4A 5.01 /
///   warning #8A5A00 5.55 / error #B42318 6.16 vs #F9F7F7 (all ≥4.5 vs
///   their own theme bg AND vs their theme surface).
///   NOTE: no single hex can pass 4.5:1 on BOTH backgrounds, so trio values
///   are per-theme — dark values on dark bg, light values on light bg.
/// - Category hues are likewise per-theme; each ≥4.5:1 on its own theme bg.
///   Dark set vs #010736; light set vs #F9F7F7 / #FFFFFF noted in comments.
class Scheme {
  // ---- Dark theme ----
  // Deep navy-black keeps the app darker without losing the blue brand tone.
  static const Color darkBg = Color(0xFF00021A);
  static const Color darkSurface = Color(0xFF080F2E);
  static const Color darkElevated = Color(0xFF172957); // sparingly
  static const Color darkInk = Color(0xFFE9EDF5);
  static const Color darkMuted = Color(0xFF9AA6C2); // 7.93:1 vs darkBg
  static const Color darkBorder = Color(0x1AE9EDF5); // ink @ ~10% alpha
  static const Color darkPrimary = Color(0xFF9AB8EE);
  static const Color darkCtaFill = darkInk;
  static const Color darkCtaText = darkBg; // 16.50:1 on ink fill

  // Dark semantic trio (ratios in class doc)
  static const Color darkSuccess = Color(0xFF4ADE80);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkError = Color(0xFFF87171);

  // Dark category hues (vs #010736): food 8.5 · transport 10.0 · shopping 11.4 ·
  // health 10.6 · entertainment 11.6 · bills 8.6 · other 10.1
  static const Color darkFood = Color(0xFFF0937E);
  static const Color darkTransport = Color(0xFF6FC3F7);
  static const Color darkShopping = Color(0xFF5AD8E6);
  static const Color darkHealth = Color(0xFF6FD3A5);
  static const Color darkEntertainment = Color(0xFFF7C04A);
  static const Color darkBills = Color(0xFFC39BF2);
  static const Color darkOther = Color(0xFFAEBEC8);

  static const Color darkFocus = darkPrimary;

  // ---- Light theme (plan §0.2, ColorHunt f9f7f7/dbe2ef/3f72af/112d4e) ----
  static const Color lightBg = Color(0xFFF9F7F7);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightTint = Color(0xFFDBE2EF);
  static const Color lightInk = Color(0xFF112D4E);
  static const Color lightPrimary = Color(0xFF3F72AF);
  static const Color lightMuted = Color(0xFF5C6B80); // 5.08:1 vs lightBg
  static const Color lightBorder = Color(0x1A112D4E); // ink @ ~10% alpha
  static const Color lightCtaFill = lightPrimary;
  static const Color lightCtaText = Color(0xFFFFFFFF); // 4.96:1 on primary

  // Light semantic trio (ratios in class doc)
  static const Color lightSuccess = Color(0xFF1B7A4A);
  static const Color lightWarning = Color(0xFF8A5A00);
  static const Color lightError = Color(0xFFB42318);

  // Light category hues (vs #F9F7F7, vs white in parens): food 5.7 (6.1) ·
  // transport 5.7 (6.1) · shopping 4.5 (4.8) · health 5.0 (5.3) ·
  // entertainment 5.4 (5.7) · bills 5.4 (5.7) · other 5.7 (6.1)
  static const Color lightFood = Color(0xFFAE3B2D);
  static const Color lightTransport = Color(0xFF1565A8);
  static const Color lightShopping = Color(0xFF0E7C96);
  static const Color lightHealth = Color(0xFF1E7A52);
  static const Color lightEntertainment = Color(0xFF856005);
  static const Color lightBills = Color(0xFF7A4BC8);
  static const Color lightOther = Color(0xFF54646E);

  static const Color lightFocus = lightPrimary; // 4.64:1 vs lightBg

  /// Legible ink tone for glyphs drawn on top of a user-picked avatar
  /// color: light ink on dark fills, dark ink on light fills.
  static Color onAvatar(Color c) =>
      c.computeLuminance() > 0.45 ? lightInk : darkInk;
}
