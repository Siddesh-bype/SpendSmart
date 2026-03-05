import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/app_settings_provider.dart';
import 'utils/theme.dart';
import 'screens/splash_screen.dart';

class SpendSmartApp extends ConsumerWidget {
  const SpendSmartApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);

    ThemeMode themeMode = ThemeMode.system;
    if (settings.theme == 'light') themeMode = ThemeMode.light;
    if (settings.theme == 'dark') themeMode = ThemeMode.dark;

    return MaterialApp(
      title: 'SpendSmart',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
