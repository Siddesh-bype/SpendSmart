import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/app_settings_provider.dart';
import 'providers/service_provider.dart';
import 'services/storage_service.dart';
import 'utils/theme.dart';
import 'utils/globals.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Local Storage Init ─────────────────────────────────
  final prefs = await SharedPreferences.getInstance();
  final storageService = StorageService();
  await storageService.init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const SpendSmartApp(),
    ),
  );
}

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
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      home: const SplashScreen(),
    );
  }
}
