import 'package:flutter/material.dart';

import '../utils/design.dart';
import '../utils/theme.dart';

/// A reusable empty-state placeholder widget.
/// Replaces duplicated empty-column patterns across screens.
///
/// Usage:
/// ```dart
/// if (items.isEmpty)
///   const EmptyState(
///     icon: Icons.receipt_long_rounded,
///     title: 'No transactions yet',
///     subtitle: 'Add your first expense using the + button',
///   )
/// ```
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? action;
  final Color? iconColor;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.action,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);
    final color = iconColor ?? scheme.primary.withValues(alpha: 0.24);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: color),
            const SizedBox(height: AppSpacing.lg),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                subtitle!,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.muted),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
