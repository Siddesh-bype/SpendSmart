import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../models/app_settings.dart';
import '../services/merchant_anomaly_service.dart';
import '../services/ai_financial_advisor_service.dart';
import '../services/financial_calculation_engine.dart';
import '../utils/design.dart';
import '../utils/theme.dart';
import '../utils/financial_period.dart';
import '../widgets/money_text.dart';
import '../widgets/section_header.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allExpenses = ref.watch(expenseProvider);
    final expenses = allExpenses.where((e) => !e.isUncategorized).toList();
    final budgets = ref.watch(budgetProvider);
    final settings = ref.watch(appSettingsProvider);
    final now = DateTime.now();
    final period = FinancialPeriod.containing(now, settings.startingDayOfMonth);

    final thisMonth = expenses.where((e) => period.contains(e.date)).toList();

    final previous = period.previous;
    final lastMonth = expenses.where((e) => previous.contains(e.date)).toList();

    final thisTotal = thisMonth.fold(0.0, (a, b) => a + b.amount);
    final lastTotal = lastMonth.fold(0.0, (a, b) => a + b.amount);
    final change = lastTotal > 0 ? ((thisTotal - lastTotal) / lastTotal * 100) : 0.0;

    // AI Financial Review & Health Scoring
    final aiReview = AiFinancialAdvisorService.generateReview(
      allExpenses: allExpenses,
      budgets: budgets,
      settings: settings,
      referenceDate: now,
    );

    // Category breakdown this month
    final catSums = <Category, double>{};
    for (final e in thisMonth) {
      catSums[e.category] = (catSums[e.category] ?? 0) + e.amount;
    }
    final topCat = catSums.entries.isEmpty
        ? null
        : catSums.entries.reduce((a, b) => a.value > b.value ? a : b);

    // Recurring expenses
    final recurring = _detectRecurring(expenses);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Spending Insights & AI'),
        actions: [
          IconButton(
            tooltip: 'Ask AI Advisor',
            constraints:
                const BoxConstraints.tightFor(width: 44, height: 44),
            icon: Icon(
              Icons.chat_bubble_outline,
              color: SchemeTheme.of(context).primary,
            ),
            onPressed: () => _showAiChatModal(context, expenses, settings),
          ),
        ],
      ),
      body: expenses.isEmpty
          ? Center(
              child: Text(
                'Add some expenses to see insights!',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            )
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg + MediaQuery.of(context).padding.bottom,
              ),
              children: [
                // 1. AI Health Score & Pacing Header Card
                _aiHealthScoreCard(context, aiReview, settings.currency),
                const SizedBox(height: AppSpacing.lg),

                // 2. Month comparison card
                _comparisonCard(
                  thisTotal,
                  lastTotal,
                  change,
                  settings.currency,
                ),
                const SizedBox(height: AppSpacing.lg),

                // 3. On-device merchant spikes
                _MerchantAlertsSection(
                  expenses: allExpenses,
                  currency: settings.currency,
                  monthlyBudget: settings.monthlyBudget,
                  startingDayOfMonth: settings.startingDayOfMonth,
                ),

                // 4. Top spending category
                if (topCat != null) ...[
                  _infoCard(
                    context,
                    icon: topCat.key.icon,
                    color: SchemeTheme.of(
                      context,
                    ).categoryColors[topCat.key.index],
                    title: 'Top Category: ${topCat.key.displayName}',
                    subtitle:
                        '${settings.currency}${NumberFormat('#,##0').format(topCat.value)} this month'
                        ' (${thisTotal > 0 ? (topCat.value / thisTotal * 100).toStringAsFixed(0) : 0}% of spending)',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // 5. Recurring subscriptions
                if (recurring.isNotEmpty) ...[
                  const SectionHeader(title: 'Recurring Expenses Detected'),
                  ...recurring.map(
                    (r) => _recurringTile(context, r, settings.currency),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],

                // 6. AI Smart Recommendations
                const SectionHeader(title: 'AI Smart Recommendations'),
                ...aiReview.recommendations.map((r) => _aiRecommendationCard(context, r, settings.currency)),
              ],
            ),
    );
  }

  Widget _aiHealthScoreCard(BuildContext context, AiFinancialReview review, String currency) {
    final report = review.healthReport;
    final pacing = review.pacing;
    final money = NumberFormat('#,##0');
    final scheme = SchemeTheme.of(context);

    Color tierColor;
    switch (report.tier) {
      case HealthScoreTier.excellent:
        tierColor = scheme.success;
        break;
      case HealthScoreTier.good:
        tierColor = scheme.primary;
        break;
      case HealthScoreTier.fair:
        tierColor = scheme.warning;
        break;
      case HealthScoreTier.needsAttention:
        tierColor = scheme.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: tierColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.auto_awesome, color: tierColor, size: 18),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Text(
                    'Financial Health & Pacing',
                    style: TextStyle(
                      color: scheme.ink,
                      fontSize: AppType.title,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: tierColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${report.score} / 100',
                  style: TextStyle(
                    color: tierColor,
                    fontWeight: FontWeight.bold,
                    fontSize: AppType.label,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            report.summary,
            style: TextStyle(color: scheme.muted, fontSize: AppType.body),
          ),
          const SizedBox(height: AppSpacing.md),
          Divider(color: scheme.border, height: 1),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Daily Safe Spend', style: TextStyle(color: scheme.muted, fontSize: AppType.caption)),
                    const SizedBox(height: 2),
                    Text(
                      '$currency${money.format(pacing.dailySafeToSpend)} / day',
                      style: TextStyle(
                        color: scheme.ink,
                        fontWeight: FontWeight.bold,
                        fontSize: AppType.body,
                        fontFeatures: AppType.tabular,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Projected Month-End', style: TextStyle(color: scheme.muted, fontSize: AppType.caption)),
                    const SizedBox(height: 2),
                    Text(
                      '$currency${money.format(pacing.projectedMonthEnd)}',
                      style: TextStyle(
                        color: pacing.isOverBudget ? scheme.error : scheme.success,
                        fontWeight: FontWeight.bold,
                        fontSize: AppType.body,
                        fontFeatures: AppType.tabular,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aiRecommendationCard(BuildContext context, AiRecommendation rec, String currency) {
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);
    IconData icon;
    Color color;

    switch (rec.type) {
      case AiInsightType.criticalWarning:
        icon = Icons.warning_amber_rounded;
        color = scheme.error;
        break;
      case AiInsightType.budgetPacing:
        icon = Icons.speed_rounded;
        color = scheme.warning;
        break;
      case AiInsightType.smartSavings:
        icon = Icons.lightbulb_outline_rounded;
        color = scheme.primary;
        break;
      case AiInsightType.trendAlert:
        icon = Icons.trending_up_rounded;
        color = rec.relatedCategory != null
            ? scheme.categoryColors[rec.relatedCategory!.index]
            : scheme.warning;
        break;
      case AiInsightType.positiveMilestone:
        icon = Icons.verified_outlined;
        color = scheme.success;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: color.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    rec.title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(rec.message, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAiChatModal(BuildContext context, List<Expense> expenses, AppSettings settings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _AiAssistantSheet(expenses: expenses, settings: settings),
    );
  }

  Widget _comparisonCard(
    double thisMonth,
    double lastMonth,
    double change,
    String currency,
  ) {
    final isUp = change > 0;
    return Builder(
      builder: (context) {
        final scheme = SchemeTheme.of(context);
        final trendColor = isUp ? scheme.error : scheme.success;
        return Container(
          padding: const EdgeInsets.all(AppSpacing.xl),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: scheme.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'vs Last Month',
                style: TextStyle(color: scheme.muted, fontSize: AppType.label),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Icon(
                    isUp ? Icons.trending_up : Icons.trending_down,
                    color: trendColor,
                    size: AppType.title,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${isUp ? '+' : ''}${change.toStringAsFixed(1)}%',
                        style: TextStyle(
                          color: trendColor,
                          fontSize: AppType.display,
                          fontWeight: FontWeight.bold,
                          fontFeatures: AppType.tabular,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: trendColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: trendColor.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Text(
                      isUp ? 'Spending up' : 'Spending down',
                      style: TextStyle(
                        color: trendColor,
                        fontSize: AppType.caption,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Text(
                    'This month: ',
                    style: TextStyle(color: scheme.muted),
                  ),
                  MoneyText(
                    thisMonth,
                    currency: currency,
                    size: AppType.body,
                    color: scheme.ink,
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    'Last month: ',
                    style: TextStyle(color: scheme.muted),
                  ),
                  MoneyText(
                    lastMonth,
                    currency: currency,
                    size: AppType.body,
                    color: scheme.muted,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _infoCard(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: AppType.title),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.labelMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recurringTile(
    BuildContext context,
    Map<String, dynamic> r,
    String currency,
  ) {
    final scheme = SchemeTheme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.border),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: scheme.primary.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.autorenew,
            color: scheme.primary,
            size: 20,
          ),
        ),
        title: Text(r['name']),
        subtitle: Text(
          '~${r['frequency']} - Monthly ~$currency${NumberFormat('#,##0').format(r['amount'])}',
        ),
        trailing: Icon(
          Icons.repeat,
          size: AppType.headline,
          color: scheme.muted,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _detectRecurring(List expenses) {
    final titleCount = <String, int>{};
    final titleAmount = <String, double>{};
    for (final e in expenses) {
      final key = e.title.toLowerCase().trim();
      titleCount[key] = (titleCount[key] ?? 0) + 1;
      titleAmount[key] = (titleAmount[key] ?? 0) + e.amount;
    }
    final recurring = <Map<String, dynamic>>[];
    titleCount.forEach((key, count) {
      if (count >= 2) {
        final avg = titleAmount[key]! / count;
        String freq = count >= 12
            ? 'Monthly'
            : count >= 4
            ? 'Quarterly'
            : 'Occasional';
        recurring.add({
          'name': _capitalize(key),
          'amount': avg,
          'count': count,
          'frequency': freq,
        });
      }
    });
    recurring.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));
    return recurring.take(5).toList();
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

class _AiAssistantSheet extends StatefulWidget {
  final List<Expense> expenses;
  final AppSettings settings;

  const _AiAssistantSheet({
    required this.expenses,
    required this.settings,
  });

  @override
  State<_AiAssistantSheet> createState() => _AiAssistantSheetState();
}

class _AiAssistantSheetState extends State<_AiAssistantSheet> {
  final _controller = TextEditingController();
  String? _answer;
  bool _isProcessing = false;

  void _ask(String prompt) {
    setState(() {
      _isProcessing = true;
      _controller.text = prompt;
    });
    HapticFeedback.selectionClick();

    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final reply = AiFinancialAdvisorService.answerSpendingQuery(
        query: prompt,
        expenses: widget.expenses,
        settings: widget.settings,
      );
      setState(() {
        _answer = reply;
        _isProcessing = false;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);
    final quickPrompts = [
      'What was my highest expense?',
      'How much did I spend on food?',
      'Total spending?',
      'Shopping expenses?',
      'Bills breakdown',
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            AppSpacing.lg,
        left: AppSpacing.lg,
        right: AppSpacing.lg,
        top: AppSpacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.auto_awesome, color: scheme.primary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Financial Advisor',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '100% Offline • Instant Heuristic Insights',
                    style: theme.textTheme.labelSmall?.copyWith(color: scheme.primary),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: quickPrompts
                  .map(
                    (p) => Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        avatar: Icon(Icons.bolt, size: 14, color: scheme.primary),
                        label: Text(p, style: const TextStyle(fontSize: AppType.caption)),
                        onPressed: () => _ask(p),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (_answer != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: scheme.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, size: 14, color: scheme.primary),
                      const SizedBox(width: 6),
                      Text(
                        'Advisor Answer',
                        style: TextStyle(
                          fontSize: AppType.caption,
                          fontWeight: FontWeight.bold,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _answer!,
                    style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: InputDecoration(
                    hintText: 'Ask about your spending...',
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onSubmitted: (val) {
                    if (val.trim().isNotEmpty) _ask(val.trim());
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                constraints:
                    const BoxConstraints.tightFor(width: 48, height: 48),
                style: IconButton.styleFrom(
                  backgroundColor: scheme.ctaFill,
                  foregroundColor: scheme.ctaText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _isProcessing
                    ? null
                    : () {
                        if (_controller.text.trim().isNotEmpty) {
                          _ask(_controller.text.trim());
                        }
                      },
                icon: const Icon(Icons.arrow_upward, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MerchantAlertsSection extends StatefulWidget {
  const _MerchantAlertsSection({
    required this.expenses,
    required this.currency,
    required this.monthlyBudget,
    required this.startingDayOfMonth,
  });

  final List<Expense> expenses;
  final String currency;
  final double monthlyBudget;
  final int startingDayOfMonth;

  @override
  State<_MerchantAlertsSection> createState() => _MerchantAlertsSectionState();
}

class _MerchantAlertsSectionState extends State<_MerchantAlertsSection> {
  List<Expense>? _source;
  double? _budget;
  int? _startingDay;
  List<MerchantAnomaly> _anomalies = const [];

  void _syncAnomalies() {
    if (identical(_source, widget.expenses) &&
        _budget == widget.monthlyBudget &&
        _startingDay == widget.startingDayOfMonth) {
      return;
    }
    _source = widget.expenses;
    _budget = widget.monthlyBudget;
    _startingDay = widget.startingDayOfMonth;
    _anomalies = MerchantAnomalyService.detect(
      expenses: widget.expenses,
      monthlyBudget: widget.monthlyBudget,
      startingDayOfMonth: widget.startingDayOfMonth,
    );
  }

  @override
  Widget build(BuildContext context) {
    _syncAnomalies();
    if (_anomalies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Merchant Alerts', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.xs),
        Text(
          'These merchants are running well ahead of their usual pace.',
          style: Theme.of(context).textTheme.labelMedium,
        ),
        const SizedBox(height: AppSpacing.sm),
        ..._anomalies.map(_alertTile),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }

  Widget _alertTile(MerchantAnomaly anomaly) {
    final isCritical = anomaly.severity == 'critical';
    final money = NumberFormat('#,##0');
    return Builder(
      builder: (context) {
        final scheme = SchemeTheme.of(context);
        final color = isCritical ? scheme.error : scheme.warning;
        return Container(
          margin: const EdgeInsets.only(bottom: AppSpacing.sm),
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: scheme.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isCritical
                      ? Icons.warning_amber_rounded
                      : Icons.trending_up_rounded,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            anomaly.displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: color.withValues(alpha: 0.4),
                            ),
                          ),
                          child: Text(
                            isCritical ? 'Critical' : 'Elevated',
                            style: TextStyle(
                              fontSize: AppType.caption,
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.currency}${money.format(anomaly.currentAmount)}'
                      ' vs ${widget.currency}${money.format(anomaly.baselineAmount)}'
                      ' expected by now',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
