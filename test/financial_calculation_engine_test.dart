import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/models/app_settings.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/expense.dart';
import 'package:spendsmart/services/financial_calculation_engine.dart';
import 'package:spendsmart/services/ai_financial_advisor_service.dart';

void main() {
  group('FinancialCalculationEngine', () {
    test('calculatePacing computes accurate burn rate and daily safe allowance', () {
      final pacing = FinancialCalculationEngine.calculatePacing(
        spendSoFar: 5000,
        budget: 15000,
        daysElapsed: 10,
        totalDays: 30,
      );

      expect(pacing.projectedMonthEnd, 15000.0);
      expect(pacing.burnRate, 1.0);
      expect(pacing.dailySafeToSpend, 500.0); // 10000 / 20 remaining days
      expect(pacing.status, PacingStatus.onTrack);
    });

    test('calculatePacing flags critical overbudget when burn rate spikes', () {
      final pacing = FinancialCalculationEngine.calculatePacing(
        spendSoFar: 12000,
        budget: 15000,
        daysElapsed: 10,
        totalDays: 30,
      );

      expect(pacing.burnRate, 2.4);
      expect(pacing.projectedMonthEnd, 36000.0);
      expect(pacing.status, PacingStatus.overBudget);
    });

    test('evaluateHealthScore generates weighted health score and recommendations', () {
      final report = FinancialCalculationEngine.evaluateHealthScore(
        currentSpend: 4000,
        budget: 10000,
        recurringTotal: 1000,
        categorySpends: {'food': 1200, 'bills': 1800, 'entertainment': 1000},
        daysElapsed: 15,
        totalDays: 30,
      );

      expect(report.score, greaterThanOrEqualTo(80));
      expect(report.tier, HealthScoreTier.excellent);
      expect(report.summary.isNotEmpty, true);
    });

    test('optimizeGroupSettlements minimizes multi-party debts to fewest transactions', () {
      // Alice paid 60, Bob paid 0, Charlie paid 0 for a 60 bill split evenly (20 each)
      // Alice: +40, Bob: -20, Charlie: -20
      final balances = {
        'Alice': 40.0,
        'Bob': -20.0,
        'Charlie': -20.0,
      };

      final transfers = FinancialCalculationEngine.optimizeGroupSettlements(balances);
      expect(transfers.length, 2);
      expect(transfers.any((t) => t.from == 'Bob' && t.to == 'Alice' && t.amount == 20.0), true);
      expect(transfers.any((t) => t.from == 'Charlie' && t.to == 'Alice' && t.amount == 20.0), true);
    });
  });

  group('AiFinancialAdvisorService', () {
    test('generateReview produces structured AI insights', () {
      final List<Expense> expenses = [
        Expense(
          id: '1',
          title: 'Starbucks',
          amount: 500,
          date: DateTime.now(),
          category: Category.food,
          isManual: true,
          isUncategorized: false,
          source: 'manual',
        ),
        Expense(
          id: '2',
          title: 'Electricity Bill',
          amount: 2500,
          date: DateTime.now(),
          category: Category.bills,
          isManual: true,
          isUncategorized: false,
          source: 'manual',
        ),
      ];

      final settings = AppSettings(
        monthlyBudget: 20000,
        currency: '₹',
        startingDayOfMonth: 1,
      );

      final review = AiFinancialAdvisorService.generateReview(
        allExpenses: expenses,
        budgets: [],
        settings: settings,
      );

      expect(review.totalSpend, 3000.0);
      expect(review.recommendations.isNotEmpty, true);
      expect(review.healthReport.score, greaterThan(0));
    });

    test('answerSpendingQuery responds accurately to natural language questions', () {
      final List<Expense> expenses = [
        Expense(
          id: '1',
          title: 'Dominos Pizza',
          amount: 800,
          date: DateTime.now(),
          category: Category.food,
          isManual: true,
          isUncategorized: false,
          source: 'manual',
        ),
        Expense(
          id: '2',
          title: 'New Smartphone',
          amount: 25000,
          date: DateTime.now(),
          category: Category.shopping,
          isManual: true,
          isUncategorized: false,
          source: 'manual',
        ),
      ];

      final settings = AppSettings(
        currency: r'$',
        monthlyBudget: 30000,
      );

      final highest = AiFinancialAdvisorService.answerSpendingQuery(
        query: 'What was my highest expense?',
        expenses: expenses,
        settings: settings,
      );
      expect(highest.contains('New Smartphone'), true);
      expect(highest.contains('25,000'), true);

      final foodQuery = AiFinancialAdvisorService.answerSpendingQuery(
        query: 'How much did I spend on food?',
        expenses: expenses,
        settings: settings,
      );
      expect(foodQuery.contains('Food'), true);
      expect(foodQuery.contains('800'), true);
    });
  });
}
