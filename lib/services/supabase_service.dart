import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/expense.dart';
import '../models/budget.dart';
import '../models/category.dart';

/// Remote sync service wrapping Supabase.
/// Local Hive is the source of truth. Supabase = cloud backup + multi-device sync.
/// All calls are fire-and-forget — errors are caught so offline mode works.
class SupabaseService {
  static SupabaseClient? get _db {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null; // Not initialized (config not filled in)
    }
  }

  // ── Authentication ──
  static User? get currentUser => _db?.auth.currentUser;
  static String get userId => currentUser?.id ?? '';

  static Future<AuthResponse> signUp(String email, String password) async {
    return await _db!.auth.signUp(email: email, password: password);
  }

  static Future<AuthResponse> signIn(String email, String password) async {
    return await _db!.auth.signInWithPassword(email: email, password: password);
  }

  static Future<void> signOut() async {
    await _db?.auth.signOut();
  }

  // ═══════════════════════════════════════
  //  EXPENSES
  // ═══════════════════════════════════════

  static Future<void> upsertExpense(Expense expense) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.from('expenses').upsert({
        'id': expense.id,
        'user_id': userId,
        'title': expense.title,
        'amount': expense.amount,
        'category': expense.category.name,
        'date': expense.date.toIso8601String(),
        'note': expense.note,
        'is_manual': expense.isManual,
        'is_uncategorized': expense.isUncategorized,
        'source': expense.source,
      });
    } catch (_) {}
  }

  static Future<void> deleteExpense(String id) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.from('expenses').delete().eq('id', id).eq('user_id', userId);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> fetchExpenses() async {
    final db = _db;
    if (db == null) return [];
    try {
      final data = await db
          .from('expenses')
          .select()
          .eq('user_id', userId)
          .order('date', ascending: false);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════
  //  BUDGETS
  // ═══════════════════════════════════════

  static Future<void> upsertBudget(Budget budget) async {
    final db = _db;
    if (db == null) return;
    try {
      await db.from('budgets').upsert({
        'user_id': userId,
        'category': budget.category.name,
        'monthly_limit': budget.monthlyLimit,
        'alert_at': budget.alertAt,
      }, onConflict: 'user_id, category');
    } catch (_) {}
  }

  static Future<void> deleteBudgetByCategory(String categoryName) async {
    final db = _db;
    if (db == null) return;
    try {
      await db
          .from('budgets')
          .delete()
          .eq('user_id', userId)
          .eq('category', categoryName);
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> fetchBudgets() async {
    final db = _db;
    if (db == null) return [];
    try {
      final data = await db
          .from('budgets')
          .select()
          .eq('user_id', userId);
      return List<Map<String, dynamic>>.from(data);
    } catch (_) {
      return [];
    }
  }

  // ═══════════════════════════════════════
  //  HELPERS
  // ═══════════════════════════════════════

  static Expense rowToExpense(Map<String, dynamic> row) {
    final catName = (row['category'] as String).toLowerCase();
    final cat = Category.values.firstWhere(
      (c) => c.name.toLowerCase() == catName,
      orElse: () => Category.other,
    );
    return Expense(
      id: row['id'],
      title: row['title'],
      amount: (row['amount'] as num).toDouble(),
      category: cat,
      date: DateTime.parse(row['date']),
      note: row['note'],
      isManual: row['is_manual'] ?? false,
      isUncategorized: row['is_uncategorized'] ?? false,
      source: row['source'] ?? 'remote',
    );
  }

  /// Upload ALL local expenses to Supabase in one batch.
  static Future<void> uploadAllExpenses(List<Expense> expenses) async {
    final db = _db;
    if (db == null || expenses.isEmpty) return;
    try {
      final rows = expenses.map((e) => {
        'id': e.id,
        'user_id': userId,
        'title': e.title,
        'amount': e.amount,
        'category': e.category.name,
        'date': e.date.toIso8601String(),
        'note': e.note,
        'is_manual': e.isManual,
        'is_uncategorized': e.isUncategorized,
        'source': e.source,
      }).toList();
      await db.from('expenses').upsert(rows);
    } catch (_) {}
  }

  /// Upload ALL local budgets to Supabase in one batch.
  static Future<void> uploadAllBudgets(List<Budget> budgets) async {
    final db = _db;
    if (db == null || budgets.isEmpty) return;
    try {
      final rows = budgets.map((b) => {
        'user_id': userId,
        'category': b.category.name,
        'monthly_limit': b.monthlyLimit,
        'alert_at': b.alertAt,
      }).toList();
      await db.from('budgets').upsert(rows, onConflict: 'user_id, category');
    } catch (_) {}
  }
}
