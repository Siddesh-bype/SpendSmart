import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_settings_provider.dart';
import '../providers/expense_provider.dart';
import '../services/export_service.dart';
import '../services/pdf_export_service.dart';
import '../utils/constants.dart';
import 'pdf_import_screen.dart';
import 'insights_screen.dart';
import 'spending_goals_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold))),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Profile
        Center(child: Column(children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), shape: BoxShape.circle),
            child: const Icon(Icons.person, size: 44, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          const Text('SpendSmart User', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('v1.0.0', style: const TextStyle(color: Colors.grey, fontSize: 13)),
        ])),
        const SizedBox(height: 24),

        _sectionTitle('Preferences'),
        _tile(
          icon: Icons.currency_rupee, title: 'Currency', subtitle: settings.currency,
          onTap: () => _editCurrency(context, ref, settings.currency),
        ),
        _tile(
          icon: Icons.account_balance_wallet, title: 'Monthly Income',
          subtitle: '${settings.currency}${settings.monthlyIncome.toStringAsFixed(0)}',
          onTap: () => _editIncome(context, ref, settings.monthlyIncome),
        ),

        const SizedBox(height: 16),
        _sectionTitle('Appearance'),
        _tile(
          icon: Icons.palette_outlined, title: 'Theme',
          subtitle: settings.theme == 'light' ? '☀️ Light' : settings.theme == 'dark' ? '🌙 Dark' : '⚙️ System',
          onTap: () => _editTheme(context, ref, settings.theme),
        ),

        const SizedBox(height: 16),
        _sectionTitle('Data & Import'),
        _tile(
          icon: Icons.picture_as_pdf, title: 'Import Bank Statement (PDF)',
          subtitle: 'Auto-import transactions from your bank PDF',
          color: Colors.red,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PdfImportScreen())),
        ),
        _tile(
          icon: Icons.insights, title: 'Spending Insights',
          subtitle: 'Smart tips and spending analysis',
          color: Colors.purple,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InsightsScreen())),
        ),
        _tile(
          icon: Icons.track_changes_rounded, title: 'Spending Goals',
          subtitle: 'Set and track your monthly budget goal',
          color: AppColors.primary,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpendingGoalsScreen())),
        ),

        const SizedBox(height: 16),
        _sectionTitle('Export'),
        _tile(
          icon: Icons.picture_as_pdf, title: 'Export to PDF',
          subtitle: 'Professional expense report with charts',
          color: Colors.deepOrange,
          onTap: () => _exportPDF(context, ref, settings.currency),
        ),
        _tile(
          icon: Icons.table_chart, title: 'Export to CSV',
          subtitle: 'Spreadsheet format for all transactions',
          color: Colors.green,
          onTap: () => _exportCSV(context, ref),
        ),
        _tile(
          icon: Icons.share_rounded, title: 'Share CSV Report',
          subtitle: 'Send expense data via WhatsApp, email, etc.',
          color: Colors.teal,
          onTap: () => _shareCSV(context, ref),
        ),

        const SizedBox(height: 16),
        _sectionTitle('About'),
        _tile(icon: Icons.info_outline, title: 'Version', subtitle: '1.0.0', onTap: null),
        _tile(icon: Icons.star_outline, title: 'Rate the App', onTap: () {}),
      ]),
    );
  }

  Widget _sectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(title, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 13)),
  );

  Widget _tile({required IconData icon, required String title, String? subtitle, VoidCallback? onTap, Color? color}) {
    final iconColor = color ?? AppColors.primary;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 38, height: 38,
          decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title),
        subtitle: subtitle != null ? Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)) : null,
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }

  Future<void> _exportPDF(BuildContext context, WidgetRef ref, String currency) async {
    final expenses = ref.read(expenseProvider).where((e) => !e.isUncategorized).toList();
    if (expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to export')));
      return;
    }
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏳ Generating PDF report...')));
      final path = await PdfExportService.exportToPDF(expenses, currency: currency);
      if (!context.mounted) return;
      await OpenFilex.open(path);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('PDF export failed: $e'), backgroundColor: Colors.red));
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
        SnackBar(content: Text('CSV export failed: $e'), backgroundColor: Colors.red));
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
        SnackBar(content: Text('Share failed: $e'), backgroundColor: Colors.red));
    }
  }


  void _editCurrency(BuildContext context, WidgetRef ref, String current) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Select Currency'),
      content: Column(mainAxisSize: MainAxisSize.min,
        children: ['₹', '\$', '€', '£', '¥'].map((c) => ListTile(
          title: Text(c), selected: c == current, selectedColor: AppColors.primary,
          onTap: () { ref.read(appSettingsProvider.notifier).updateCurrency(c); Navigator.pop(context); },
        )).toList(),
      ),
    ));
  }

  void _editIncome(BuildContext context, WidgetRef ref, double current) {
    final ctrl = TextEditingController(text: current.toStringAsFixed(0));
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Monthly Income'),
      content: TextField(controller: ctrl, keyboardType: TextInputType.number,
        decoration: const InputDecoration(hintText: 'Enter amount', prefixText: '₹ ')),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: () {
            ref.read(appSettingsProvider.notifier).updateIncome(double.tryParse(ctrl.text) ?? 0);
            Navigator.pop(context);
          },
          child: const Text('Save', style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  void _editTheme(BuildContext context, WidgetRef ref, String current) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Select Theme'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        for (final t in [('light', '☀️ Light'), ('dark', '🌙 Dark'), ('system', '⚙️ System Default')])
          ListTile(
            title: Text(t.$2),
            leading: Icon(
              current == t.$1 ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: AppColors.primary,
            ),
            onTap: () {
              ref.read(appSettingsProvider.notifier).updateTheme(t.$1); 
              Navigator.pop(context); 
            },
          ),
      ]),
    ));
  }
}
