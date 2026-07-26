import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/app_settings_provider.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../services/ai_spending_analysis_service.dart';
import '../services/merchant_anomaly_service.dart';
import '../utils/constants.dart';
import '../utils/date_extension.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Kept as the raw provider instance so `_MerchantAlertsSection` can memoize
    // its scan with `identical()`; the filtered copy below is a new list on
    // every build and would defeat that.
    final allExpenses = ref.watch(expenseProvider);
    final expenses = allExpenses.where((e) => !e.isUncategorized).toList();
    final budgets = ref.watch(budgetProvider);
    final settings = ref.watch(appSettingsProvider);
    final now = DateTime.now();

    final thisMonth = expenses
        .where(
          (e) => e.date.isTargetCustomMonth(
            now.month,
            now.year,
            settings.startingDayOfMonth,
          ),
        )
        .toList();

    final lmDate = DateTime(now.year, now.month - 1);
    final lastMonth = expenses
        .where(
          (e) => e.date.isTargetCustomMonth(
            lmDate.month,
            lmDate.year,
            settings.startingDayOfMonth,
          ),
        )
        .toList();

    final thisTotal = thisMonth.fold(0.0, (a, b) => a + b.amount);
    final lastTotal = lastMonth.fold(0.0, (a, b) => a + b.amount);
    final change = lastTotal > 0
        ? ((thisTotal - lastTotal) / lastTotal * 100)
        : 0.0;

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

    // Insights list
    final insights = _generateInsights(
      thisTotal,
      lastTotal,
      change,
      catSums,
      budgets,
      settings,
      topCat,
      recurring,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Spending Insights',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: expenses.isEmpty
          ? const Center(
              child: Text(
                'Add some expenses to see insights!',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Month comparison card
                _comparisonCard(
                  thisTotal,
                  lastTotal,
                  change,
                  settings.currency,
                ),
                const SizedBox(height: 16),

                _AiReviewCard(
                  expenses: expenses,
                  currency: settings.currency,
                  monthlyBudget: settings.monthlyBudget,
                  startingDayOfMonth: settings.startingDayOfMonth,
                  workerUrl: settings.aiWorkerUrl,
                  proxyToken: settings.aiProxyToken,
                ),
                const SizedBox(height: 16),

                // On-device merchant spikes. Renders nothing when there are no
                // anomalies, which is the common case.
                _MerchantAlertsSection(
                  expenses: allExpenses,
                  currency: settings.currency,
                  monthlyBudget: settings.monthlyBudget,
                  startingDayOfMonth: settings.startingDayOfMonth,
                ),

                // Top spending category
                if (topCat != null)
                  _infoCard(
                    icon: topCat.key.icon,
                    color: topCat.key.color,
                    title: 'Top Category: ${topCat.key.displayName}',
                    subtitle:
                        '${settings.currency}${NumberFormat('#,##0').format(topCat.value)} this month'
                        ' (${thisTotal > 0 ? (topCat.value / thisTotal * 100).toStringAsFixed(0) : 0}% of spending)',
                  ),
                const SizedBox(height: 12),

                // Recurring subscriptions
                if (recurring.isNotEmpty) ...[
                  const Text(
                    'Recurring Expenses Detected',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  ...recurring.map((r) => _recurringTile(r, settings.currency)),
                  const SizedBox(height: 16),
                ],

                // Smart Tips
                const Text(
                  'Smart Tips',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                ...insights.map((i) => _tipCard(i)),
              ],
            ),
    );
  }

  Widget _comparisonCard(
    double thisMonth,
    double lastMonth,
    double change,
    String currency,
  ) {
    final isUp = change > 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isUp
              ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
              : [const Color(0xFF059669), const Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'vs Last Month',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isUp ? Icons.trending_up : Icons.trending_down,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                '${isUp ? '+' : ''}${change.toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This month: $currency${NumberFormat('#,##0').format(thisMonth)}',
            style: const TextStyle(color: Colors.white70),
          ),
          Text(
            'Last month: $currency${NumberFormat('#,##0').format(lastMonth)}',
            style: const TextStyle(color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
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
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _recurringTile(Map<String, dynamic> r, String currency) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.purple.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.autorenew, color: Colors.purple, size: 20),
        ),
        title: Text(
          r['name'],
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          '~${r['frequency']} - Monthly ~$currency${NumberFormat('#,##0').format(r['amount'])}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        trailing: const Icon(Icons.repeat, size: 16, color: Colors.purple),
      ),
    );
  }

  Widget _tipCard(Map<String, dynamic> tip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (tip['color'] as Color).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                tip['icon'] as IconData,
                color: tip['color'] as Color,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip['title'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tip['body'],
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  List<Map<String, dynamic>> _generateInsights(
    double thisTotal,
    double lastTotal,
    double change,
    Map<Category, double> catSums,
    List budgets,
    dynamic settings,
    MapEntry<Category, double>? topCat,
    List recurring,
  ) {
    final tips = <Map<String, dynamic>>[];

    if (change > 20) {
      tips.add({
        'icon': Icons.warning_amber_rounded,
        'color': Colors.orange,
        'title': 'Spending Increased Significantly',
        'body':
            'Your spending is up ${change.toStringAsFixed(0)}% compared to last month. Consider reviewing your discretionary expenses.',
      });
    } else if (change < -10) {
      tips.add({
        'icon': Icons.celebration,
        'color': Colors.green,
        'title': 'Great Job Saving!',
        'body':
            'You spent ${(-change).toStringAsFixed(0)}% less than last month. Keep it up!',
      });
    }

    // Budget warnings
    for (final entry in catSums.entries) {
      final matchingBudgets = budgets.where((b) => b.category == entry.key);
      if (matchingBudgets.isEmpty) continue;
      final budget = matchingBudgets.first;
      if (budget.monthlyLimit > 0) {
        final pct = entry.value / budget.monthlyLimit;
        if (pct > 0.9) {
          tips.add({
            'icon': Icons.account_balance_wallet,
            'color': Colors.red,
            'title': '${entry.key.displayName} Budget Almost Exhausted',
            'body':
                'You\'ve used ${(pct * 100).toStringAsFixed(0)}% of your ${entry.key.displayName} budget. Only ${settings.currency}${(budget.monthlyLimit - entry.value).toStringAsFixed(0)} remaining.',
          });
        }
      }
    }

    if (topCat != null && thisTotal > 0 && (topCat.value / thisTotal) > 0.4) {
      tips.add({
        'icon': topCat.key.icon,
        'color': topCat.key.color,
        'title': '${topCat.key.displayName} Dominates Your Spending',
        'body':
            '${(topCat.value / thisTotal * 100).toStringAsFixed(0)}% of your budget goes to ${topCat.key.displayName}. Consider setting a specific budget cap.',
      });
    }

    if (settings.monthlyBudget > 0) {
      final savingsRate =
          (settings.monthlyBudget - thisTotal) / settings.monthlyBudget;
      if (savingsRate > 0.3) {
        tips.add({
          'icon': Icons.savings,
          'color': Colors.green,
          'title': 'Strong Budget Management',
          'body':
              'You have ${(savingsRate * 100).toStringAsFixed(0)}% of your budget left this month. Awesome job!',
        });
      } else if (savingsRate < 0.1 && savingsRate > 0) {
        tips.add({
          'icon': Icons.savings,
          'color': Colors.orange,
          'title': 'Approaching Budget Limit',
          'body':
              'You have less than 10% of your total budget remaining. Consider reducing spending on non-essentials.',
        });
      }
    }

    if (recurring.isNotEmpty) {
      final recTotal = recurring.fold(
        0.0,
        (a, b) => a + (b['amount'] as double),
      );
      tips.add({
        'icon': Icons.autorenew,
        'color': Colors.purple,
        'title': 'Recurring Charges',
        'body':
            'You have ${recurring.length} recurring expenses totalling approx. ${settings.currency}${NumberFormat('#,##0').format(recTotal)}/month. Review if all subscriptions are still being used.',
      });
    }

    if (tips.isEmpty) {
      tips.add({
        'icon': Icons.thumb_up,
        'color': Colors.blue,
        'title': 'Looking Good!',
        'body':
            'Your spending looks healthy this month. Keep tracking to get more personalized insights.',
      });
    }

    return tips;
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
}

/// Merchant-level spikes detected on device — no network call.
///
/// Stateful purely to memoize [MerchantAnomalyService.detect], which is a
/// multi-pass scan over every expense. This screen rebuilds often and already
/// recomputes too much in `build()`.
class _MerchantAlertsSection extends StatefulWidget {
  const _MerchantAlertsSection({
    required this.expenses,
    required this.currency,
    required this.monthlyBudget,
    required this.startingDayOfMonth,
  });

  /// Raw `expenseProvider` list. Must be the provider's own instance: the memo
  /// below compares it with `identical()`.
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

  /// Rescans only when the expense list itself changes, or when a setting the
  /// math depends on does. Same guard as `_syncMerchantIndex` in
  /// `add_expense_screen.dart`.
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
    // No header, no empty-state card: most months have nothing to say here.
    if (_anomalies.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Merchant Alerts',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 4),
        Text(
          'These merchants are running well ahead of their usual pace.',
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
        const SizedBox(height: 8),
        ..._anomalies.map(_alertTile),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _alertTile(MerchantAnomaly anomaly) {
    final color = anomaly.severity == 'critical'
        ? AppColors.error
        : AppColors.warning;
    final money = NumberFormat('#,##0');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Statement titles can be long, e.g. 'UPI/SWIGGY/9876543210'.
                Text(
                  anomaly.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${widget.currency}${money.format(anomaly.currentAmount)}'
                  ' vs ${widget.currency}${money.format(anomaly.baselineAmount)}'
                  ' expected by now',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AiReviewCard extends StatefulWidget {
  const _AiReviewCard({
    required this.expenses,
    required this.currency,
    required this.monthlyBudget,
    required this.startingDayOfMonth,
    required this.workerUrl,
    required this.proxyToken,
  });

  final List<Expense> expenses;
  final String currency;
  final double monthlyBudget;
  final int startingDayOfMonth;
  final String workerUrl;
  final String proxyToken;

  @override
  State<_AiReviewCard> createState() => _AiReviewCardState();
}

class _AiReviewCardState extends State<_AiReviewCard> {
  AiSpendingAnalysis? _analysis;
  bool _loading = false;
  bool _failed = false;
  bool _hasSufficientHistory = false;

  Future<void> _analyze() async {
    final endpoint = Uri.tryParse(widget.workerUrl);
    if (endpoint == null) {
      setState(() => _failed = true);
      return;
    }
    final request = AiSpendingAnalysisService.buildRequest(
      expenses: widget.expenses,
      currency: widget.currency,
      monthlyBudget: widget.monthlyBudget,
      startingDayOfMonth: widget.startingDayOfMonth,
    );
    final history = request['history']! as List<dynamic>;
    final hasSufficientHistory = history.every(
      (month) => ((month as Map<String, dynamic>)['total'] as num) > 0,
    );
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final analysis = await AiSpendingAnalysisService.analyze(
        endpoint: endpoint,
        proxyToken: widget.proxyToken,
        request: request,
      );
      if (mounted) {
        setState(() {
          _analysis = analysis;
          _hasSufficientHistory = hasSufficientHistory;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured =
        widget.workerUrl.isNotEmpty && widget.proxyToken.isNotEmpty;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: colors.secondary),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'AI spending review',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              configured
                  ? 'Sends category totals and your budget only. Nothing is saved automatically.'
                  : 'Configure your Cloudflare Worker in Settings to enable private AI analysis.',
              style: TextStyle(
                color: Theme.of(context).hintColor,
                fontSize: 12,
              ),
            ),
            if (configured) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _loading ? null : _analyze,
                  icon: _loading
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_awesome),
                  label: Text(
                    _analysis == null ? 'Analyze spending' : 'Refresh analysis',
                  ),
                ),
              ),
            ],
            if (_failed) ...[
              const SizedBox(height: 12),
              const Text(
                'AI analysis is unavailable. Check the Worker URL and proxy token, then try again.',
                style: TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
            if (_analysis != null) ...[
              const SizedBox(height: 16),
              Text(_analysis!.summary, style: const TextStyle(height: 1.35)),
              const SizedBox(height: 12),
              _forecast(_analysis!.forecast),
              const SizedBox(height: 16),
              const Text(
                'Category comparison',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (!_hasSufficientHistory)
                const Text(
                  'Track spending for three completed months to compare category patterns.',
                  style: TextStyle(fontSize: 12),
                )
              else if (_analysis!.anomalies.isEmpty)
                const Text(
                  'No categories are unusually high at this point in the month.',
                  style: TextStyle(fontSize: 12),
                )
              else
                ..._analysis!.anomalies.map(_anomaly),
              const SizedBox(height: 8),
              ..._analysis!.insights.map(_insight),
            ],
          ],
        ),
      ),
    );
  }

  Widget _insight(AiSpendingInsight insight) {
    final color = switch (insight.tone) {
      'positive' => Colors.green,
      'warning' => Colors.orange,
      _ => Colors.blue,
    };
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${insight.title}: ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  TextSpan(text: insight.detail),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _forecast(AiSpendingForecast forecast) {
    final color = switch (forecast.status) {
      'withinBudget' => AppColors.success,
      'atRisk' => AppColors.warning,
      'overBudget' => AppColors.error,
      _ => AppColors.mutedLight,
    };
    final label = switch (forecast.status) {
      'withinBudget' => 'Projected within budget',
      'atRisk' => 'Projected close to budget',
      'overBudget' => 'Projected over budget',
      _ =>
        forecast.projectedSpend == null
            ? 'Forecast needs more current-month activity'
            : 'Projected spend (no budget set)',
    };
    final amount = forecast.projectedSpend == null
        ? null
        : '${widget.currency}${NumberFormat('#,##0').format(forecast.projectedSpend)}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.trending_up_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (amount != null)
                  Text(amount, style: TextStyle(color: color)),
                Text(
                  forecast.confidence == 'unavailable'
                      ? 'Add expenses on at least three days for a forecast.'
                      : '${forecast.confidence[0].toUpperCase()}${forecast.confidence.substring(1)} confidence',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _anomaly(AiSpendingAnomaly anomaly) {
    final color = anomaly.severity == 'critical'
        ? AppColors.error
        : AppColors.warning;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${anomaly.category}: ${widget.currency}${NumberFormat('#,##0').format(anomaly.currentAmount)} so far, compared with ${widget.currency}${NumberFormat('#,##0').format(anomaly.baselineAmount)} expected at this point.',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
