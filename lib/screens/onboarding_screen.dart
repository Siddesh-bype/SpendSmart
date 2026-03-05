import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/constants.dart';
import '../providers/app_settings_provider.dart';
import 'main_scaffold.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _page = 0;

  final List<_OnboardPage> _pages = [
    _OnboardPage(
      icon: Icons.sms,
      title: 'Auto-detect UPI Payments',
      desc: 'Instantly read SMS for UPI transactions and automatically log your expenses without lifting a finger.',
    ),
    _OnboardPage(
      icon: Icons.pie_chart,
      title: 'Smart Spending Analytics',
      desc: 'See exactly where your money goes with beautiful charts and category-wise breakdowns.',
    ),
    _OnboardPage(
      icon: Icons.account_balance_wallet,
      title: 'Set Budgets & Goals',
      desc: 'Set monthly budgets for each category and get alerts before you overspend.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 48),
            const Text(
              'SpendSmart',
              style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Your personal expense tracker',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 48),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _pages.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (_, i) => _buildPage(_pages[i]),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_pages.length, (i) => AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: _page == i ? 24 : 8,
                height: 8,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: _page == i ? AppColors.primary : Colors.grey,
                ),
              )),
            ),
            const SizedBox(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Consumer(builder: (context, ref, _) {
                return ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: () async {
                    if (_page < _pages.length - 1) {
                      _controller.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      await ref.read(appSettingsProvider.notifier).completeOnboarding();
                      if (!context.mounted) return;
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(builder: (_) => const MainScaffold()),
                      );
                    }
                  },
                  child: Text(
                    _page < _pages.length - 1 ? 'Next' : 'Get Started',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                );
              }),
            ),
            const SizedBox(height: 32),
          ],
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
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(page.icon, size: 56, color: AppColors.primary),
          ),
          const SizedBox(height: 32),
          Text(page.title, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 16),
          Text(page.desc, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, color: Colors.grey, height: 1.5)),
        ],
      ),
    );
  }
}

class _OnboardPage {
  final IconData icon;
  final String title;
  final String desc;
  const _OnboardPage({required this.icon, required this.title, required this.desc});
}
