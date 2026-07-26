import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/models/expense.dart';
import 'package:spendsmart/screens/analytics_screen.dart';

Expense expense(String id, Category category, double amount, DateTime date) =>
    Expense(
      id: id,
      title: id,
      amount: amount,
      category: category,
      date: date,
      isManual: true,
      isUncategorized: false,
      source: 'test',
    );

void main() {
  test('daily category totals include only the selected calendar day', () {
    final totals = categoryTotalsForDay([
      expense('lunch', Category.food, 250, DateTime(2026, 7, 11, 13)),
      expense('coffee', Category.food, 50, DateTime(2026, 7, 11, 18)),
      expense('bus', Category.transport, 40, DateTime(2026, 7, 11, 9)),
      expense('yesterday', Category.food, 500, DateTime(2026, 7, 10)),
    ], DateTime(2026, 7, 11));

    expect(totals, {Category.food: 300, Category.transport: 40});
  });
}
