import 'package:flutter/material.dart';
import 'constants.dart';
import 'design.dart';

class AppTheme {
  static ThemeData get lightTheme => _build(
    brightness: Brightness.light,
    primary: AppColors.primary,
    background: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    surfaceElevated: AppColors.cardLight,
    onSurface: AppColors.textLight,
    muted: AppColors.mutedLight,
    border: AppColors.borderLight,
    onError: Colors.white,
    iconColor: AppColors.primary,
    inputFilled: false,
  );

  static ThemeData get darkTheme => _build(
    brightness: Brightness.dark,
    primary: AppColors.accent,
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    surfaceElevated: AppColors.surfaceElevatedDark,
    onSurface: AppColors.textDark,
    muted: AppColors.mutedDark,
    border: AppColors.borderDark,
    onError: Colors.black,
    iconColor: AppColors.textDark,
    inputFilled: true,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color primary,
    required Color background,
    required Color surface,
    required Color surfaceElevated,
    required Color onSurface,
    required Color muted,
    required Color border,
    required Color onError,
    required Color iconColor,
    required bool inputFilled,
  }) {
    final isDark = brightness == Brightness.dark;
    final textTheme = AppType.textTheme(onSurface: onSurface, muted: muted);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      onSecondary: Colors.white,
      tertiary: AppColors.accent,
      onTertiary: AppColors.accentForeground,
      error: AppColors.error,
      onError: onError,
      surface: surface,
      onSurface: onSurface,
      onSurfaceVariant: muted,
      surfaceContainerHighest: surfaceElevated,
      outline: border,
      outlineVariant: border.withValues(alpha: isDark ? 0.5 : 0.6),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: AppType.fontFamily,
      primaryColor: primary,
      scaffoldBackgroundColor: background,
      colorScheme: scheme,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: iconColor),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: onSurface,
        titleTextStyle: textTheme.titleLarge,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.accent,
        foregroundColor: AppColors.accentForeground,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: isDark ? AppColors.textLight : AppColors.textDark,
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        side: BorderSide(color: primary.withValues(alpha: isDark ? 0.16 : 0.12)),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: textTheme.bodyMedium?.copyWith(color: muted),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: muted.withValues(alpha: 0.7),
        ),
        prefixIconColor: primary,
        suffixIconColor: primary,
        filled: inputFilled,
        fillColor: surfaceElevated,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: border, width: isDark ? 1 : 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        elevation: isDark ? 2 : 1,
        color: surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        iconColor: muted,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall,
        leadingAndTrailingTextStyle: textTheme.labelMedium,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
      ),
      // Hairline rules: later phases build a "ledger rail" from these.
      dividerTheme: DividerThemeData(
        color: border,
        thickness: 0.5,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primary,
        linearTrackColor: border,
        linearMinHeight: 6,
        circularTrackColor: border,
        borderRadius: AppRadius.smAll,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          side: WidgetStatePropertyAll(BorderSide(color: border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? primary.withValues(alpha: isDark ? 0.22 : 0.12)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected) ? primary : muted,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary
              : (isDark ? Colors.grey.shade600 : Colors.grey),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? primary.withValues(alpha: 0.4)
              : Colors.grey.withValues(alpha: isDark ? 0.3 : 0.4),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }
}
