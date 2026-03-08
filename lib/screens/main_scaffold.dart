import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'analytics_screen.dart';
import 'budget_screen.dart';
import 'settings_screen.dart';
import 'add_expense_screen.dart';
import 'lending_screen.dart';
import '../models/category.dart';
import '../utils/constants.dart';
import '../widgets/glass_container.dart';
import '../providers/recurring_expense_provider.dart';
import '../providers/expense_provider.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _quickAddOpen = false;
  late final AnimationController _fabController;
  late final AnimationController _quickAddController;

  final List<Widget> _screens = const [
    HomeScreen(),
    AnalyticsScreen(),
    BudgetScreen(),
    LendingScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _fabController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();
    _quickAddController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Generate any overdue recurring expenses on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(recurringExpenseProvider.notifier).generateDueExpenses(
        ref.read(expenseProvider.notifier),
      );
    });
  }

  @override
  void dispose() {
    _fabController.dispose();
    _quickAddController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    if (_quickAddOpen) _closeQuickAdd();
    setState(() => _currentIndex = index);
  }

  void _toggleQuickAdd() {
    HapticFeedback.mediumImpact();
    setState(() => _quickAddOpen = !_quickAddOpen);
    if (_quickAddOpen) {
      _quickAddController.forward();
    } else {
      _quickAddController.reverse();
    }
  }

  void _closeQuickAdd() {
    setState(() => _quickAddOpen = false);
    _quickAddController.reverse();
  }

  Future<void> _openAddExpense({Category? initialCategory}) async {
    _closeQuickAdd();
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddExpenseScreen(initialCategory: initialCategory)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onTap: _quickAddOpen ? _closeQuickAdd : null,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        extendBody: false,
        body: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Quick-add chips
            if (_quickAddOpen) ...[
              ...Category.values.take(6).map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: ScaleTransition(
                    scale: CurvedAnimation(parent: _quickAddController, curve: Curves.easeOutBack),
                    child: FloatingActionButton.extended(
                      heroTag: 'quick_${cat.name}',
                      onPressed: () => _openAddExpense(initialCategory: cat),
                      backgroundColor: cat.color,
                      foregroundColor: Colors.white,
                      icon: Icon(cat.icon, size: 20),
                      label: Text(cat.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                      elevation: 8,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 10),
            ],
            // Main FAB — circular
            ScaleTransition(
              scale: CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
              child: GestureDetector(
                onLongPress: _toggleQuickAdd,
                child: SizedBox(
                  width: 50,
                  height: 50,
                  child: FloatingActionButton(
                    heroTag: 'main_fab',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (_quickAddOpen) {
                        _closeQuickAdd();
                      } else {
                        _openAddExpense();
                      }
                    },
                    backgroundColor: AppColors.accent,
                    elevation: 8,
                    child: AnimatedRotation(
                      turns: _quickAddOpen ? 0.125 : 0,
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeInOutBack,
                      child: const Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          color: Colors.transparent,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          padding: EdgeInsets.zero,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: GlassContainer(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                borderRadius: 28,
                backgroundColor: isDark
                    ? AppColors.surfaceDark.withValues(alpha: 0.6)
                    : Colors.white.withValues(alpha: 0.6),
                blurRadius: 20,
                child: SizedBox(
                  height: 56,
                  child: Row(
                    children: [
                      // Left group — flex 3 each so total = 6
                      Expanded(flex: 3, child: _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home', isDark)),
                      Expanded(flex: 3, child: _navItem(1, Icons.pie_chart_rounded, Icons.pie_chart_outline_rounded, 'Analytics', isDark)),
                      // Center gap for FAB
                      const SizedBox(width: 64),
                      // Right group — flex 2 each so total = 6
                      Expanded(flex: 2, child: _navItem(2, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Budget', isDark)),
                      Expanded(flex: 2, child: _navItem(3, Icons.handshake_rounded, Icons.handshake_outlined, 'Split', isDark)),
                      Expanded(flex: 2, child: _navItem(4, Icons.person_rounded, Icons.person_outline_rounded, 'Profile', isDark)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Returns inner widget only — Expanded wrapper is applied at call site
  Widget _navItem(int index, IconData activeIcon, IconData inactiveIcon, String label, bool isDark) {
    final selected = _currentIndex == index;
    final inactiveColor = isDark ? Colors.white54 : Colors.black45;

    return GestureDetector(
      onTap: () => _onTabTap(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutExpo,
            padding: EdgeInsets.symmetric(horizontal: 10, vertical: selected ? 6 : 4),
            decoration: BoxDecoration(
              color: selected ? AppColors.accent.withValues(alpha: 0.2) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              selected ? activeIcon : inactiveIcon,
              color: selected ? AppColors.accent : inactiveColor,
              size: selected ? 22 : 20,
            ),
          ),
          const SizedBox(height: 2),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 10,
              color: selected ? AppColors.accent : inactiveColor,
              fontWeight: selected ? FontWeight.bold : FontWeight.w500,
              letterSpacing: 0.2,
              height: 1.2,
            ),
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
