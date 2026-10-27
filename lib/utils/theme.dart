import 'package:flutter/material.dart';
import 'constants.dart';
import 'design.dart';

class AppTheme {
  static ThemeData get lightTheme => _build(SchemeTheme.light);

  static ThemeData get darkTheme => _build(SchemeTheme.dark);

  static ThemeData _build(SchemeTheme tokens) {
    final isDark = tokens == SchemeTheme.dark;
    final textTheme = AppType.textTheme(
      onSurface: tokens.ink,
      muted: tokens.muted,
    );
    final scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: tokens.primary,
      onPrimary: tokens.ctaText,
      secondary: tokens.primary,
      onSecondary: tokens.ctaText,
      tertiary: tokens.success,
      onTertiary: tokens.ctaText,
      error: tokens.error,
      onError: tokens.ctaText,
      surface: tokens.surface,
      onSurface: tokens.ink,
      onSurfaceVariant: tokens.muted,
      surfaceContainerHighest: tokens.elevated,
      outline: tokens.border,
      outlineVariant: tokens.border,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: scheme.brightness,
      fontFamily: AppType.fontFamily,
      primaryColor: tokens.primary,
      scaffoldBackgroundColor: tokens.bg,
      colorScheme: scheme,
      textTheme: textTheme,
      iconTheme: IconThemeData(color: tokens.ink),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: tokens.ink,
        titleTextStyle: textTheme.titleLarge,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: tokens.ctaFill,
        foregroundColor: tokens.ctaText,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.elevated,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        contentTextStyle: textTheme.bodyMedium?.copyWith(color: tokens.ink),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.smAll),
        side: BorderSide(color: tokens.border),
        labelStyle: textTheme.labelLarge,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        labelStyle: textTheme.bodyMedium?.copyWith(color: tokens.muted),
        hintStyle: textTheme.bodyMedium?.copyWith(
          color: tokens.muted.withValues(alpha: 0.7),
        ),
        prefixIconColor: tokens.primary,
        suffixIconColor: tokens.primary,
        filled: isDark,
        fillColor: tokens.elevated,
        border: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: tokens.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: tokens.border, width: isDark ? 1 : 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.mdAll,
          borderSide: BorderSide(color: tokens.focus, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
      ),
      cardTheme: CardThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        elevation: isDark ? 2 : 1,
        color: tokens.surface,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        iconColor: tokens.muted,
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
        color: tokens.border,
        thickness: 0.5,
        space: 1,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.lgAll),
        titleTextStyle: textTheme.titleMedium,
        contentTextStyle: textTheme.bodyMedium,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: tokens.primary,
        linearTrackColor: tokens.border,
        linearMinHeight: 6,
        circularTrackColor: tokens.border,
        borderRadius: AppRadius.smAll,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          textStyle: WidgetStatePropertyAll(textTheme.labelLarge),
          side: WidgetStatePropertyAll(BorderSide(color: tokens.border)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadius.smAll),
          ),
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? tokens.primary.withValues(alpha: isDark ? 0.22 : 0.12)
                : Colors.transparent,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? tokens.primary
                : tokens.muted,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: tokens.ctaFill,
          foregroundColor: tokens.ctaText,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: tokens.primary,
          textStyle: textTheme.labelLarge,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: tokens.primary,
          textStyle: textTheme.labelLarge,
          side: BorderSide(color: tokens.border),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) =>
              s.contains(WidgetState.selected) ? tokens.primary : tokens.muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? tokens.primary.withValues(alpha: 0.4)
              : tokens.border,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
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

/// Per-brightness view onto [Scheme]. Legacy [AppColors] remains available for
/// callers that have not migrated; new display code should use these tokens.
class SchemeTheme {
  const SchemeTheme({
    required this.bg,
    required this.surface,
    required this.elevated,
    required this.tint,
    required this.ink,
    required this.muted,
    required this.border,
    required this.primary,
    required this.ctaFill,
    required this.ctaText,
    required this.success,
    required this.warning,
    required this.error,
    required this.categoryFood,
    required this.categoryTransport,
    required this.categoryShopping,
    required this.categoryHealth,
    required this.categoryEntertainment,
    required this.categoryBills,
    required this.categoryOther,
    required this.focus,
  });

  final Color bg, surface, elevated, tint, ink, muted, border, primary;
  final Color ctaFill, ctaText;
  final Color success, warning, error;
  final Color categoryFood,
      categoryTransport,
      categoryShopping,
      categoryHealth,
      categoryEntertainment,
      categoryBills,
      categoryOther;
  final Color focus;

  /// Categories in the same order as [AppColors.categoryColors].
  List<Color> get categoryColors => [
    categoryFood,
    categoryTransport,
    categoryShopping,
    categoryHealth,
    categoryEntertainment,
    categoryBills,
    categoryOther,
  ];

  static const dark = SchemeTheme(
    bg: Scheme.darkBg,
    surface: Scheme.darkSurface,
    elevated: Scheme.darkElevated,
    // Dark has no separate tint in the plan; elevated fills that role.
    tint: Scheme.darkElevated,
    ink: Scheme.darkInk,
    muted: Scheme.darkMuted,
    border: Scheme.darkBorder,
    primary: Scheme.darkPrimary,
    ctaFill: Scheme.darkCtaFill,
    ctaText: Scheme.darkCtaText,
    success: Scheme.darkSuccess,
    warning: Scheme.darkWarning,
    error: Scheme.darkError,
    categoryFood: Scheme.darkFood,
    categoryTransport: Scheme.darkTransport,
    categoryShopping: Scheme.darkShopping,
    categoryHealth: Scheme.darkHealth,
    categoryEntertainment: Scheme.darkEntertainment,
    categoryBills: Scheme.darkBills,
    categoryOther: Scheme.darkOther,
    focus: Scheme.darkFocus,
  );

  static const light = SchemeTheme(
    bg: Scheme.lightBg,
    surface: Scheme.lightSurface,
    elevated: Scheme.lightTint,
    tint: Scheme.lightTint,
    ink: Scheme.lightInk,
    muted: Scheme.lightMuted,
    border: Scheme.lightBorder,
    primary: Scheme.lightPrimary,
    ctaFill: Scheme.lightCtaFill,
    ctaText: Scheme.lightCtaText,
    success: Scheme.lightSuccess,
    warning: Scheme.lightWarning,
    error: Scheme.lightError,
    categoryFood: Scheme.lightFood,
    categoryTransport: Scheme.lightTransport,
    categoryShopping: Scheme.lightShopping,
    categoryHealth: Scheme.lightHealth,
    categoryEntertainment: Scheme.lightEntertainment,
    categoryBills: Scheme.lightBills,
    categoryOther: Scheme.lightOther,
    focus: Scheme.lightFocus,
  );

  static SchemeTheme of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;
}
