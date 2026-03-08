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
    this.blurRadius = 10.0,  // Reduced from 15 → 10 for smoother rendering
    this.backgroundColor = Colors.white,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: margin,
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 24,
              offset: const Offset(0, 8),
              spreadRadius: 0,
            )
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
                color: backgroundColor.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(borderRadius),
                border: border ??
                    Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                      width: 1.5,
                    ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
