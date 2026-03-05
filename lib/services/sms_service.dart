import 'package:telephony/telephony.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'sms_parser.dart';
import 'storage_service.dart';
import '../providers/expense_provider.dart';

@pragma('vm:entry-point')
Future<void> backgroundMessageHandler(SmsMessage message) async {
  if (message.body == null) return;
  final expense = SMSParser.parseSMS(message.body!, DateTime.now());
  if (expense != null) {
    final storage = StorageService();
    await storage.init();
    
    final memory = storage.getMerchantMemory(expense.title);
    if (memory != null) {
      expense.category = memory.category;
      expense.isUncategorized = false;
      await storage.saveMerchantMemory(expense.title, memory.category);
    }
    
    await storage.saveExpense(expense);
  }
}

class SMSService {
  final Telephony telephony = Telephony.instance;
  final Ref ref;

  SMSService(this.ref);

  Future<void> init() async {
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted != null && permissionsGranted) {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          _handleForegroundMessage(message);
        },
        onBackgroundMessage: backgroundMessageHandler,
      );
    }
  }

  void _handleForegroundMessage(SmsMessage message) async {
    if (message.body == null) return;
    final expense = SMSParser.parseSMS(message.body!, DateTime.now());
    if (expense != null) {
      ref.read(expenseProvider.notifier).addExpenseFromSMS(expense);
    }
  }

  Future<void> importPastSMS() async {
    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted != null && permissionsGranted) {
      List<SmsMessage> messages = await telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
        sortOrder: [OrderBy(SmsColumn.DATE, sort: Sort.DESC)],
      );

      for (var msg in messages) {
        if (msg.body != null && msg.date != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(msg.date!);
          final expense = SMSParser.parseSMS(msg.body!, date);
          if (expense != null) {
            ref.read(expenseProvider.notifier).addExpenseFromSMS(expense, isImport: true);
          }
        }
      }
    }
  }
}
