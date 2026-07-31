import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/app_settings_provider.dart';
import 'providers/service_provider.dart';
import 'screens/splash_screen.dart';
import 'services/storage_service.dart';
import 'utils/globals.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  // Boxes are NOT opened here: when a lock is set up the encryption key is
  // derived from the password, which does not exist until the user unlocks.
  // StorageService.init is called from the login/signup screens instead.
  final storageService = StorageService();

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
