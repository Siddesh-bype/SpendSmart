import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notification_listener_service/notification_listener_service.dart';
import 'sms_parser.dart';
import '../models/category.dart';
import '../models/expense.dart';
import '../providers/expense_provider.dart';
import '../utils/globals.dart';
import '../widgets/transaction_detected_dialog.dart';

/// Banking/fintech app package names typically seen in India.
/// Add more package names for apps you want tracked.
const _trackedPackages = {
  'com.msf.iMobile',          // ICICI iMobile
  'com.sbi.SBIFreedomPlus',   // SBI YONO
  'com.axis.mobile',           // Axis Mobile
  'com.hdfc.wallet',           // HDFC PayZapp
  'com.freecharge.android',    // Freecharge
  'net.one97.paytm',           // Paytm
  'com.phonepe.app',           // PhonePe
  'com.google.android.apps.nbu.paisa.user', // Google Pay
  'in.amazon.mShop.android.shopping',       // Amazon Pay
  'com.whatsapp',              // WhatsApp (sometimes sends payment alerts)
};

/// Keywords that suggest a debit notification.
const _debitKeywords = [
  'debited', 'rs.', '₹', 'spent', 'paid', 'payment of',
  'your a/c', 'your account', 'deducted', 'purchase',
];

class NotificationService {
  final Ref _ref;
  bool _listening = false;

  NotificationService(this._ref);

  /// Request notification listener permission and start tracking.
  Future<bool> init() async {
    bool granted = await NotificationListenerService.isPermissionGranted();
    if (!granted) {
      granted = await NotificationListenerService.requestPermission();
    }
    if (granted && !_listening) {
      _startListening();
    }
    return granted;
  }

  void _startListening() {
    _listening = true;
    NotificationListenerService.notificationsStream.listen((event) {
      final package = event.packageName ?? '';
      final content = event.content ?? '';
      final title = event.title ?? '';

      // Optionally restrict to known banking apps; comment-out the if to catch ALL apps
      if (_trackedPackages.isNotEmpty && !_trackedPackages.contains(package)) {
        return;
      }

      final lowered = '$content $title'.toLowerCase();
      final looksLikeTransaction = _debitKeywords.any((k) => lowered.contains(k));
      if (!looksLikeTransaction) return;

      log('[NotificationService] Transaction notification from $package: $content');
      _tryParseAndSave(content);
    });
  }

  void _tryParseAndSave(String content) {
    final expense = SMSParser.parseSMS(content, DateTime.now());
    if (expense != null) {
      log('[NotificationService] Detected expense: ${expense.title} ₹${expense.amount}');
      _promptCategorization(expense);
    }
  }

  void _promptCategorization(Expense expense) {
    final context = navigatorKey.currentContext;
    if (context == null) {
      // App is likely in background with no active context.
      // We save it straight away without category (user can categorize later in Pending Screen)
      _ref.read(expenseProvider.notifier).addExpenseFromSMS(expense);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => TransactionDetectedDialog(
        merchant: expense.title,
        amount: expense.amount,
        rawMessage: expense.note ?? '', // Orignal msg saved in note
        onSave: (Category category) {
          expense.category = category;
          expense.isUncategorized = false;
          _ref.read(expenseProvider.notifier).addExpenseFromSMS(expense);
          Navigator.pop(context); // Close dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Expense saved ✅'), backgroundColor: Colors.green),
          );
        },
        onDismiss: () {
          Navigator.pop(context); // Skip
        },
      ),
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref);
});
