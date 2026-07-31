import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spendsmart/models/budget.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/expense.dart';
import 'package:spendsmart/models/group_expense.dart';
import 'package:spendsmart/models/income.dart';
import 'package:spendsmart/models/lending.dart';
import 'package:spendsmart/models/merchant_memory.dart';
import 'package:spendsmart/models/recurring_expense.dart';
import 'package:spendsmart/models/split_group.dart';
import 'package:spendsmart/providers/app_settings_provider.dart';
import 'package:spendsmart/providers/service_provider.dart';
import 'package:spendsmart/screens/add_expense_screen.dart';
import 'package:spendsmart/screens/ai_sign_in_screen.dart';
import 'package:spendsmart/screens/analytics_screen.dart';
import 'package:spendsmart/screens/budget_screen.dart';
import 'package:spendsmart/screens/groups_screen.dart';
import 'package:spendsmart/screens/home_screen.dart';
import 'package:spendsmart/screens/income_screen.dart';
import 'package:spendsmart/screens/insights_screen.dart';
import 'package:spendsmart/screens/lending_screen.dart';
import 'package:spendsmart/screens/login_screen.dart';
import 'package:spendsmart/screens/main_scaffold.dart';
import 'package:spendsmart/screens/notifications_screen.dart';
import 'package:spendsmart/screens/onboarding_screen.dart';
import 'package:spendsmart/screens/pdf_import_screen.dart';
import 'package:spendsmart/screens/pending_screen.dart';
import 'package:spendsmart/screens/recurring_expense_screen.dart';
import 'package:spendsmart/screens/settings_screen.dart';
import 'package:spendsmart/screens/signup_screen.dart';
import 'package:spendsmart/screens/spending_goals_screen.dart';
import 'package:spendsmart/screens/transactions_screen.dart';
import 'package:spendsmart/services/storage_service.dart';
import 'package:spendsmart/utils/theme.dart';

void main() {
  late Directory tempDir;
  late StorageService storage;

  setUpAll(() async {
    tempDir = await Directory.systemTemp.createTemp('spendsmart_layout_');
    Hive.init(tempDir.path);
    Hive.registerAdapter(CategoryAdapter());
    Hive.registerAdapter(ExpenseAdapter());
    Hive.registerAdapter(MerchantMemoryAdapter());
    Hive.registerAdapter(BudgetAdapter());
    Hive.registerAdapter(IncomeAdapter());
    Hive.registerAdapter(LendingAdapter());
    Hive.registerAdapter(RecurringExpenseAdapter());
    Hive.registerAdapter(SplitGroupAdapter());
    Hive.registerAdapter(GroupExpenseAdapter());
    await Hive.openBox<Expense>(StorageService.expenseBoxName);
    await Hive.openBox<MerchantMemory>(StorageService.merchantBoxName);
    await Hive.openBox<Budget>(StorageService.budgetBoxName);
    await Hive.openBox<Lending>(StorageService.lendingBoxName);
    await Hive.openBox<Income>(StorageService.incomeBoxName);
    await Hive.openBox<RecurringExpense>(StorageService.recurringBoxName);
    await Hive.openBox<SplitGroup>(StorageService.splitGroupBoxName);
    await Hive.openBox<GroupExpense>(StorageService.groupExpenseBoxName);
    storage = StorageService();
  });

  tearDownAll(() async {
    await Hive.close();
    await tempDir.delete(recursive: true);
  });

  testWidgets('screens fit a compact phone in light and dark modes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    SharedPreferences.setMockInitialValues({'onboardingDone': true});
    final prefs = await SharedPreferences.getInstance();
    final screens = <String, Widget>{
      'main': const MainScaffold(),
      'home': const HomeScreen(),
      'analytics': const AnalyticsScreen(),
      'budget': const BudgetScreen(),
      'groups': const GroupsScreen(),
      'settings': const SettingsScreen(),
      'add expense': const AddExpenseScreen(),
      'transactions': const TransactionsScreen(),
      'lending': const LendingScreen(),
      'income': const IncomeScreen(),
      'recurring': const RecurringExpenseScreen(),
      'insights': const InsightsScreen(),
      'goals': const SpendingGoalsScreen(),
      'PDF import': const PdfImportScreen(),
      'pending': const PendingScreen(),
      'notifications': const NotificationsScreen(),
      'onboarding': const OnboardingScreen(),
      'signup': const SignupScreen(),
      'login': const LoginScreen(),
      'AI sign-in': const AiSignInScreen(),
    };

    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      for (final entry in screens.entries) {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              storageServiceProvider.overrideWithValue(storage),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              theme: AppTheme.lightTheme,
              darkTheme: AppTheme.darkTheme,
              themeMode: mode,
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(360, 800),
                  textScaler: TextScaler.linear(1.2),
                ),
                child: entry.value,
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          tester.takeException(),
          isNull,
          reason: '${entry.key} failed in ${mode.name} mode',
        );
      }
    }
  });

  testWidgets('onboarding does not advertise removed SMS detection', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Track Every Expense'), findsOneWidget);
    expect(find.textContaining('read SMS'), findsNothing);
  });
}
