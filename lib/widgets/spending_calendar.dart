import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/expense.dart';
import '../utils/constants.dart';
import '../utils/design.dart';
import '../utils/financial_period.dart';

/// A grid showing how much was spent each day of a [FinancialPeriod].
///
/// Spend is encoded twice on purpose: as a tinted background and as the amount
/// itself. Colour alone would fail for colour-blind users and in bright sun,
/// and the number alone makes it hard to spot the expensive days at a glance.
///
/// The grid walks the period, not the calendar month. With a custom starting
/// day those differ, and rendering the calendar month instead left the days
/// before the start looking empty while the days after the month boundary --
/// which the totals above the calendar *do* count -- had no cell at all.
class SpendingCalendar extends StatelessWidget {
  const SpendingCalendar({
    super.key,
    required this.period,
    required this.selectedDay,
    required this.expenses,
    required this.currency,
    required this.onDaySelected,
    this.lastSelectableDay,
    this.goals = const {},
  });

  /// The cycle to render, one cell per day.
  final FinancialPeriod period;
  final DateTime selectedDay;

  /// Expenses to sum per day. Anything outside [period] is ignored.
  final List<Expense> expenses;
  final String currency;
  final ValueChanged<DateTime> onDaySelected;

  /// Days after this are shown greyed and are not tappable. Null means the
  /// whole period is selectable.
  final DateTime? lastSelectableDay;

  /// Per-day limits keyed 'YYYY-MM-DD'. Days with one get a marker, and go red
  /// when spending passes it.
  final Map<String, double> goals;

  static const _cellSpacing = 3.0;

  static String _dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    // DateTime.weekday is 1=Mon..7=Sun, and the grid starts on Monday.
    final leadingBlanks = period.start.weekday - 1;

    final totals = <String, double>{};
    for (final expense in expenses) {
      if (!period.contains(expense.date)) continue;
      final key = _dayKey(expense.date);
      totals[key] = (totals[key] ?? 0) + expense.amount;
    }
    // Scaled against the busiest day, so the ramp is readable whether the
    // period peaks at 200 or 20,000.
    final busiest = totals.values.fold(0.0, (a, b) => a > b ? a : b);

    final days = [
      for (var i = 0; i < period.totalDays; i++)
        DateTime(period.start.year, period.start.month, period.start.day + i),
    ];

    final cells = <Widget>[
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (final date in days)
        _dayCell(
          context,
          theme,
          scheme,
          date,
          totals[_dayKey(date)] ?? 0,
          busiest,
        ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final label in const ['M', 'T', 'W', 'T', 'F', 'S', 'S'])
              Expanded(
                child: Center(
                  child: Text(
                    label,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: _cellSpacing,
          crossAxisSpacing: _cellSpacing,
          padding: EdgeInsets.zero,
          children: cells,
        ),
      ],
    );
  }

  Widget _dayCell(
    BuildContext context,
    ThemeData theme,
    ColorScheme scheme,
    DateTime date,
    double spent,
    double busiest,
  ) {
    final isSelected = date.year == selectedDay.year &&
        date.month == selectedDay.month &&
        date.day == selectedDay.day;
    final isFuture =
        lastSelectableDay != null && date.isAfter(lastSelectableDay!);

    final goal = goals[_dayKey(date)];
    final overGoal = goal != null && spent > goal;

    // Floor at 0.10 so any spending is visible, not just near-peak days.
    final intensity = busiest > 0 && spent > 0 ? 0.10 + (spent / busiest) * 0.55 : 0.0;
    final background = isSelected
        ? scheme.primary
        : overGoal
            ? AppColors.error.withValues(alpha: 0.18)
            : spent > 0
                ? AppColors.accent.withValues(alpha: intensity)
                : Colors.transparent;
    final foreground = isSelected
        ? scheme.onPrimary
        : isFuture
            ? scheme.onSurfaceVariant.withValues(alpha: 0.4)
            : scheme.onSurface;

    return Semantics(
      button: !isFuture,
      selected: isSelected,
      label: '${date.day} ${_monthName(date.month)}, '
          '${spent > 0 ? '$currency${spent.round()} spent' : 'nothing spent'}',
      child: InkWell(
        onTap: isFuture
            ? null
            : () {
                HapticFeedback.selectionClick();
                onDaySelected(date);
              },
        borderRadius: AppRadius.smAll,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppRadius.smAll,
            border: isSelected
                ? null
                : Border.all(
                    color: overGoal
                        ? AppColors.error.withValues(alpha: 0.5)
                        : scheme.outlineVariant,
                    width: overGoal ? 1 : 0.5,
                  ),
          ),
          child: Stack(
            children: [
              if (goal != null)
                Positioned(
                  top: 3,
                  right: 3,
                  child: Icon(
                    Icons.flag,
                    size: 8,
                    color: isSelected
                        ? scheme.onPrimary
                        : overGoal
                            ? AppColors.error
                            : scheme.onSurfaceVariant,
                  ),
                ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${date.day}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: foreground,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                  ),
                  if (spent > 0)
                    Text(
                      _compact(spent),
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontSize: AppType.micro,
                        height: 1.1,
                        color: foreground,
                        fontFeatures: AppType.tabular,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A cell is ~40px wide, so amounts are abbreviated: 1234 -> 1.2k.
  static String _compact(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
    return amount.round().toString();
  }

  static String _monthName(int month) => const [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ][month - 1];
}
