import 'package:flutter/material.dart';

import '../utils/design.dart';
import '../utils/theme.dart';

/// A small labelled statistic used on the home and analytics screens.
///
/// Pass a [color] for the accent style (icon circle, translucent fill and
/// border); omit it for the neutral tint chip. Values are pre-formatted
/// strings — money should come from `formatMoney` so digits stay consistent.
class StatChip extends StatelessWidget {
  const StatChip({
    super.key,
    required this.label,
    required this.value,
    this.sublabel,
    this.icon,
    this.color,
  });

  final String label;
  final String value;
  final String? sublabel;
  final IconData? icon;

  /// Accent color; null renders the neutral tint style.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = SchemeTheme.of(context);
    final theme = Theme.of(context);
    final accent = color ?? scheme.ink;
    final isAccent = color != null;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: isAccent ? accent.withValues(alpha: 0.08) : scheme.tint,
        borderRadius: AppRadius.mdAll,
        border: isAccent ? Border.all(color: accent.withValues(alpha: 0.2)) : null,
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.xs),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accent, size: AppType.headline),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: isAccent
                      ? theme.textTheme.labelMedium
                      : TextStyle(color: scheme.muted, fontSize: AppType.caption),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isAccent ? accent : scheme.ink,
                    fontSize: AppType.body,
                    fontWeight: isAccent ? FontWeight.w800 : FontWeight.w600,
                    fontFeatures: AppType.tabular,
                  ),
                ),
                if (sublabel != null)
                  Text(
                    sublabel!,
                    style: theme.textTheme.labelSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
