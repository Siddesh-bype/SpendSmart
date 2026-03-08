import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_settings_provider.dart';
import '../providers/expense_provider.dart';
import '../services/csv_import_service.dart';
import '../services/export_service.dart';
import '../services/pdf_export_service.dart';
import '../utils/constants.dart';
import '../widgets/glass_container.dart';
import 'pdf_import_screen.dart';
import 'insights_screen.dart';
import 'spending_goals_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // ── App info card ──────────────────────────────────────────
        const _AppInfoCard(),
        const SizedBox(height: 24),

        _sectionTitle('Preferences'),
        _tile(
          icon: Icons.currency_rupee,
          title: 'Currency',
          subtitle: settings.currency,
          onTap: () => _editCurrency(context, ref, settings.currency),
        ),
        _tile(
          icon: Icons.account_balance_wallet,
          title: 'Monthly Budget',
          subtitle:
              '${settings.currency}${settings.monthlyBudget.toStringAsFixed(0)}',
          onTap: () => _editBudget(context, ref, settings.monthlyBudget),
        ),
        _tile(
          icon: Icons.calendar_month_outlined,
          title: 'Starting Day of Month',
          subtitle:
              'Starts on the ${settings.startingDayOfMonth}${_ordinal(settings.startingDayOfMonth)}',
          onTap: () =>
              _editStartingDay(context, ref, settings.startingDayOfMonth),
        ),

        const SizedBox(height: 16),
        _sectionTitle('Appearance'),
        _tile(
          icon: Icons.palette_outlined,
          title: 'Theme',
          subtitle: settings.theme == 'light'
              ? '☀️ Light'
              : settings.theme == 'dark'
                  ? '🌙 Dark'
                  : '⚙️ System',
          onTap: () => _editTheme(context, ref, settings.theme),
        ),

        const SizedBox(height: 16),
        _sectionTitle('Data & Import'),
        _tile(
          icon: Icons.picture_as_pdf,
          title: 'Import Bank Statement (PDF)',
          subtitle: 'Auto-import transactions from your bank PDF',
          color: Colors.red,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const PdfImportScreen())),
        ),
        _tile(
          icon: Icons.upload_file_rounded,
          title: 'Import CSV',
          subtitle: 'Import expenses from a SpendSmart or custom CSV file',
          color: Colors.green.shade700,
          onTap: () => _importCSV(context, ref),
        ),
        _tile(
          icon: Icons.insights,
          title: 'Spending Insights',
          subtitle: 'Smart tips and spending analysis',
          color: Colors.purple,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const InsightsScreen())),
        ),
        _tile(
          icon: Icons.track_changes_rounded,
          title: 'Spending Goals',
          subtitle: 'Set and track your monthly budget goal',
          color: AppColors.primary,
          onTap: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const SpendingGoalsScreen())),
        ),

        const SizedBox(height: 16),
        _sectionTitle('Export'),
        _tile(
          icon: Icons.picture_as_pdf,
          title: 'Export to PDF',
          subtitle: 'Professional expense report with charts',
          color: Colors.deepOrange,
          onTap: () => _exportPDF(context, ref, settings.currency),
        ),
        _tile(
          icon: Icons.table_chart,
          title: 'Export to CSV',
          subtitle: 'Spreadsheet format for all transactions',
          color: Colors.green,
          onTap: () => _exportCSV(context, ref),
        ),
        _tile(
          icon: Icons.share_rounded,
          title: 'Share CSV Report',
          subtitle: 'Send expense data via WhatsApp, email, etc.',
          color: Colors.teal,
          onTap: () => _shareCSV(context, ref),
        ),

        const SizedBox(height: 160),
      ]),
    );
  }

  Widget _sectionTitle(String title) => Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              title,
              style: TextStyle(
                color: isDark ? const Color(0xFF90CAF9) : AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
                letterSpacing: 0.3,
              ),
            ),
          );
        },
      );

  Widget _tile({
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
    Color? color,
  }) {
    final iconColor = color ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Builder(
        builder: (context) {
          final isDark = Theme.of(context).brightness == Brightness.dark;

          final tile = ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: isDark ? 0.25 : 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            title: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isDark ? const Color(0xFFE8EAF6) : null,
              ),
            ),
            subtitle: subtitle != null
                ? Text(
                    subtitle,
                    style: TextStyle(
                      color: isDark ? const Color(0xFF90CAF9) : Colors.grey,
                      fontSize: 12,
                    ),
                  )
                : null,
            trailing: onTap != null
                ? Icon(Icons.chevron_right,
                    color: isDark ? Colors.white38 : Colors.grey)
                : null,
            onTap: onTap,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          );

          if (isDark) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF1A2540),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: Colors.white.withValues(alpha: 0.1), width: 1),
              ),
              child: tile,
            );
          }
          return GlassContainer(
            borderRadius: 16,
            padding: const EdgeInsets.all(4),
            backgroundColor: Colors.white,
            child: tile,
          );
        },
      ),
    );
  }

  Future<void> _importCSV(BuildContext context, WidgetRef ref) async {
    CsvImportResult? result;
    try {
      result = await CsvImportService.pickAndParse();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to read file: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (result == null) return;

    if (!context.mounted) return;

    if (result.imported.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errors.isNotEmpty
              ? 'No valid rows found. ${result.errors.first}'
              : 'No valid rows found in the CSV.'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
      return;
    }

    final skippedInfo = result.skipped > 0 ? '  ${result.skipped} rows skipped.' : '';
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
                style: const TextStyle(fontSize: 12, color: Colors.orange),
              ),
            ],
            const SizedBox(height: 12),
            const Text(
              'Duplicate IDs will be overwritten. Continue?',
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
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Import'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    ref.read(expenseProvider.notifier).importExpenses(result.imported);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Imported ${result.imported.length} transaction(s) successfully.',
        ),
        backgroundColor: Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _exportPDF(
      BuildContext context, WidgetRef ref, String currency) async {
    final expenses =
        ref.read(expenseProvider).where((e) => !e.isUncategorized).toList();
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transactions to export')));
      return;
    }
    try {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('⏳ Generating PDF report...')));
      final path =
          await PdfExportService.exportToPDF(expenses, currency: currency);
      if (!context.mounted) return;
      await OpenFilex.open(path);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('PDF export failed: $e'),
              backgroundColor: Colors.red));
    }
  }

  Future<void> _exportCSV(BuildContext context, WidgetRef ref) async {
    try {
      final expenses = ref.read(expenseProvider);
      final path = await ExportService.exportToCSV(expenses);
      if (!context.mounted) return;
      await OpenFilex.open(path);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('CSV export failed: $e'),
              backgroundColor: Colors.red));
    }
  }

  Future<void> _shareCSV(BuildContext context, WidgetRef ref) async {
    final expenses = ref.read(expenseProvider);
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No transactions to share')));
      return;
    }
    try {
      HapticFeedback.lightImpact();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('📤 Preparing report...')));
      final path = await ExportService.exportToCSV(expenses);
      await Share.shareXFiles(
        [XFile(path)],
        subject: 'SpendSmart Expense Report',
        text: 'My expense report from SpendSmart 📊',
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Share failed: $e'),
              backgroundColor: Colors.red));
    }
  }

  void _editCurrency(
      BuildContext context, WidgetRef ref, String current) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Currency'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: ['₹', '\$', '€', '£', '¥']
              .map((c) => ListTile(
                    title: Text(c),
                    selected: c == current,
                    selectedColor: AppColors.primary,
                    onTap: () {
                      ref
                          .read(appSettingsProvider.notifier)
                          .updateCurrency(c);
                      Navigator.pop(context);
                    },
                  ))
              .toList(),
        ),
      ),
    );
  }

  Future<void> _editBudget(
      BuildContext context, WidgetRef ref, double current) async {
    final ctrl = TextEditingController(
        text: current > 0 ? current.toStringAsFixed(0) : '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Monthly Budget'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'Total monthly budget',
            prefixText: '${ref.read(appSettingsProvider).currency} ',
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white),
            onPressed: () {
              final val = double.tryParse(ctrl.text) ?? 0;
              HapticFeedback.mediumImpact();
              ref.read(appSettingsProvider.notifier).updateBudget(val);
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ).whenComplete(() => ctrl.dispose());
  }

  void _editStartingDay(
      BuildContext context, WidgetRef ref, int current) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Starting Day of Month'),
        content: SizedBox(
          width: double.maxFinite,
          height: 200,
          child: ListView.builder(
            itemCount: 28,
            itemBuilder: (context, index) {
              final day = index + 1;
              return ListTile(
                title: Text('Day $day'),
                trailing: day == current
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref
                      .read(appSettingsProvider.notifier)
                      .updateStartingDay(day);
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _editTheme(BuildContext context, WidgetRef ref, String current) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Select Theme'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final t in [
              ('light', '☀️ Light'),
              ('dark', '🌙 Dark'),
              ('system', '⚙️ System Default')
            ])
              ListTile(
                title: Text(t.$2),
                leading: Icon(
                  current == t.$1
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  color: AppColors.primary,
                ),
                onTap: () {
                  ref.read(appSettingsProvider.notifier).updateTheme(t.$1);
                  Navigator.pop(context);
                },
              ),
          ],
        ),
      ),
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

class _AppInfoCard extends StatelessWidget {
  const _AppInfoCard();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      borderRadius: 24,
      padding: const EdgeInsets.all(24),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      child: Column(children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
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
          future: PackageInfo.fromPlatform(),
          builder: (context, snapshot) => Text(
            'v${snapshot.data?.version ?? '2.1.0'}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your personal expense tracker',
          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
          textAlign: TextAlign.center,
        ),
      ]),
    );
  }
}
