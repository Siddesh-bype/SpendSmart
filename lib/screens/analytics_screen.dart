import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../utils/constants.dart';
import '../utils/date_extension.dart';
import '../utils/design.dart';
import '../widgets/glass_container.dart';
import '../widgets/money_text.dart';
import '../widgets/section_header.dart';
import '../widgets/spending_calendar.dart';
import 'transactions_screen.dart';

Map<Category, double> categoryTotalsForDay(
  Iterable<Expense> expenses,
  DateTime day,
) {
  final totals = <Category, double>{};
  for (final expense in expenses) {
    if (expense.isUncategorized ||
        expense.date.year != day.year ||
        expense.date.month != day.month ||
        expense.date.day != day.day) {
      continue;
    }
    totals[expense.category] = (totals[expense.category] ?? 0) + expense.amount;
  }
  return totals;
}

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  // Built in initState rather than `late final`: with a lazy initialiser the
  // empty-state path never touches _tabs, so dispose() would construct a
  // controller during teardown and look up a deactivated ancestor.
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  DateTime _selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _selectedDay = DateTime.now();

  void _changeMonth(int delta) {
    HapticFeedback.lightImpact();
    _selectMonth(DateTime(_selectedMonth.year, _selectedMonth.month + delta));
  }

  void _selectMonth(DateTime month) {
    final days = DateTime(month.year, month.month + 1, 0).day;
    final day = _selectedDay.day.clamp(1, days);
    setState(() {
      _selectedMonth = DateTime(month.year, month.month);
      _selectedDay = DateTime(month.year, month.month, day);
    });
  }

  void _changeDay(int delta) {
    HapticFeedback.selectionClick();
    setState(() => _selectedDay = _selectedDay.add(Duration(days: delta)));
  }

  Future<void> _pickDay() async {
    final now = DateTime.now();
    final first = DateTime(_selectedMonth.year, _selectedMonth.month);
    final monthEnd = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);
    final last = monthEnd.isAfter(now) ? now : monthEnd;
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay.isAfter(last) ? last : _selectedDay,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null && mounted) setState(() => _selectedDay = picked);
  }

  @override
  Widget build(BuildContext context) {
    final expenses = ref
        .watch(expenseProvider)
        .where((e) => !e.isUncategorized)
        .toList();
    final settings = ref.watch(appSettingsProvider);
    final now = DateTime.now();

    final monthlyExpenses = expenses
        .where(
          (e) => e.date.isTargetCustomMonth(
            _selectedMonth.month,
            _selectedMonth.year,
            settings.startingDayOfMonth,
          ),
        )
        .toList();

    // Previous month for MoM comparison
    final prevMonth = DateTime(_selectedMonth.year, _selectedMonth.month - 1);
    final prevExpenses = expenses
        .where(
          (e) => e.date.isTargetCustomMonth(
            prevMonth.month,
            prevMonth.year,
            settings.startingDayOfMonth,
          ),
        )
        .toList();

    final totalSpent = monthlyExpenses.fold(0.0, (a, b) => a + b.amount);
    final prevTotal = prevExpenses.fold(0.0, (a, b) => a + b.amount);
    final momChange = prevTotal > 0
        ? ((totalSpent - prevTotal) / prevTotal * 100)
        : 0.0;
    final isCurrentMonth =
        _selectedMonth.month == now.month && _selectedMonth.year == now.year;
    final firstSelectableDay = DateTime(
      _selectedMonth.year,
      _selectedMonth.month,
    );
    final monthLastDay = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    );
    final lastSelectableDay = isCurrentMonth ? now : monthLastDay;
    final canSelectPreviousDay = _selectedDay.isAfter(firstSelectableDay);
    final canSelectNextDay = _selectedDay.isBefore(lastSelectableDay);

    final catSums = <Category, double>{};
    for (final e in monthlyExpenses) {
      catSums[e.category] = (catSums[e.category] ?? 0) + e.amount;
    }
    final sortedCats = catSums.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final dailyCatSums = categoryTotalsForDay(monthlyExpenses, _selectedDay);
    final dailyCats = Category.values
        .where(dailyCatSums.containsKey)
        .map((category) => MapEntry(category, dailyCatSums[category]!))
        .toList();

    // 6-month bar data — keep list so index maps to DateTime for tap
    final sixMonths = List.generate(6, (i) {
      final m = DateTime(now.year, now.month - (5 - i));
      final total = expenses
          .where(
            (e) => e.date.isTargetCustomMonth(
              m.month,
              m.year,
              settings.startingDayOfMonth,
            ),
          )
          .fold(0.0, (a, b) => a + b.amount);
      return (month: m, label: DateFormat('MMM').format(m), total: total);
    });

    // Biggest single expense this month
    final biggestExpense = monthlyExpenses.isNotEmpty
        ? monthlyExpenses.reduce((a, b) => a.amount > b.amount ? a : b)
        : null;
    final daysInMonth = DateTime(
      _selectedMonth.year,
      _selectedMonth.month + 1,
      0,
    ).day;
    final daysElapsed = isCurrentMonth ? now.day : daysInMonth;
    final dailyAvg = daysElapsed > 0 ? totalSpent / daysElapsed : 0.0;

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics')),
      body: monthlyExpenses.isEmpty && sixMonths.every((m) => m.total == 0)
          ? _emptyState()
          : Column(
              children: [
                // Month Switcher
                Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                      vertical: AppSpacing.xs,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left),
                          onPressed: () => _changeMonth(-1),
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          DateFormat('MMMM yyyy').format(_selectedMonth),
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        if (isCurrentMonth)
                          Container(
                            margin: const EdgeInsets.only(left: AppSpacing.sm),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.sm,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.15),
                              borderRadius: AppRadius.smAll,
                            ),
                            child: Text(
                              'Current',
                              style: Theme.of(context).textTheme.labelSmall
                                  ?.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ),
                        const SizedBox(width: AppSpacing.xs),
                        IconButton(
                          icon: Icon(
                            Icons.chevron_right,
                            color: isCurrentMonth
                                ? Theme.of(context).colorScheme.outline
                                : null,
                          ),
                          onPressed: isCurrentMonth
                              ? null
                              : () => _changeMonth(1),
                        ),
                      ],
                    ),
                  ),
                TabBar(
                  controller: _tabs,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Categories'),
                    Tab(text: 'Trends'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    controller: _tabs,
                    children: [
                      CustomScrollView(
                        key: const PageStorageKey('analytics-overview'),
                        slivers: [
                // Total Spent Card
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.md,
                    ),
                    child: _totalCard(
                      totalSpent,
                      prevTotal,
                      momChange,
                      settings.currency,
                    ),
                  ),
                ),

                // Stats row — Daily Avg + Biggest Expense
                if (totalSpent > 0)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _statChip(
                              icon: Icons.today_rounded,
                              label: 'Daily Avg',
                              amount: dailyAvg,
                              currency: settings.currency,
                              color: AppColors.secondary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          if (biggestExpense != null)
                            Expanded(
                              child: _statChip(
                                icon: Icons.arrow_upward_rounded,
                                label: 'Top Expense',
                                amount: biggestExpense.amount,
                                currency: settings.currency,
                                sublabel: biggestExpense.title,
                                color: AppColors.warning,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // Pie Chart
                // Daily Spending Chart
                if (monthlyExpenses.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        0,
                      ),
                      child: const SectionHeader(title: 'Daily Spending'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.sm,
                      ),
                      child: SizedBox(
                        height: 180,
                        child: _dailySpendingChart(
                          monthlyExpenses,
                          daysInMonth,
                          settings.currency,
                        ),
                      ),
                    ),
                  ),
                ],

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: const SectionHeader(
                      title: 'Calendar',
                      subtitle: 'Tap a day to see its breakdown below',
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      0,
                    ),
                    child: SpendingCalendar(
                      month: _selectedMonth,
                      selectedDay: _selectedDay,
                      expenses: monthlyExpenses,
                      currency: settings.currency,
                      lastSelectableDay: lastSelectableDay,
                      onDaySelected: (day) =>
                          setState(() => _selectedDay = day),
                    ),
                  ),
                ),

                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.lg,
                      AppSpacing.lg,
                      0,
                    ),
                    child: const SectionHeader(title: 'Day by Category'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Previous day',
                          onPressed: canSelectPreviousDay
                              ? () => _changeDay(-1)
                              : null,
                          icon: const Icon(Icons.chevron_left_rounded),
                        ),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _pickDay,
                            icon: const Icon(
                              Icons.calendar_today_outlined,
                              size: AppType.headline,
                            ),
                            label: Text(
                              DateFormat('EEE, d MMM').format(_selectedDay),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: 'Next day',
                          onPressed: canSelectNextDay
                              ? () => _changeDay(1)
                              : null,
                          icon: const Icon(Icons.chevron_right_rounded),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: _dailyCategoryCard(dailyCats, settings.currency),
                  ),
                ),

                        ],
                      ),
                      CustomScrollView(
                        key: const PageStorageKey('analytics-categories'),
                        slivers: [
                if (sortedCats.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        0,
                      ),
                      child: const SectionHeader(title: 'Spending Breakdown'),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 220,
                      child: PieChart(
                        PieChartData(
                          sections: sortedCats
                              .map(
                                (e) => PieChartSectionData(
                                  value: e.value,
                                  color: e.key.color,
                                  title:
                                      '${(e.value / totalSpent * 100).toStringAsFixed(0)}%',
                                  titleStyle: const TextStyle(
                                    fontSize: AppType.caption,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  radius: 80,
                                ),
                              )
                              .toList(),
                          sectionsSpace: 3,
                          centerSpaceRadius: 30,
                        ),
                      ),
                    ),
                  ),
                ],

                // Category List
                if (sortedCats.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.lg,
                        AppSpacing.lg,
                        0,
                      ),
                      child: const SectionHeader(title: 'By Category'),
                    ),
                  ),
                  SliverList(
                    delegate: SliverChildBuilderDelegate((context, i) {
                      final e = sortedCats[i];
                      final pct = totalSpent > 0 ? e.value / totalSpent : 0.0;
                      final theme = Theme.of(context);
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.md,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    TransactionsScreen(initialCategory: e.key),
                              ),
                            );
                          },
                          child: GlassContainer(
                            borderRadius: AppRadius.md,
                            backgroundColor:
                                theme.cardTheme.color ?? theme.colorScheme.surface,
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: e.key.color.withValues(
                                              alpha: 0.15,
                                            ),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            e.key.icon,
                                            color: e.key.color,
                                            size: 20,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.md),
                                        Text(
                                          e.key.name,
                                          style: theme.textTheme.titleSmall
                                              ?.copyWith(
                                                fontWeight: FontWeight.w700,
                                              ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        MoneyText(
                                          e.value,
                                          currency: settings.currency,
                                          size: AppType.headline,
                                          weight: FontWeight.w800,
                                          color: theme.colorScheme.onSurface,
                                          textAlign: TextAlign.right,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${(pct * 100).toStringAsFixed(1)}%',
                                          style: theme.textTheme.labelMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.md),
                                ClipRRect(
                                  borderRadius: AppRadius.smAll,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(begin: 0, end: pct),
                                    duration: const Duration(
                                      milliseconds: 1000,
                                    ),
                                    curve: Curves.easeOutExpo,
                                    builder: (context, val, _) =>
                                        LinearProgressIndicator(
                                          value: val,
                                          backgroundColor: theme
                                              .colorScheme
                                              .surfaceContainerHighest
                                              .withValues(alpha: 0.4),
                                          color: e.key.color,
                                          minHeight: 8,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }, childCount: sortedCats.length),
                  ),
                ],

                        ],
                      ),
                      CustomScrollView(
                        key: const PageStorageKey('analytics-trends'),
                        slivers: [
                // 6-Month Bar Chart
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      0,
                    ),
                    child: const SectionHeader(title: '6-Month Overview'),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      160,
                    ),
                    child: SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          gridData: const FlGridData(show: false),
                          borderData: FlBorderData(show: false),
                          barTouchData: BarTouchData(
                            touchCallback: (event, response) {
                              if (event is FlTapUpEvent &&
                                  response != null &&
                                  response.spot != null) {
                                final idx = response.spot!.touchedBarGroupIndex;
                                if (idx >= 0 && idx < sixMonths.length) {
                                  HapticFeedback.selectionClick();
                                  _selectMonth(sixMonths[idx].month);
                                }
                              }
                            },
                          ),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, m) {
                                  final idx = v.toInt();
                                  if (idx >= 0 && idx < sixMonths.length) {
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        top: AppSpacing.xs,
                                      ),
                                      child: Text(
                                        sixMonths[idx].label,
                                        style: _axisLabelStyle(context),
                                      ),
                                    );
                                  }
                                  return const SizedBox();
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 44,
                                getTitlesWidget: (v, m) => Text(
                                  NumberFormat.compact().format(v),
                                  style: _axisLabelStyle(context),
                                ),
                              ),
                            ),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                          ),
                          barGroups: sixMonths.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final data = entry.value;
                            final isSelected =
                                data.month.month == _selectedMonth.month &&
                                data.month.year == _selectedMonth.year;
                            return BarChartGroupData(
                              x: idx,
                              barRods: [
                                BarChartRodData(
                                  toY: data.total,
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.secondary.withValues(
                                          alpha: 0.6,
                                        ),
                                  width: 28,
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(AppRadius.sm),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ),
                ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Chart axis labels: theme-muted, tabular so tick values don't jitter.
  TextStyle? _axisLabelStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(
        fontFeatures: AppType.tabular,
      );

  Widget _totalCard(
    double total,
    double prevTotal,
    double momChange,
    String currency,
  ) {
    final momUp = momChange > 0;
    // On the navy card: warm for "up" (bad), mint for "down" (good). Both are
    // read against a dark brand fill, so they stay light rather than
    // AppColors.error/success which are tuned for surface backgrounds.
    final momColor = momUp
        ? const Color(0xFFFCA5A5)
        : const Color(0xFF4ADE80);
    return GlassContainer(
      borderRadius: AppRadius.lg,
      backgroundColor: AppColors.primary,
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Total Spent',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: AppType.label,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                MoneyText(
                  total,
                  currency: currency,
                  autoShrink: true,
                  size: AppType.display,
                  weight: FontWeight.bold,
                  color: Colors.white,
                ),
                const Text(
                  'This Month',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: AppType.caption,
                  ),
                ),
              ],
            ),
          ),
          if (prevTotal > 0)
            Container(
              margin: const EdgeInsets.only(left: AppSpacing.md),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: momColor.withValues(alpha: 0.2),
                borderRadius: AppRadius.smAll,
                border: Border.all(color: momColor.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    momUp ? Icons.show_chart : Icons.trending_down,
                    color: momColor,
                    size: AppType.headline,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    '${momUp ? '+' : ''}${momChange.toStringAsFixed(1)}%',
                    style: TextStyle(
                      color: momColor,
                      fontWeight: FontWeight.bold,
                      fontSize: AppType.label,
                      fontFeatures: AppType.tabular,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _dailySpendingChart(List expenses, int daysInMonth, String currency) {
    final dailySpending = List<double>.filled(daysInMonth, 0);
    for (final e in expenses) {
      final day = e.date.day - 1;
      if (day >= 0 && day < daysInMonth) {
        dailySpending[day] += e.amount;
      }
    }

    final spots = <FlSpot>[];
    for (int i = 0; i < daysInMonth; i++) {
      spots.add(FlSpot(i.toDouble(), dailySpending[i]));
    }

    final maxY = dailySpending.reduce((a, b) => a > b ? a : b);
    final scheme = Theme.of(context).colorScheme;
    final hairline = Theme.of(context).dividerTheme.thickness ?? 1;

    return GlassContainer(
      borderRadius: AppRadius.md,
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: maxY > 0 ? maxY / 4 : 1,
            getDrawingHorizontalLine: (value) =>
                FlLine(color: scheme.outlineVariant, strokeWidth: hairline),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (daysInMonth / 7).ceilToDouble(),
                getTitlesWidget: (value, meta) {
                  final day = value.toInt() + 1;
                  if (day <= daysInMonth &&
                      day % ((daysInMonth / 7).ceil()) == 1) {
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.xs),
                      child: Text('$day', style: _axisLabelStyle(context)),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  NumberFormat.compact().format(value),
                  style: _axisLabelStyle(context),
                ),
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primary,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primary.withValues(alpha: 0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    '${spot.x.toInt() + 1}: $currency${NumberFormat('#,##0').format(spot.y)}',
                    const TextStyle(
                      color: Colors.white,
                      fontSize: AppType.caption,
                      fontWeight: FontWeight.bold,
                      fontFeatures: AppType.tabular,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _dailyCategoryCard(
    List<MapEntry<Category, double>> categories,
    String currency,
  ) {
    if (categories.isEmpty) {
      return GlassContainer(
        borderRadius: AppRadius.md,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy_outlined,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            const Flexible(
              child: Text('No spending recorded for this day'),
            ),
          ],
        ),
      );
    }

    final maxY = categories
        .map((entry) => entry.value)
        .reduce((a, b) => a > b ? a : b);
    final scheme = Theme.of(context).colorScheme;
    final hairline = Theme.of(context).dividerTheme.thickness ?? 1;
    return GlassContainer(
      borderRadius: AppRadius.md,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.md,
      ),
      child: Column(
        children: [
          SizedBox(
            height: 185,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxY * 1.15,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                  getDrawingHorizontalLine: (_) =>
                      FlLine(color: scheme.outlineVariant, strokeWidth: hairline),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, _) => Text(
                        NumberFormat.compact().format(value),
                        style: _axisLabelStyle(context),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, _) {
                        final index = value.toInt();
                        if (index < 0 || index >= categories.length) {
                          return const SizedBox();
                        }
                        final category = categories[index].key;
                        return Padding(
                          padding: const EdgeInsets.only(top: AppSpacing.xs),
                          child: Icon(
                            category.icon,
                            color: category.color,
                            size: AppType.headline,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final entry = categories[group.x.toInt()];
                      return BarTooltipItem(
                        '${entry.key.displayName}\n$currency${NumberFormat('#,##0').format(entry.value)}',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontFeatures: AppType.tabular,
                        ),
                      );
                    },
                  ),
                ),
                barGroups: categories.asMap().entries.map((item) {
                  final category = item.value.key;
                  return BarChartGroupData(
                    x: item.key,
                    barRods: [
                      BarChartRodData(
                        toY: item.value.value,
                        color: category.color,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(AppRadius.sm),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: categories.map((entry) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: entry.key.color.withValues(alpha: 0.12),
                  borderRadius: AppRadius.smAll,
                ),
                child: Text(
                  '${entry.key.displayName} $currency${NumberFormat.compact().format(entry.value)}',
                  style: TextStyle(
                    color: entry.key.color,
                    fontSize: AppType.caption,
                    fontWeight: FontWeight.w700,
                    fontFeatures: AppType.tabular,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.bar_chart_rounded,
          size: 72,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('No data yet', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxl),
          child: Text(
            'Add expenses to see your analytics here.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  );

  Widget _statChip({
    required IconData icon,
    required String label,
    required double amount,
    required String currency,
    String? sublabel,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.xs),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: AppType.headline),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                MoneyText(
                  amount,
                  currency: currency,
                  size: AppType.body,
                  weight: FontWeight.w800,
                  color: color,
                ),
                if (sublabel != null)
                  Text(
                    sublabel,
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
