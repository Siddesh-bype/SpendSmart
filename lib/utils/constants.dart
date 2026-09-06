import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF123B5D);
  static const Color primaryDark = Color(0xFF16A6C7);
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
  static const Color cardLight = Color(0xFFFFFFFF);

  // Glass tokens
  static const double glassAlpha = 0.60;
}

class AppConstants {
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
}
