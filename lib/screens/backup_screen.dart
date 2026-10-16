import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/app_settings_provider.dart';
import '../providers/custom_category_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/daily_goal_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/group_expense_provider.dart';
import '../providers/group_provider.dart';
import '../providers/income_provider.dart';
import '../providers/lending_provider.dart';
import '../providers/merchant_memory_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/recurring_expense_provider.dart';
import '../providers/service_provider.dart';
import '../providers/spending_goal_provider.dart';
import '../services/backup_service.dart';
import '../utils/design.dart';
import '../utils/theme.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _shareButtonKey = GlobalKey();
  BackupSnapshot? _snapshot;
  BackupPreview? _preview;
  String? _error;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final scheme = SchemeTheme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg + MediaQuery.paddingOf(context).bottom,
        ),
        children: [
          Text(
            'Keep an offline copy of your SpendSmart data. Backups stay on your device until you choose to share them.',
            style: TextStyle(color: scheme.muted),
          ),
          const SizedBox(height: AppSpacing.lg),
          _actionTile(
            context,
            key: _shareButtonKey,
            icon: Icons.ios_share_outlined,
            title: 'Create and share backup',
            subtitle: 'Write a private JSON backup to temporary storage',
            onTap: _busy ? null : _share,
          ),
          _actionTile(
            context,
            icon: Icons.file_open_outlined,
            title: 'Select backup to restore',
            subtitle: 'Preview records before merging them into this device',
            onTap: _busy ? null : _select,
          ),
          if (_busy) ...[
            const SizedBox(height: AppSpacing.md),
            const Center(child: CircularProgressIndicator()),
          ],
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.md),
            _message(_error!, scheme.error),
          ],
          if (_snapshot != null && _preview != null) ...[
            const SizedBox(height: AppSpacing.lg),
            _previewCard(context, _preview!),
          ],
        ],
      ),
    );
  }

  Widget _actionTile(
    BuildContext context, {
    Key? key,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    final scheme = SchemeTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Container(
        key: key,
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: AppRadius.mdAll,
          border: Border.all(color: scheme.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            leading: Icon(icon, color: scheme.primary),
            title: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(subtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: onTap,
          ),
        ),
      ),
    );
  }

  Widget _message(String message, Color color) => Container(
    padding: const EdgeInsets.all(AppSpacing.md),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.1),
      borderRadius: AppRadius.mdAll,
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Text(message, style: TextStyle(color: color)),
  );

  Widget _previewCard(BuildContext context, BackupPreview preview) {
    final scheme = SchemeTheme.of(context);
    final labels = <String, String>{
      'expenses': 'Expenses',
      'merchants': 'Merchant memory',
      'budgets': 'Budgets',
      'lendings': 'Lendings',
      'incomes': 'Income',
      'recurring_expenses': 'Recurring expenses',
      'split_groups': 'Split groups',
      'group_expenses': 'Group expenses',
      'custom_categories': 'Custom categories',
    };
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: AppRadius.mdAll,
        border: Border.all(color: scheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Restore preview',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${preview.totalNewRecords} new record(s) will be merged. '
            '${preview.totalSkippedRecords} existing record(s) will be kept.',
            style: TextStyle(color: scheme.muted),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final entry in labels.entries)
            _countRow(
              context,
              entry.value,
              preview.newRecords[entry.key] ?? 0,
              preview.skippedRecords[entry.key] ?? 0,
            ),
          _countRow(
            context,
            'Settings, goals and notifications',
            preview.preferences,
            0,
            freshLabel: 'included',
          ),
          if (preview.preferenceKeys.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Included: ${preview.preferenceKeys.map(_preferenceLabel).join(', ')}',
              style: TextStyle(color: scheme.muted, fontSize: AppType.caption),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Text(
            'Merge mode never overwrites an existing Hive record. Settings are restored as single values.',
            style: TextStyle(color: scheme.muted, fontSize: AppType.caption),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.restore),
              label: const Text('Review and restore'),
              onPressed: _busy ? null : _confirmRestore,
            ),
          ),
        ],
      ),
    );
  }

  Widget _countRow(
    BuildContext context,
    String label,
    int fresh,
    int skipped, {
    String freshLabel = 'new',
    String skippedLabel = 'kept',
  }) {
    final scheme = SchemeTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text('$fresh $freshLabel', style: TextStyle(color: scheme.success)),
          if (skipped > 0) ...[
            const SizedBox(width: 8),
            Text(
              '$skipped $skippedLabel',
              style: TextStyle(color: scheme.muted),
            ),
          ],
        ],
      ),
    );
  }

  String _preferenceLabel(String key) => switch (key) {
    'currency' => 'currency',
    'monthlyBudget' => 'monthly budget',
    'monthlyIncome' => 'monthly income',
    'theme' => 'theme',
    'onboardingDone' => 'onboarding',
    'startingDayOfMonth' => 'cycle start day',
    'goal_monthly_limit' => 'spending goal',
    'goal_enabled' => 'goal status',
    'daily_goals' => 'daily goals',
    'app_notifications_v1' => 'notifications',
    _ => key,
  };

  Future<void> _share() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final renderObject = _shareButtonKey.currentContext?.findRenderObject();
      final renderBox = renderObject is RenderBox ? renderObject : null;
      final origin = renderBox == null
          ? const Rect.fromLTWH(0, 0, 1, 1)
          : renderBox.localToGlobal(Offset.zero) & renderBox.size;
      await ref.read(backupServiceProvider).shareBackup(
        sharePositionOrigin: origin,
      );
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not create or share the backup.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select() async {
    setState(() {
      _busy = true;
      _error = null;
      _snapshot = null;
      _preview = null;
    });
    try {
      final json = await BackupService.pickBackupJson();
      if (json == null) return;
      final snapshot = BackupService.parse(json);
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        _preview = ref.read(backupServiceProvider).preview(snapshot);
      });
    } on BackupFormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'The selected backup could not be read.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirmRestore() async {
    final snapshot = _snapshot;
    if (snapshot == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restore backup?'),
        content: const Text(
          'This will merge new records and restore the backed-up settings. Existing records with the same key will be kept. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Restore'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
    });
    // Captured up front: the user may leave this screen mid-restore, and the
    // providers must still be refreshed afterwards.
    final container = ProviderScope.containerOf(context, listen: false);
    var restoreStarted = false;
    try {
      restoreStarted = true;
      final result = await ref.read(backupServiceProvider).restore(snapshot);
      if (!mounted) return;
      setState(() {
        _snapshot = null;
        _preview = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Restored ${result.totalInserted} new record(s).'),
        ),
      );
    } on BackupFormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Restore failed. No success was recorded; some writes may need review.',
        );
      }
    } finally {
      if (restoreStarted) _invalidateDataProviders(container);
      if (mounted) setState(() => _busy = false);
    }
  }

  void _invalidateDataProviders(ProviderContainer container) {
    container.invalidate(appSettingsProvider);
    container.invalidate(expenseProvider);
    container.invalidate(budgetProvider);
    container.invalidate(incomeProvider);
    container.invalidate(lendingProvider);
    container.invalidate(recurringExpenseProvider);
    container.invalidate(splitGroupProvider);
    container.invalidate(groupExpenseProvider);
    container.invalidate(merchantNotifierProvider);
    container.invalidate(dailyGoalProvider);
    container.invalidate(spendingGoalProvider);
    container.invalidate(notificationProvider);
    container.invalidate(customCategoryProvider);
  }
}
