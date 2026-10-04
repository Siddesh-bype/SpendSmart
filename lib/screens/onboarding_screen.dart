import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/theme.dart';
import '../utils/design.dart';
import '../providers/app_settings_provider.dart';
import '../providers/service_provider.dart';
import 'main_scaffold.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _page = 0;

  late final AnimationController _pageAnimCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  // Pages made static const — no rebuild overhead.
  // Copy is frozen by screen_visibility_test ('Track Every Expense' must stay,
  // no mention of SMS detection). Colors resolve per-theme at build time.
  static const _pages = [
    _OnboardPage(
      icon: Icons.add_card_outlined,
      title: 'Track Every Expense',
      desc:
          'Add expenses manually or import compatible bank statements and CSV files when you are ready.',
    ),
    _OnboardPage(
      icon: Icons.pie_chart,
      title: 'Smart Spending Analytics',
      desc:
          'See exactly where your money goes with beautiful charts and category-wise breakdowns.',
    ),
    _OnboardPage(
      icon: Icons.account_balance_wallet,
      title: 'Set Budgets & Goals',
      desc:
          'Set monthly budgets for each category and get alerts before you overspend.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _pageAnimCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _pageAnimCtrl, curve: Curves.easeOutCubic),
        );
    _pageAnimCtrl.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _pageAnimCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int i) {
    HapticFeedback.selectionClick();
    setState(() => _page = i);
    _pageAnimCtrl.forward(from: 0);
  }

  /// Completes onboarding and opens the app.
  ///
  /// No password is asked for here: the lock is optional and lives in Settings.
  /// Requiring one before the first expense would gate the whole app on a
  /// decision the user has no context for yet.
  Future<void> _finish() async {
    HapticFeedback.mediumImpact();
    await ref.read(appSettingsProvider.notifier).completeOnboarding();
    await ref.read(storageServiceProvider).init();
    if (!mounted) return;
    Navigator.of(
      context,
    ).pushReplacement(MaterialPageRoute(builder: (_) => const MainScaffold()));
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;
    final scheme = SchemeTheme.of(context);

    return PopScope(
      canPop: _page == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _page > 0) {
          _controller.previousPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      },
      child: Scaffold(
        backgroundColor: scheme.bg,
        body: SafeArea(
          child: Column(
            children: [
              // Header row with app name + Skip button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'SpendSmart',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: AppType.title,
                          fontWeight: FontWeight.bold,
                          color: scheme.ink,
                          letterSpacing: 0,
                        ),
                      ),
                    ),
                    if (!isLast)
                      TextButton(
                        style: TextButton.styleFrom(
                          foregroundColor: scheme.muted,
                          minimumSize: const Size(64, 44),
                        ),
                        onPressed: _finish,
                        child: const Text(
                          'Skip',
                          style: TextStyle(fontSize: AppType.body),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Your personal expense tracker',
                    style: TextStyle(color: scheme.muted, fontSize: AppType.label),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Animated page content
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _pages.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (_, i) => SlideTransition(
                    position: _slideAnim,
                    child: FadeTransition(
                      opacity: _fadeAnim,
                      child: _buildPage(scheme, _pages[i]),
                    ),
                  ),
                ),
              ),

              // Dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _page == i ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      color: _page == i
                          ? scheme.primary
                          : scheme.muted.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Next / Get Started — ref accessed directly via ConsumerState
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: scheme.ctaFill,
                    foregroundColor: scheme.ctaText,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppRadius.mdAll,
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    if (!isLast) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      _finish();
                    }
                  },
                  child: Text(
                    isLast ? 'Get Started' : 'Next',
                    style: TextStyle(
                      fontSize: AppType.headline,
                      fontWeight: FontWeight.bold,
                      color: scheme.ctaText,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(SchemeTheme scheme, _OnboardPage page) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.border,
                  width: 1,
                ),
              ),
              child: Icon(page.icon, size: 56, color: scheme.primary),
            ),
            const SizedBox(height: 40),
            Text(
              page.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppType.title,
                fontWeight: FontWeight.bold,
                color: scheme.ink,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              page.desc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: AppType.body,
                color: scheme.muted,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final String title;
  final String desc;
  const _OnboardPage({
    required this.icon,
    required this.title,
    required this.desc,
  });
}
