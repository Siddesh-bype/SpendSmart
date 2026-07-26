import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/expense.dart';
import 'package:spendsmart/services/ai_spending_analysis_service.dart';

Expense _expense(
  String title,
  Category category,
  double amount,
  DateTime date,
) => Expense(
  id: title,
  title: title,
  amount: amount,
  category: category,
  date: date,
  isManual: true,
  isUncategorized: false,
  source: 'test',
);

void main() {
  test('AI request contains aggregate progress and three completed months', () {
    final request = AiSpendingAnalysisService.buildRequest(
      expenses: [
        _expense('Private merchant', Category.food, 250, DateTime(2026, 7, 12)),
        _expense('Last month', Category.food, 100, DateTime(2026, 6, 12)),
        _expense('Two months ago', Category.food, 80, DateTime(2026, 5, 12)),
        _expense(
          'Three months ago',
          Category.transport,
          60,
          DateTime(2026, 4, 12),
        ),
      ],
      currency: 'INR',
      monthlyBudget: 1000,
      startingDayOfMonth: 10,
      now: DateTime(2026, 7, 20),
    );

    expect(request['period'], {
      'daysElapsed': 11,
      'daysRemaining': 20,
      'totalDays': 31,
    });
    expect(request['currentMonth'], {
      'total': 250.0,
      'categories': {'Food': 250.0},
    });
    expect(request['history'], [
      {
        'total': 100.0,
        'categories': {'Food': 100.0},
      },
      {
        'total': 80.0,
        'categories': {'Food': 80.0},
      },
      {
        'total': 60.0,
        'categories': {'Transport': 60.0},
      },
    ]);
    expect(request.toString(), isNot(contains('Private merchant')));
  });

  test('AI response accepts deterministic forecast and anomalies', () {
    final result = AiSpendingAnalysisService.parseResponse('''
      {
        "summary":"Spending is steady.",
        "forecast":{"projectedSpend":1100,"status":"atRisk","confidence":"medium"},
        "anomalies":[
          {"category":"Food","currentAmount":500,"baselineAmount":250,"severity":"warning"}
        ],
        "insights":[
          {"title":"Food is highest","detail":"Consider a weekly cap.","tone":"warning"}
        ]
      }
    ''');

    expect(result.summary, 'Spending is steady.');
    expect(result.insights.single.tone, 'warning');
    expect(result.forecast.projectedSpend, 1100);
    expect(result.forecast.status, 'atRisk');
    expect(result.anomalies.single.category, 'Food');
  });
}
