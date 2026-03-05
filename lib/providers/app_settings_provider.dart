import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(AppSettingsNotifier.new);

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      currency: prefs.getString('currency') ?? '₹',
      monthlyIncome: prefs.getDouble('monthlyIncome') ?? 0.0,
      theme: prefs.getString('theme') ?? 'light',
      onboardingDone: prefs.getBool('onboardingDone') ?? false,
    );
  }

  Future<void> updateCurrency(String currency) async {
    await ref.read(sharedPreferencesProvider).setString('currency', currency);
    state = state.copyWith(currency: currency);
  }

  Future<void> updateIncome(double income) async {
    await ref.read(sharedPreferencesProvider).setDouble('monthlyIncome', income);
    state = state.copyWith(monthlyIncome: income);
  }

  Future<void> updateTheme(String theme) async {
    await ref.read(sharedPreferencesProvider).setString('theme', theme);
    state = state.copyWith(theme: theme);
  }

  Future<void> completeOnboarding() async {
    await ref.read(sharedPreferencesProvider).setBool('onboardingDone', true);
    state = state.copyWith(onboardingDone: true);
  }
}
