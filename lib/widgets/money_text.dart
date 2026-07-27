import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/design.dart';

/// The single place money is rendered. Always uses tabular figures so digits
/// are fixed-width and amounts line up in columns.
///
/// Usage:
/// ```dart
/// // list tile amount, shows paise
/// MoneyText(expense.amount, currency: cur, decimals: true,
///     size: AppType.headline, weight: FontWeight.w800,
///     color: theme.colorScheme.primary)
///
/// // hero number, shrinks to fit
/// MoneyText(totalSpent, currency: settings.currency, autoShrink: true,
///     size: AppType.display, weight: FontWeight.bold, color: Colors.white)
///
/// // +/- delta
/// MoneyText(diff, currency: cur, signed: true, size: AppType.label)
/// ```
class MoneyText extends StatelessWidget {
  final double amount;
  final String currency;

  /// `#,##0.##` when true (tile-style, shows paise), `#,##0` when false.
  final bool decimals;

  /// Prefix positive values with `+`. Negatives always get `-`.
  final bool signed;

  /// Base style to build on; falls back to the ambient DefaultTextStyle.
  final TextStyle? style;
  final double? size;
  final FontWeight? weight;
  final Color? color;

  /// Wrap in a scale-down [FittedBox] — for the large hero number.
  final bool autoShrink;
  final int maxLines;
  final TextAlign? textAlign;

  const MoneyText(
    this.amount, {
    super.key,
    required this.currency,
    this.decimals = false,
    this.signed = false,
    this.style,
    this.size,
    this.weight,
    this.color,
    this.autoShrink = false,
    this.maxLines = 1,
    this.textAlign,
  });

  String get formatted {
    final digits = NumberFormat(decimals ? '#,##0.##' : '#,##0')
        .format(amount.abs());
    final sign = amount < 0 ? '-' : (signed ? '+' : '');
    return '$sign$currency$digits';
  }

  @override
  Widget build(BuildContext context) {
    // inherit: true by default, so Text merges this over DefaultTextStyle.
    final text = Text(
      formatted,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: (style ?? const TextStyle()).copyWith(
        fontSize: size,
        fontWeight: weight,
        color: color,
        fontFeatures: AppType.tabular,
      ),
    );
    // ponytail: FittedBox alignment fixed to centerLeft — the only hero call
    // site is left-aligned; expose it if a right-aligned one shows up.
    return autoShrink
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: text,
          )
        : text;
  }
}
