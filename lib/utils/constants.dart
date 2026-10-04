import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF123B5D);
  static const Color secondary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF16A6C7);
  static const Color accentForeground = Color(0xFF0C1419);

  static const Color success = Color(0xFF237A57);
  static const Color warning = Color(0xFFA15C00);
  static const Color error = Color(0xFFB53A3A);

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

  // Semantic Badges / Glass Highlights
  static const Color positiveGreen = Color(0xFF4ADE80);
  static const Color negativeCoral = Color(0xFFFCA5A5);
  static const Color borderSubtleLight = Color(0xFFBBCDE0);

  // Text
  static const Color textLight = Color(0xFF17212B);
  static const Color textDark = Color(0xFFEEF4F6);
  static const Color mutedLight = Color(0xFF5F6B75);
  static const Color mutedDark = Color(0xFFAAB6BD);

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF4F7F9);
  static const Color backgroundDark = Color(0xFF0C1419);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF152129);
  static const Color surfaceElevatedDark = Color(0xFF1C2B34);
  static const Color borderLight = Color(0xFFD8E1E7);
  static const Color borderDark = Color(0xFF30414B);

  // Glass tokens
  static const double glassAlpha = 0.60;
}

/// New redesign palette (plan §0.2). ADDITIVE — existing [AppColors] stays.
///
/// Contrast (WCAG) notes, computed 2026-10-04:
/// - dark muted #9AA6C2 vs dark bg 7.93:1 (≥4.5 OK), vs dark surface 6.82:1
/// - dark ink #E9EDF5 vs dark bg 16.50:1; light ink #112D4E vs light bg 13.04:1
/// - light primary #3F72AF vs light bg 4.64:1, vs white 4.96:1
/// - dark primary/focus #8FB0E8 vs dark bg 8.80:1
/// - CTA text #010736 on ink fill 16.50:1; white on light CTA (#3F72AF) 4.96:1
/// - Semantic trio: dark success #4ADE80 11.11 / warning #FBBF24 11.59 /
///   error #F87171 7.00 vs #010736; light success #1B7A4A 5.01 /
///   warning #8A5A00 5.55 / error #B42318 6.16 vs #F9F7F7 (all ≥4.5 vs
///   their own theme bg AND vs their theme surface).
///   NOTE: no single hex can pass 4.5:1 on BOTH backgrounds, so trio values
///   are per-theme — dark values on dark bg, light values on light bg.
/// - Category hues are likewise per-theme; each ≥4.5:1 on its own theme bg.
///   Dark set vs #010736; light set vs #F9F7F7 / #FFFFFF noted in comments.
class Scheme {
  // ---- Dark theme (plan §0.2) ----
  static const Color darkBg = Color(0xFF010736);
  static const Color darkSurface = Color(0xFF0D1C42);
  static const Color darkElevated = Color(0xFF22396F); // sparingly
  static const Color darkInk = Color(0xFFE9EDF5);
  static const Color darkMuted = Color(0xFF9AA6C2); // 7.93:1 vs darkBg
  static const Color darkBorder = Color(0x1AE9EDF5); // ink @ ~10% alpha
  static const Color darkPrimary = Color(0xFF8FB0E8); // 8.80:1 vs darkBg
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

  static const Color darkFocus = Color(0xFF8FB0E8); // == darkPrimary

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

  /// One shared scrim: black at 50% (inside the plan's 40–60% band).
  static const Color scrim = Color(0x80000000);

  /// Legible ink tone for glyphs drawn on top of a user-picked avatar
  /// color: light ink on dark fills, dark ink on light fills.
  static Color onAvatar(Color c) =>
      c.computeLuminance() > 0.45 ? lightInk : darkInk;
}

class AppConstants {
  static const double buttonRadius = 12.0;
}
