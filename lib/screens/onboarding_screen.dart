import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/constants.dart';
import '../providers/app_settings_provider.dart';
import 'main_scaffold.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _controller = PageController();
  int _page = 0;

  late final AnimationController _pageAnimCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  final List<_OnboardPage> _pages = [
    _OnboardPage(
      icon: Icons.sms,
      color: AppColors.primary,
      title: 'Auto-detect UPI Payments',
      desc: 'Instantly read SMS for UPI transactions and automatically log your expenses without lifting a finger.',
    ),
    _OnboardPage(
      icon: Icons.pie_chart,
      color: AppColors.secondary,
      title: 'Smart Spending Analytics',
      desc: 'See exactly where your money goes with beautiful charts and category-wise breakdowns.',
    ),
    _OnboardPage(
      icon: Icons.account_balance_wallet,
      color: AppColors.accent,
      title: 'Set Budgets & Goals',
      desc: 'Set monthly budgets for each category and get alerts before you overspend.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _pageAnimCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 500),
    );
    _fadeAnim  = CurvedAnimation(parent: _pageAnimCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _pageAnimCtrl, curve: Curves.easeOutCubic));
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

  Future<void> _finish(WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    await ref.read(appSettingsProvider.notifier).completeOnboarding();
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const MainScaffold()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLast = _page == _pages.length - 1;

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
        backgroundColor: AppColors.backgroundDark,
        body: SafeArea(
          child: Column(
            children: [
              // Header row with app name + Skip button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 16, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'SpendSmart',
                      style: TextStyle(
                        fontSize: 22, fontWeight: FontWeight.bold,
                        color: Colors.white, letterSpacing: -0.5,
                      ),
                    ),
                    if (!isLast)
                      Consumer(builder: (context, ref, _) {
                        return TextButton(
                          onPressed: () => _finish(ref),
                          child: const Text(
                            'Skip',
                            style: TextStyle(color: Colors.grey, fontSize: 14),
                          ),
                        );
                      }),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Your personal expense tracker',
                    style: TextStyle(color: Colors.grey, fontSize: 13),
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
                      child: _buildPage(_pages[i]),
                    ),
                  ),
                ),
              ),

              // Dot indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: _page == i ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: _page == i ? AppColors.accent : Colors.grey.shade700,
                  ),
                )),
              ),
              const SizedBox(height: 32),

              // Next / Get Started button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Consumer(builder: (context, ref, _) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: isLast ? AppColors.accent : AppColors.primary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (!isLast) {
                        _controller.nextPage(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                        );
                      } else {
                        _finish(ref);
                      }
                    },
                    child: Text(
                      isLast ? 'Get Started' : 'Next',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: page.color.withValues(alpha: 0.3), width: 2),
            ),
            child: Icon(page.icon, size: 56, color: page.color),
          ),
          const SizedBox(height: 40),
          Text(page.title, textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Text(page.desc, textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Colors.grey, height: 1.6)),
        ],
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final Color color;
  final String title;
  final String desc;
  const _OnboardPage({
    required this.icon,
    required this.color,
    required this.title,
    required this.desc,
  });
}
