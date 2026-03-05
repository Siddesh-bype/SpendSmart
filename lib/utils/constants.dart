import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF81A6C6);    // Steel blue
  static const Color secondary = Color(0xFFAACDDC);  // Light blue
  static const Color accent = Color(0xFFD2C4B4);     // Warm taupe

  // Category Colors (harmonized with blue/beige palette)
  static const Color food = Color(0xFFE07B6A);        // Soft terracotta
  static const Color transport = Color(0xFF81A6C6);   // Steel blue (matches primary)
  static const Color shopping = Color(0xFFAACDDC);    // Light blue
  static const Color health = Color(0xFF7BAE9E);      // Muted teal
  static const Color entertainment = Color(0xFFD4A96A); // Warm amber
  static const Color bills = Color(0xFFAA8FBF);       // Soft lavender
  static const Color other = Color(0xFFD2C4B4);       // Warm taupe

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF3E3D0); // Warm beige
  static const Color backgroundDark = Color(0xFF1C2433);  // Dark navy
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF263245);     // Slightly lighter navy
  static const Color cardLight = Color(0xFFD2C4B4);       // Warm taupe cards
}

class AppConstants {
  static const double cardRadius = 16.0;
  static const double buttonRadius = 12.0;
}
