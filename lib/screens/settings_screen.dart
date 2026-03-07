import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/app_settings_provider.dart';
import '../providers/expense_provider.dart';
import '../providers/budget_provider.dart';
import '../services/export_service.dart';
import '../services/pdf_export_service.dart';
import '../services/supabase_service.dart';
import '../services/notification_service.dart';
import '../providers/service_provider.dart';
import '../utils/constants.dart';
import 'pdf_import_screen.dart';
import 'insights_screen.dart';
import 'spending_goals_screen.dart';
import 'auth_screen.dart';

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
          const SizedBox(height: 12),
          Text(SupabaseService.currentUser?.email ?? 'Guest (Offline)', 
               style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          const Text('v2.0.0', style: TextStyle(color: Colors.grey, fontSize: 13)),
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
        _tile(
          icon: Icons.calendar_month_outlined, title: 'Starting Day of Month',
          subtitle: 'Starts on the ${settings.startingDayOfMonth}${_ordinal(settings.startingDayOfMonth)}',
          onTap: () => _editStartingDay(context, ref, settings.startingDayOfMonth),
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
          icon: Icons.notifications_active_rounded, title: 'Enable Notification Tracking',
          subtitle: 'Auto-detect transactions from banking app notifications',
          color: Colors.deepPurple,
          onTap: () => _enableNotificationTracking(context, ref),
        ),
        _tile(
          icon: Icons.track_changes_rounded, title: 'Spending Goals',
          subtitle: 'Set and track your monthly budget goal',
          color: AppColors.primary,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SpendingGoalsScreen())),
        ),
        _tile(
          icon: Icons.cloud_sync_rounded, title: 'Sync to Cloud',
          subtitle: SupabaseService.currentUser == null ? 'Log in to securely backup data' : 'Upload and pull remote data',
          color: AppColors.secondary,
          onTap: () {
            if (SupabaseService.currentUser == null) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
            } else {
              _syncCloud(context, ref);
            }
          },
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
        _sectionTitle('About & Account'),
        _tile(icon: Icons.info_outline, title: 'Version', subtitle: '2.0.0', onTap: null),
        const SizedBox(height: 16),
        
        if (SupabaseService.currentUser != null)
          ElevatedButton.icon(
            onPressed: () => _handleLogout(context, ref),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade50,
              foregroundColor: Colors.red.shade700,
              elevation: 0,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.logout),
            label: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
          )
        else
          ElevatedButton.icon(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen())),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.1),
              foregroundColor: AppColors.primary,
              elevation: 0,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.login),
            label: const Text('Log In to Sync', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        const SizedBox(height: 32),
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

  Future<void> _syncCloud(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('☁️ Syncing to Supabase...'),
        duration: Duration(seconds: 2),
      ),
    );
    try {
      final expenses = ref.read(expenseProvider);
      final budgets = ref.read(budgetProvider);
      // Upload all local data
      await SupabaseService.uploadAllExpenses(expenses);
      await SupabaseService.uploadAllBudgets(budgets);
      // Pull any remote data not yet local
      await ref.read(expenseProvider.notifier).syncFromSupabase();
      await ref.read(budgetProvider.notifier).syncFromSupabase();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('✅ Sync complete!'),
      backgroundColor: Colors.green.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sync failed: $e'), backgroundColor: Colors.red),
      );
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

  void _editStartingDay(BuildContext context, WidgetRef ref, int current) {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('Starting Day of Month'),
      content: SizedBox(
        width: double.maxFinite,
        height: 200,
        child: ListView.builder(
          itemCount: 28, // Max safe day
          itemBuilder: (context, index) {
            final day = index + 1;
            return ListTile(
              title: Text('Day $day'),
              trailing: day == current ? const Icon(Icons.check, color: AppColors.primary) : null,
              onTap: () {
                ref.read(appSettingsProvider.notifier).updateStartingDay(day);
                Navigator.pop(context);
              },
            );
          },
        ),
      ),
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

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Log Out?'),
        content: const Text('This will clear local data. Your data remains safely backed up in the cloud.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Log Out', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      )
    ) ?? false;

    if (!confirm || !context.mounted) return;

    HapticFeedback.heavyImpact();
    
    // 1. Sign out from Supabase
    await SupabaseService.signOut();
    
    // 2. Clear entirely from local Hive boxes
    final storage = ref.read(storageServiceProvider);
    await storage.clearAll();

    // 3. Navigate straight back to Auth
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const AuthScreen()),
        (route) => false,
      );
    }
  }

  Future<void> _enableNotificationTracking(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Requesting notification access…')),
    );
    final granted = await ref.read(notificationServiceProvider).init();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        granted
            ? '✅ Notification tracking enabled. Banking alerts will auto-create expenses.'
            : '❌ Permission denied. Open Android Settings → Notification Access to grant it.',
      ),
      backgroundColor: granted ? Colors.green.shade600 : Colors.red.shade600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 4),
    ));
  }

  String _ordinal(int number) {
    if (number >= 11 && number <= 13) return 'th';
    switch (number % 10) {
      case 1:  return 'st';
      case 2:  return 'nd';
      case 3:  return 'rd';
      default: return 'th';
    }
  }
}
