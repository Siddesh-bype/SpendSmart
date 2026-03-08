import 'package:flutter/material.dart';

class AppColors {
  static const Color primary    = Color(0xFF0B2D72);  // Dark Navy (light mode)
  static const Color primaryDark = Color(0xFF4A9FE0); // Bright blue (dark mode icons/borders)
  static const Color secondary  = Color(0xFF0992C2);  // Medium Blue
  static const Color accent     = Color(0xFF0AC4E0);  // Cyan

  // Category Colors — vibrant enough for both modes
  static const Color food          = Color(0xFFE07B6A);   // Soft terracotta
  static const Color transport     = Color(0xFF29B6F6);   // Sky blue (brighter)
  static const Color shopping      = Color(0xFF26C6DA);   // Bright cyan
  static const Color health        = Color(0xFF4CAF7D);   // Mint green
  static const Color entertainment = Color(0xFFF4A639);   // Amber
  static const Color bills         = Color(0xFFAB7FE8);   // Soft purple (brighter)
  static const Color other         = Color(0xFF90A4AE);   // Light slate (brighter)

  // Text
  static const Color textLight = Color(0xFF1A1F36);  // Near-black text for light mode
  static const Color textDark  = Color(0xFFE8EAF6);  // Near-white text for dark mode

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF4F7FC); // Soft cool gray
  static const Color backgroundDark  = Color(0xFF0A0F1A); // Deep spatial navy
  static const Color surfaceLight    = Color(0xFFFFFFFF);
  static const Color surfaceDark     = Color(0xFF131A2A); // Elevated dark surface
  static const Color cardLight       = Color(0xFFFFFFFF);
}

class AppConstants {
  static const double cardRadius   = 16.0;
  static const double buttonRadius = 12.0;
}
