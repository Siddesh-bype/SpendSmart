import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/merchant_memory_provider.dart';
import '../providers/service_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/category_classifier.dart';
import '../services/ai_financial_advisor_service.dart';
import '../utils/constants.dart';
import '../utils/design.dart';

class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  bool _isAnalyzing = false;

  @override
  Widget build(BuildContext context) {
    final pending = ref
        .watch(expenseProvider)
        .where((e) => e.isUncategorized)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Pending Categorization',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (pending.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                onPressed: _isAnalyzing ? null : () => _runAiAutoCategorize(context, pending),
                icon: _isAnalyzing
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.auto_awesome, size: 16, color: AppColors.secondary),
                label: const Text(
                  'Auto-Categorize',
                  style: TextStyle(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                    fontSize: AppType.label,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: pending.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: AppColors.success,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'All caught up!',
                    style: TextStyle(fontSize: AppType.title, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'No pending transactions to categorize.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: AppColors.warning,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${pending.length} transaction${pending.length > 1 ? 's' : ''} need${pending.length == 1 ? 's' : ''} categorization. Tap "Auto-Categorize" or select manually.',
                                style: const TextStyle(
                                  color: AppColors.warning,
                                  fontSize: AppType.label,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: pending.length,
                    itemBuilder: (_, i) => _PendingTile(
                      key: ValueKey(pending[i].id),
                      expense: pending[i],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _runAiAutoCategorize(BuildContext context, List<Expense> pending) async {
    setState(() => _isAnalyzing = true);
    HapticFeedback.mediumImpact();

    try {
      final storage = ref.read(storageServiceProvider);
      final suggestions = AiFinancialAdvisorService.categorizePendingExpenses(
        expenses: pending,
        storageService: storage,
      );

      final confidentSuggestions = suggestions.where(
        (s) => (s.confidence == AiConfidence.high || s.confidence == AiConfidence.medium) && s.category != Category.other,
      ).toList();

      if (!mounted) return;
      setState(() => _isAnalyzing = false);

      if (confidentSuggestions.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No confident category matches found for remaining merchants. Please assign manually.'),
          ),
        );
        return;
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (sheetContext) => _AiBatchCategorizeSheet(
          suggestions: confidentSuggestions,
          onApplyAll: () async {
            Navigator.pop(sheetContext);
            final messenger = ScaffoldMessenger.of(context);
            final expensesNotifier = ref.read(expenseProvider.notifier);
            final merchantsNotifier = ref.read(merchantNotifierProvider.notifier);

            int applied = 0;
            for (final s in confidentSuggestions) {
              try {
                await expensesNotifier.categorizeExpense(s.expenseId, s.category);
                await merchantsNotifier.correctMerchant(s.merchant, s.category);
                applied++;
              } catch (_) {}
            }

            messenger.showSnackBar(
              SnackBar(
                content: Text('Successfully auto-categorized $applied transaction${applied == 1 ? '' : 's'}! ✨'),
                backgroundColor: AppColors.success,
              ),
            );
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Auto-categorization failed: $e')),
        );
      }
    }
  }
}

class _AiBatchCategorizeSheet extends StatelessWidget {
  final List<AiCategorySuggestion> suggestions;
  final VoidCallback onApplyAll;

  const _AiBatchCategorizeSheet({
    required this.suggestions,
    required this.onApplyAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final highConfidenceCount = suggestions.where((s) => s.confidence == AiConfidence.high).length;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                  color: AppColors.secondary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome, color: AppColors.secondary, size: 20),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('AI Categorization Results', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    Text(
                      '$highConfidenceCount high confidence, ${suggestions.length - highConfidenceCount} moderate match',
                      style: theme.textTheme.labelMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(),
          Expanded(
            child: ListView.separated(
              itemCount: suggestions.length,
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemBuilder: (ctx, idx) {
                final s = suggestions[idx];
                final isHigh = s.confidence == AiConfidence.high;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: s.category.color.withValues(alpha: 0.15),
                    child: Icon(s.category.icon, color: s.category.color, size: 18),
                  ),
                  title: Text(s.merchant, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(s.rationale, style: theme.textTheme.labelSmall),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isHigh ? AppColors.success.withValues(alpha: 0.12) : AppColors.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isHigh ? AppColors.success.withValues(alpha: 0.3) : AppColors.warning.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      s.category.displayName,
                      style: TextStyle(
                        fontSize: AppType.caption,
                        fontWeight: FontWeight.bold,
                        color: isHigh ? AppColors.success : AppColors.warning,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: onApplyAll,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: Text('Apply All (${suggestions.length} Transactions)'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingTile extends ConsumerWidget {
  final Expense expense;
  const _PendingTile({super.key, required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(appSettingsProvider).currency;

    // Run instant heuristic check to see if AI has a high/medium suggestion for this item
    final storage = ref.watch(storageServiceProvider);
    final memoryCategory = storage.lookupMerchantCategory(expense.title);
    final quickClassify = CategoryClassifier.classify(expense.title);
    final suggestedCategory = memoryCategory ?? (quickClassify.category != Category.other ? quickClassify.category : null);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    expense.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: AppType.body,
                    ),
                  ),
                ),
                Text(
                  '$cur${NumberFormat('#,##0.##').format(expense.amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: AppType.headline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy  hh:mm a').format(expense.date),
              style: const TextStyle(color: Colors.grey, fontSize: AppType.caption),
            ),
            if (suggestedCategory != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: () => _categorize(context, ref, suggestedCategory),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.auto_awesome, size: 13, color: AppColors.secondary),
                      const SizedBox(width: 6),
                      Text(
                        'AI Suggestion: ${suggestedCategory.displayName}',
                        style: const TextStyle(
                          fontSize: AppType.caption,
                          fontWeight: FontWeight.bold,
                          color: AppColors.secondary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        '• Tap to apply',
                        style: TextStyle(fontSize: AppType.caption, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Select Category:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: AppType.label),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Category.values
                  .map(
                    (cat) => GestureDetector(
                      onTap: () => _categorize(context, ref, cat),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: cat.color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: cat.color.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cat.icon, size: 14, color: cat.color),
                            const SizedBox(width: 5),
                            Text(
                              cat.displayName,
                              style: TextStyle(
                                color: cat.color,
                                fontSize: AppType.caption,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _categorize(
    BuildContext context,
    WidgetRef ref,
    Category cat,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final expenses = ref.read(expenseProvider.notifier);
    final merchants = ref.read(merchantNotifierProvider.notifier);
    try {
      await expenses.categorizeExpense(expense.id, cat);
      await merchants.correctMerchant(expense.title, cat);
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text('Could not save ${expense.title}.')),
      );
      return;
    }
    messenger.showSnackBar(
      SnackBar(
        content: Text('${expense.title} -> ${cat.displayName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
