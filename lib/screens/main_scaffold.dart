import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_screen.dart';
import 'analytics_screen.dart';
import 'budget_screen.dart';
import 'settings_screen.dart';
import 'add_expense_screen.dart';
import '../models/category.dart';
import '../utils/constants.dart';

class MainScaffold extends StatefulWidget {
  const MainScaffold({super.key});

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _quickAddOpen = false;
  late final AnimationController _fabController;
  late final AnimationController _quickAddController;

  final List<Widget> _screens = const [
    HomeScreen(),
    AnalyticsScreen(),
    BudgetScreen(),
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
    return GestureDetector(
      onTap: _quickAddOpen ? _closeQuickAdd : null,
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        body: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
          child: KeyedSubtree(
            key: ValueKey(_currentIndex),
            child: _screens[_currentIndex],
          ),
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Quick-add chips
            if (_quickAddOpen) ...[
              ...Category.values.take(6).map((cat) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ScaleTransition(
                    scale: CurvedAnimation(parent: _quickAddController, curve: Curves.easeOut),
                    child: FloatingActionButton.extended(
                      heroTag: 'quick_${cat.name}',
                      onPressed: () => _openAddExpense(initialCategory: cat),
                      backgroundColor: cat.color,
                      foregroundColor: Colors.white,
                      icon: Icon(cat.icon, size: 18),
                      label: Text(cat.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      elevation: 3,
                    ),
                  ),
                );
              }),
              const SizedBox(height: 8),
            ],
            // Main FAB
            ScaleTransition(
              scale: CurvedAnimation(parent: _fabController, curve: Curves.elasticOut),
              child: GestureDetector(
                onLongPress: _toggleQuickAdd,
                child: FloatingActionButton(
                  heroTag: 'main_fab',
                  onPressed: () {
                    if (_quickAddOpen) {
                      _closeQuickAdd();
                    } else {
                      _openAddExpense();
                    }
                  },
                  backgroundColor: AppColors.primary,
                  elevation: 6,
                  shape: const CircleBorder(),
                  child: AnimatedRotation(
                    turns: _quickAddOpen ? 0.125 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.add, color: Colors.white, size: 28),
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          elevation: 10,
          shadowColor: Colors.black26,
          child: SizedBox(
            height: 60,
            child: Row(
              children: [
                _navItem(0, Icons.home_rounded, Icons.home_outlined, 'Home'),
                _navItem(1, Icons.pie_chart_rounded, Icons.pie_chart_outline_rounded, 'Analytics'),
                const SizedBox(width: 56),
                _navItem(2, Icons.account_balance_wallet_rounded, Icons.account_balance_wallet_outlined, 'Budget'),
                _navItem(3, Icons.person_rounded, Icons.person_outline_rounded, 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData activeIcon, IconData inactiveIcon, String label) {
    final selected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onTabTap(index),
        splashColor: AppColors.primary.withValues(alpha: 0.1),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary.withValues(alpha: 0.13) : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                selected ? activeIcon : inactiveIcon,
                color: selected ? AppColors.primary : Colors.grey,
                size: 24,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 10,
                color: selected ? AppColors.primary : Colors.grey,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
