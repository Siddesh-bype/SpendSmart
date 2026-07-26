import 'dart:ui';
import 'package:flutter/material.dart';

class GlassContainer extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final double blurRadius;
  final Color backgroundColor;
  final BoxBorder? border;

  const GlassContainer({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding = const EdgeInsets.all(24),
    this.margin = EdgeInsets.zero,
    this.blurRadius = 12.0,
    // Default transparent — callers pass explicit color when needed.
    // Colors.white caused dark-mode cards to look blown out.
    this.backgroundColor = Colors.transparent,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveBorder =
        border ??
        Border.all(
          color: (isDark ? Colors.white : Colors.black).withValues(
            alpha: isDark ? 0.10 : 0.06,
          ),
          width: 1,
        );
    final shadowAlpha = isDark ? 0.22 : 0.08;

    return RepaintBoundary(
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: shadowAlpha),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            ),
          ],
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: blurRadius, sigmaY: blurRadius),
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                color: backgroundColor.withValues(alpha: isDark ? 0.72 : 0.82),
                borderRadius: BorderRadius.circular(borderRadius),
                border: effectiveBorder,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
