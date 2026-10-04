import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'home_screen.dart';
import 'analytics_screen.dart';
import 'budget_screen.dart';
import 'settings_screen.dart';
import 'groups_screen.dart';
import '../utils/design.dart';
import '../utils/theme.dart';
import '../providers/recurring_expense_provider.dart';
import '../providers/expense_provider.dart';

class MainScaffold extends ConsumerStatefulWidget {
  const MainScaffold({super.key});

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    AnalyticsScreen(),
    BudgetScreen(),
    GroupsScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Generate any overdue recurring expenses on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref
          .read(recurringExpenseProvider.notifier)
          .generateDueExpenses(ref.read(expenseProvider.notifier));
    });
  }

  void _onTabTap(int index) {
    if (_currentIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = SchemeTheme.of(context);

    return Scaffold(
      extendBody: false,
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(top: BorderSide(color: scheme.border, width: 1)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                Expanded(
                  child: _navItem(
                    0,
                    Icons.home_rounded,
                    Icons.home_outlined,
                    'Home',
                    scheme,
                  ),
                ),
                Expanded(
                  child: _navItem(
                    1,
                    Icons.pie_chart_rounded,
                    Icons.pie_chart_outline_rounded,
                    'Analytics',
                    scheme,
                  ),
                ),
                Expanded(
                  child: _navItem(
                    2,
                    Icons.account_balance_wallet_rounded,
                    Icons.account_balance_wallet_outlined,
                    'Budget',
                    scheme,
                  ),
                ),
                Expanded(
                  child: _navItem(
                    3,
                    Icons.groups_rounded,
                    Icons.groups_outlined,
                    'Groups',
                    scheme,
                  ),
                ),
                Expanded(
                  child: _navItem(
                    4,
                    Icons.settings_rounded,
                    Icons.settings_outlined,
                    'Settings',
                    scheme,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Returns inner widget only; Expanded wrapper is applied at call site.
  Widget _navItem(
    int index,
    IconData activeIcon,
    IconData inactiveIcon,
    String label,
    SchemeTheme scheme,
  ) {
    final selected = _currentIndex == index;

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkResponse(
          onTap: () => _onTabTap(index),
          radius: 28,
          splashColor: scheme.primary.withValues(alpha: 0.20),
          highlightColor: scheme.primary.withValues(alpha: 0.10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: AppDuration.base,
                curve: Curves.easeOutExpo,
                padding: EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: selected ? 6 : 4,
                ),
                decoration: BoxDecoration(
                  color: selected ? scheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  selected ? activeIcon : inactiveIcon,
                  color: selected ? scheme.ctaText : scheme.muted,
                  size: selected ? 22 : 20,
                ),
              ),
              const SizedBox(height: 2),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  fontSize: AppType.micro,
                  color: selected ? scheme.primary : scheme.muted,
                  fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                  letterSpacing: 0.2,
                  height: 1.2,
                ),
                child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
