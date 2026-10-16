import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/design.dart';
import '../utils/theme.dart';
import '../providers/service_provider.dart';
import 'main_scaffold.dart';
import 'onboarding_screen.dart';
import '../providers/app_settings_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _anim;
  late Animation<double> _scale;
  late Animation<double> _fade;
  bool _reduceMotion = false;
  bool _motionPreferenceResolved = false;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _scale = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic));
    _fade = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _anim, curve: Curves.easeIn));

    // The provider container is only accessed after the widget is mounted.
    // Scheduling this independently of didChangeDependencies also handles the
    // normal-motion case, where the initial preference value is false.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _navigate();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = AppMotion.reduced(context);
    if (_motionPreferenceResolved && _reduceMotion == reduceMotion) return;
    _reduceMotion = reduceMotion;
    _motionPreferenceResolved = true;
    if (reduceMotion) {
      _anim.value = 1;
    } else if (!_anim.isAnimating && _anim.value == 0) {
      _anim.forward();
    }
  }

  Future<void> _navigate() async {
    final container = ProviderScope.containerOf(context, listen: false);
    final storageInit = container.read(storageServiceProvider).init();
    final minimumSplash = Future<void>.delayed(
      _reduceMotion ? Duration.zero : const Duration(milliseconds: 700),
    );
    await Future.wait([storageInit, minimumSplash]);

    if (!mounted) return;
    final settings = container.read(appSettingsProvider);
    final routeDuration = AppMotion.duration(
      context,
      const Duration(milliseconds: 220),
    );
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: routeDuration,
        reverseTransitionDuration: routeDuration,
        pageBuilder: (_, _, _) => settings.onboardingDone
            ? const MainScaffold()
            : const OnboardingScreen(),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = SchemeTheme.of(context);
    return Scaffold(
      backgroundColor: scheme.bg,
      body: Center(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.5),
                        blurRadius: 32,
                        spreadRadius: 4,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 110,
                      height: 110,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text('SpendSmart', style: theme.textTheme.displayMedium),
                const SizedBox(height: 8),
                Text(
                  'Your personal expense tracker',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: scheme.muted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
