import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../providers/expense_provider.dart';
import '../providers/app_settings_provider.dart';
import '../providers/merchant_memory_provider.dart';
import '../models/expense.dart';
import '../models/category.dart';
import '../services/ai_categorization_service.dart';
import '../utils/constants.dart';

const _aiFailureMessage =
    'AI categorization is unavailable. '
    'Check the Worker URL and proxy token in Settings.';

String _plural(int count, String word) => '$count $word${count == 1 ? '' : 's'}';

class PendingScreen extends ConsumerStatefulWidget {
  const PendingScreen({super.key});

  @override
  ConsumerState<PendingScreen> createState() => _PendingScreenState();
}

class _PendingScreenState extends ConsumerState<PendingScreen> {
  bool _loading = false;

  /// Opt-in bulk categorization. Never runs on its own: one confirmation per
  /// tap, no stored consent flag.
  Future<void> _categorizeWithAi(List<Expense> pending) async {
    // Everything provider-shaped is read before the first await.
    final settings = ref.read(appSettingsProvider);
    final expenses = ref.read(expenseProvider.notifier);
    final merchants = ref.read(merchantNotifierProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    final workerUrl = Uri.tryParse(settings.aiWorkerUrl);
    final batches = AiCategorizationService.buildBatches(
      pending.map((e) => e.title),
    );
    if (workerUrl == null || batches.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text(_aiFailureMessage)));
      return;
    }
    final sentCount = batches.fold(0, (sum, batch) => sum + batch.length);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Categorize with AI?'),
        content: Text(
          '${_plural(sentCount, 'merchant name')} from your '
          '${_plural(pending.length, 'pending transaction')} will be sent to '
          'your own Cloudflare Worker, and on to OpenRouter, to suggest '
          'categories.\n\n'
          'No amounts, dates, or notes are sent.\n\n'
          'Only high-confidence suggestions are applied. Anything else stays '
          'here for you to categorize yourself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);

    // Keyed by lowercased merchant so one suggestion fans out to every pending
    // expense sharing that merchant -- buildBatches deduped them on the way out.
    final learned = <String, Category>{};
    var failed = false;
    try {
      final endpoint = AiCategorizationService.categorizeEndpoint(workerUrl);
      for (final batch in batches) {
        final suggestions = await AiCategorizationService.categorize(
          endpoint: endpoint,
          proxyToken: settings.aiProxyToken,
          merchants: batch,
        );
        for (final suggestion in suggestions) {
          if (suggestion.isHighConfidence) {
            learned[suggestion.merchant.toLowerCase()] = suggestion.category;
          }
        }
      }
    } catch (_) {
      // Batches already collected still get applied below.
      failed = true;
    }

    var applied = 0;
    try {
      for (final expense in pending) {
        final category = learned[expense.title.trim().toLowerCase()];
        if (category == null) continue;
        // Same pair as the per-tile chip: clear the flag, teach the store.
        await expenses.categorizeExpense(expense.id, category);
        await merchants.correctMerchant(expense.title, category);
        applied++;
      }
    } catch (_) {
      failed = true;
    }

    if (!mounted) return;
    setState(() => _loading = false);
    final remaining = pending.length - applied;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failed && applied == 0
              ? _aiFailureMessage
              : 'Categorized $applied of ${pending.length}'
                    '${remaining == 0 ? '.' : ' — $remaining still need review.'}'
                    '${failed ? ' The connection failed partway through.' : ''}',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider);
    final aiConfigured =
        settings.aiWorkerUrl.isNotEmpty && settings.aiProxyToken.isNotEmpty;
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
      ),
      body: pending.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.check_circle_outline,
                    size: 64,
                    color: Colors.green,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'All caught up!',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          color: Colors.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange.shade300),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.orange,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${pending.length} transaction${pending.length > 1 ? 's' : ''} need${pending.length == 1 ? 's' : ''} categorization. Swipe or tap to assign.',
                                style: const TextStyle(
                                  color: Colors.orange,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Hidden until the user has configured their own Worker.
                      if (aiConfigured) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _loading
                                ? null
                                : () => _categorizeWithAi(pending),
                            icon: _loading
                                ? const SizedBox(
                                    height: 16,
                                    width: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.auto_awesome),
                            label: const Text('Categorize with AI'),
                          ),
                        ),
                      ],
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
}

class _PendingTile extends ConsumerWidget {
  final Expense expense;
  const _PendingTile({super.key, required this.expense});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cur = ref.watch(appSettingsProvider).currency;
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
                      fontSize: 15,
                    ),
                  ),
                ),
                Text(
                  '$cur${NumberFormat('#,##0.##').format(expense.amount)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('MMM dd, yyyy  hh:mm a').format(expense.date),
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 12),
            const Text(
              'Select Category:',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Category.values
                  .map(
                    (cat) => GestureDetector(
                      onTap: () {
                        final expenses = ref.read(expenseProvider.notifier);
                        final merchants = ref.read(
                          merchantNotifierProvider.notifier,
                        );
                        // categorizeExpense also clears isUncategorized.
                        expenses.categorizeExpense(expense.id, cat);
                        merchants.correctMerchant(expense.title, cat);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${expense.title} -> ${cat.displayName}',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      },
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
                                fontSize: 12,
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
}
