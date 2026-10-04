import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_settings_provider.dart';
import '../providers/budget_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/group_expense_provider.dart';
import '../providers/group_provider.dart';
import '../providers/income_provider.dart';
import '../providers/lending_provider.dart';
import '../providers/merchant_memory_provider.dart';
import '../providers/recurring_expense_provider.dart';
import '../providers/service_provider.dart';
import '../services/csv_import_service.dart';
import '../services/export_service.dart';
import '../services/pdf_export_service.dart';
import '../utils/design.dart';
import '../utils/theme.dart';
import '../utils/validation.dart';
import 'pdf_import_screen.dart';
import 'insights_screen.dart';
import 'lending_screen.dart';
import 'spending_goals_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── App info card ──────────────────────────────────────────
          const _AppInfoCard(),
          const SizedBox(height: 24),

          _sectionTitle('Preferences'),
          _tile(
            icon: Icons.currency_rupee,
            title: 'Currency',
            subtitle: Text(settings.currency),
            onTap: () => _editCurrency(context, ref, settings.currency),
          ),
          _tile(
            icon: Icons.account_balance_wallet,
            title: 'Monthly Budget',
            subtitle: Text(
              '${settings.currency}${settings.monthlyBudget.toStringAsFixed(0)}',
            ),
            onTap: () => _editBudget(context, ref, settings.monthlyBudget),
          ),
          _tile(
            icon: Icons.calendar_month_outlined,
            title: 'Starting Day of Month',
            subtitle: Text(
              'Starts on the ${settings.startingDayOfMonth}${_ordinal(settings.startingDayOfMonth)}',
            ),
            onTap: () =>
                _editStartingDay(context, ref, settings.startingDayOfMonth),
          ),

          const SizedBox(height: 16),
          _sectionTitle('Appearance'),
          Builder(
            builder: (context) {
              final scheme = SchemeTheme.of(context);
              final themeMeta = switch (settings.theme) {
                'light' => (Icons.wb_sunny_outlined, 'Light'),
                'dark' => (Icons.nightlight_outlined, 'Dark'),
                _ => (Icons.brightness_auto, 'System'),
              };
              return _tile(
                icon: Icons.palette_outlined,
                title: 'Theme',
                subtitle: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(themeMeta.$1, size: 14, color: scheme.muted),
                    const SizedBox(width: 4),
                    Text(
                      themeMeta.$2,
                      style: TextStyle(
                        color: scheme.muted,
                        fontSize: AppType.caption,
                      ),
                    ),
                  ],
                ),
                onTap: () => _editTheme(context, ref, settings.theme),
              );
            },
          ),

          const SizedBox(height: 16),
          _sectionTitle('Planning'),
          _tile(
            icon: Icons.insights,
            title: 'Spending Insights',
            subtitle: const Text('Smart tips and spending analysis'),
            color: SchemeTheme.of(context).primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const InsightsScreen()),
            ),
          ),
          _tile(
            icon: Icons.track_changes_rounded,
            title: 'Spending Goals',
            subtitle: const Text('Set and track your monthly budget goal'),
            color: SchemeTheme.of(context).primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SpendingGoalsScreen()),
            ),
          ),
          _tile(
            icon: Icons.people_alt_outlined,
            title: 'Lend & Borrow',
            subtitle: const Text('Track money you gave or owe'),
            color: SchemeTheme.of(context).primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const LendingScreen()),
            ),
          ),

          const SizedBox(height: 16),
          _sectionTitle('Data & Import'),
          _tile(
            icon: Icons.picture_as_pdf,
            title: 'Import Bank Statement (PDF)',
            subtitle: const Text('Auto-import transactions from your bank PDF'),
            color: SchemeTheme.of(context).primary,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const PdfImportScreen()),
            ),
          ),
          _tile(
            icon: Icons.upload_file_rounded,
            title: 'Import CSV',
            subtitle: const Text(
              'Import expenses from a SpendSmart or custom CSV file',
            ),
            color: SchemeTheme.of(context).primary,
            onTap: () => _importCSV(context, ref),
          ),

          const SizedBox(height: 16),
          _sectionTitle('Export'),
          _tile(
            icon: Icons.picture_as_pdf,
            title: 'Export to PDF',
            subtitle: const Text('Professional expense report with charts'),
            color: SchemeTheme.of(context).muted,
            onTap: () => _exportPDF(context, ref, settings.currency),
          ),
          _tile(
            icon: Icons.table_chart,
            title: 'Export to CSV',
            subtitle: const Text('Save expenses as a spreadsheet'),
            color: SchemeTheme.of(context).muted,
            onTap: () => _exportCSV(context, ref),
          ),
          _tile(
            icon: Icons.share_rounded,
            title: 'Share CSV Report',
            subtitle: const Text('Send expense data via WhatsApp, email, etc.'),
            color: SchemeTheme.of(context).muted,
            onTap: () => _shareCSV(context, ref),
          ),

          // Safe-area padding replaces the old 160px FAB spacer.
          const SizedBox(height: 16),
          _sectionTitle('Danger Zone'),
          _dangerTile(
            icon: Icons.delete_forever_outlined,
            title: 'Erase all data',
            subtitle: const Text('Permanently delete all local data'),
            onTap: () => _confirmEraseAll(context, ref),
          ),
          SizedBox(height: 16 + MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) => Builder(
    builder: (context) {
      final scheme = SchemeTheme.of(context);
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: scheme.muted,
            fontWeight: FontWeight.bold,
            fontSize: AppType.label,
            letterSpacing: 1.2,
          ),
        ),
      );
    },
  );

  Widget _tile({
    required IconData icon,
    required String title,
    Widget? subtitle,
    VoidCallback? onTap,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Builder(
        builder: (context) {
          final scheme = SchemeTheme.of(context);
          final iconColor = color ?? scheme.primary;

          return Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(color: scheme.border),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.tint,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: scheme.ink,
                ),
              ),
              subtitle: subtitle != null
                  ? DefaultTextStyle(
                      style: TextStyle(
                        color: scheme.muted,
                        fontSize: AppType.caption,
                      ),
                      child: subtitle,
                    )
                  : null,
              trailing: onTap != null
                  ? Icon(Icons.chevron_right, color: scheme.muted)
                  : null,
              onTap: onTap,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Destructive twin of [_tile]: error-tinted outline plus error
  /// text AND icon, so the danger is never carried by color alone.
  Widget _dangerTile({
    required IconData icon,
    required String title,
    Widget? subtitle,
    VoidCallback? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Builder(
        builder: (context) {
          final scheme = SchemeTheme.of(context);
          return Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: AppRadius.mdAll,
              border: Border.all(
                color: scheme.error.withValues(alpha: 0.6),
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: scheme.error.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: scheme.error, size: 22),
                ),
                title: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.error,
                  ),
                ),
                subtitle: subtitle != null
                    ? DefaultTextStyle(
                        style: TextStyle(
                          color: scheme.muted,
                          fontSize: AppType.caption,
                        ),
                        child: subtitle,
                      )
                    : null,
                trailing: onTap != null
                    ? Icon(Icons.chevron_right, color: scheme.error)
                    : null,
                onTap: onTap,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.mdAll),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Confirm sheet for the wipe. Nothing is erased until "Erase everything"
  /// is tapped; Cancel stays the default-focused action.
  Future<void> _confirmEraseAll(BuildContext context, WidgetRef ref) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = SchemeTheme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: scheme.error,
                    size: 22,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Erase all data?',
                      style: Theme.of(sheetContext).textTheme.titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: scheme.error,
                          ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'This permanently deletes all expenses, budgets, income, '
                'lendings, recurring rules, split groups, group expenses and '
                'learned merchant data stored on this device. '
                'This cannot be undone.',
                style: Theme.of(sheetContext).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  autofocus: true,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: scheme.ctaFill,
                    foregroundColor: scheme.ctaText,
                  ),
                  onPressed: () => Navigator.pop(sheetContext, false),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: scheme.ctaText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: scheme.error,
                    foregroundColor: Theme.of(
                      sheetContext,
                    ).colorScheme.onError,
                  ),
                  onPressed: () => Navigator.pop(sheetContext, true),
                  child: const Text(
                    'Erase everything',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(storageServiceProvider).clearAllData();
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not erase data. $error'),
          backgroundColor: SchemeTheme.of(context).error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Boxes are empty now; rebuild every Hive-backed provider from them.
    ref.invalidate(expenseProvider);
    ref.invalidate(budgetProvider);
    ref.invalidate(incomeProvider);
    ref.invalidate(lendingProvider);
    ref.invalidate(recurringExpenseProvider);
    ref.invalidate(splitGroupProvider);
    ref.invalidate(groupExpenseProvider);
    ref.invalidate(merchantNotifierProvider);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All data erased')),
    );
  }

  Future<void> _importCSV(BuildContext context, WidgetRef ref) async {
    final memoryLookup = ref.read(storageServiceProvider).lookupMerchantCategory;
    CsvImportResult? result;
    try {
      result = await CsvImportService.pickAndParse(memoryLookup: memoryLookup);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not read the selected CSV file.'),
          backgroundColor: SchemeTheme.of(context).error,
        ),
      );
      return;
    }

    if (result == null) return;

    if (!context.mounted) return;

    if (result.imported.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.errors.isNotEmpty
                ? 'No valid rows found. ${result.errors.first}'
                : 'No valid rows found in the CSV.',
          ),
          backgroundColor: SchemeTheme.of(context).error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final skippedInfo = result.skipped > 0
        ? '  ${result.skipped} rows skipped.'
        : '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Import CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Found ${result!.imported.length} transactions to import.$skippedInfo',
            ),
            if (result.errors.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                '${result.errors.length} row(s) had errors and will be skipped.',
                style: TextStyle(
                  fontSize: 12,
                  color: SchemeTheme.of(context).warning,
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Existing or repeated matching transactions will be skipped. Continue?',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SchemeTheme.of(context).ctaFill,
              foregroundColor: SchemeTheme.of(context).ctaText,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    int inserted;
    try {
      inserted = await ref
          .read(expenseProvider.notifier)
          .importExpenses(result.imported);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not import the selected transactions.'),
        ),
      );
      return;
    }

    if (!context.mounted) return;
    final duplicates = result.imported.length - inserted;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imported $inserted transaction(s). '
          '${result.skipped} invalid row(s), $duplicates duplicate(s) skipped.',
        ),
        backgroundColor: SchemeTheme.of(context).success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }


  Future<void> _exportPDF(
    BuildContext context,
    WidgetRef ref,
    String currency,
  ) async {
    final expenses = ref
        .read(expenseProvider)
        .where((e) => !e.isUncategorized)
        .toList();
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export')),
      );
      return;
    }
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating PDF report...')),
      );
      final path = await PdfExportService.exportToPDF(
        expenses,
        currency: currency,
      );
      if (!context.mounted) return;
      await OpenFilex.open(path);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF export failed. Try again.')),
      );
    }
  }

  Future<void> _exportCSV(BuildContext context, WidgetRef ref) async {
    try {
      final expenses = ref.read(expenseProvider);
      final path = await ExportService.exportToCSV(expenses);
      if (!context.mounted) return;
      await OpenFilex.open(path);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV export failed. Try again.')),
      );
    }
  }

  Future<void> _shareCSV(BuildContext context, WidgetRef ref) async {
    final expenses = ref.read(expenseProvider);
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No transactions to share')));
      return;
    }
    try {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preparing report...')));
      final path = await ExportService.exportToCSV(expenses);
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'SpendSmart Expense Report',
        text: 'My expense report from SpendSmart',
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not share the report. Try again.')),
      );
    }
  }

  void _editCurrency(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = SchemeTheme.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Currency',
                style: Theme.of(sheetContext).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final c in ['₹', '\$', '€', '£', '¥'])
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c),
                  trailing: c == current
                      ? Icon(Icons.check, color: scheme.primary)
                      : null,
                  onTap: () {
                    ref.read(appSettingsProvider.notifier).updateCurrency(c);
                    Navigator.pop(sheetContext);
                  },
                ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: scheme.ctaFill,
                    foregroundColor: scheme.ctaText,
                  ),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: scheme.ctaText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  Future<void> _editBudget(
    BuildContext context,
    WidgetRef ref,
    double current,
  ) async {
    final ctrl = TextEditingController(
      text: current > 0 ? current.toStringAsFixed(0) : '',
    );
    final amountError = ValueNotifier<String?>(null);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = SchemeTheme.of(sheetContext);
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Monthly Budget',
                style: Theme.of(sheetContext).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.lg),
              ValueListenableBuilder<String?>(
                valueListenable: amountError,
                builder: (ctx, error, _) => TextField(
                  controller: ctrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    if (v.trim().isEmpty) {
                      amountError.value = null;
                    } else {
                      amountError.value = parsePositiveAmount(v) == null
                          ? 'Enter a valid monthly budget'
                          : null;
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Total monthly budget',
                    prefixText:
                        '${ref.read(appSettingsProvider).currency} ',
                    errorText: error,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: scheme.ctaFill,
                    foregroundColor: scheme.ctaText,
                  ),
                  onPressed: () async {
                    final val = parsePositiveAmount(ctrl.text);
                    if (val == null) {
                      amountError.value = 'Enter a valid monthly budget';
                      return;
                    }
                    HapticFeedback.mediumImpact();
                    await ref
                        .read(appSettingsProvider.notifier)
                        .updateBudget(val);
                    if (context.mounted) Navigator.pop(sheetContext);
                  },
                  child: Text(
                    'Save',
                    style: TextStyle(
                      color: scheme.ctaText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    ).whenComplete(() {
      ctrl.dispose();
      amountError.dispose();
    });
  }

  void _editStartingDay(BuildContext context, WidgetRef ref, int current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = SchemeTheme.of(sheetContext);
        return Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Starting Day of Month',
                style: Theme.of(sheetContext).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                height: 240,
                width: double.maxFinite,
                child: ListView.builder(
                  itemCount: 28,
                  itemBuilder: (context, index) {
                    final day = index + 1;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Day $day'),
                      trailing: day == current
                          ? Icon(Icons.check, color: scheme.primary)
                          : null,
                      onTap: () {
                        ref
                            .read(appSettingsProvider.notifier)
                            .updateStartingDay(day);
                        Navigator.pop(sheetContext);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: scheme.ctaFill,
                    foregroundColor: scheme.ctaText,
                  ),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: scheme.ctaText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  void _editTheme(BuildContext context, WidgetRef ref, String current) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        final scheme = SchemeTheme.of(sheetContext);
        const options = [
          ('light', 'Light', Icons.wb_sunny_outlined),
          ('dark', 'Dark', Icons.nightlight_outlined),
          ('system', 'System Default', Icons.brightness_auto),
        ];
        return Padding(
          padding: const EdgeInsets.only(
            left: AppSpacing.xl,
            right: AppSpacing.xl,
            top: AppSpacing.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select Theme',
                style: Theme.of(sheetContext).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final t in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(t.$3, color: scheme.primary),
                  title: Text(t.$2),
                  trailing: current == t.$1
                      ? Icon(Icons.check, color: scheme.primary)
                      : null,
                  onTap: () {
                    ref.read(appSettingsProvider.notifier).updateTheme(t.$1);
                    Navigator.pop(sheetContext);
                  },
                ),
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: scheme.ctaFill,
                    foregroundColor: scheme.ctaText,
                  ),
                  onPressed: () => Navigator.pop(sheetContext),
                  child: Text(
                    'Done',
                    style: TextStyle(
                      color: scheme.ctaText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
            ],
          ),
        );
      },
    );
  }

  String _ordinal(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }
}

// ── App info card ──────────────────────────────────────────────────────────────

class _AppInfoCard extends StatefulWidget {
  const _AppInfoCard();

  @override
  State<_AppInfoCard> createState() => _AppInfoCardState();
}

class _AppInfoCardState extends State<_AppInfoCard> {
  late final Future<PackageInfo> _packageInfoFuture;

  @override
  void initState() {
    super.initState();
    _packageInfoFuture = PackageInfo.fromPlatform();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = SchemeTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SchemeTheme.of(context).surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SchemeTheme.of(context).border),
      ),
      child: Column(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: SchemeTheme.of(context).primary.withValues(alpha: 0.3),
                  blurRadius: 16,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/logo.png',
                width: 80,
                height: 80,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'SpendSmart',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          FutureBuilder<PackageInfo>(
            future: _packageInfoFuture, // cached — not recreated on rebuild
            builder: (context, snapshot) => Text(
              'v${snapshot.data?.version ?? '2.1.0'}',
              style: TextStyle(color: scheme.muted, fontSize: 12),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your personal expense tracker',
            style: TextStyle(color: scheme.muted, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
