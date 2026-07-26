import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized');
});

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      currency: prefs.getString('currency') ?? '₹',
      monthlyBudget:
          prefs.getDouble('monthlyBudget') ??
          prefs.getDouble('monthlyIncome') ??
          0.0,
      theme: prefs.getString('theme') ?? 'system',
      onboardingDone: prefs.getBool('onboardingDone') ?? false,
      startingDayOfMonth: prefs.getInt('startingDayOfMonth') ?? 1,
      aiWorkerUrl: prefs.getString('aiWorkerUrl') ?? '',
      aiProxyToken: prefs.getString('aiProxyToken') ?? '',
    );
  }

  Future<void> updateCurrency(String currency) async {
    await ref.read(sharedPreferencesProvider).setString('currency', currency);
    state = state.copyWith(currency: currency);
  }

  Future<void> updateBudget(double budget) async {
    await ref
        .read(sharedPreferencesProvider)
        .setDouble('monthlyBudget', budget);
    state = state.copyWith(monthlyBudget: budget);
  }

  Future<void> updateTheme(String theme) async {
    await ref.read(sharedPreferencesProvider).setString('theme', theme);
    state = state.copyWith(theme: theme);
  }

  Future<void> updateStartingDay(int day) async {
    await ref.read(sharedPreferencesProvider).setInt('startingDayOfMonth', day);
    state = state.copyWith(startingDayOfMonth: day);
  }

  Future<void> completeOnboarding() async {
    await ref.read(sharedPreferencesProvider).setBool('onboardingDone', true);
    state = state.copyWith(onboardingDone: true);
  }

  Future<void> updateAiConnection(String workerUrl, String proxyToken) async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('aiWorkerUrl', workerUrl.trim());
    await prefs.setString('aiProxyToken', proxyToken.trim());
    state = state.copyWith(
      aiWorkerUrl: workerUrl.trim(),
      aiProxyToken: proxyToken.trim(),
    );
  }

  Future<void> clearAiConnection() async {
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('aiWorkerUrl');
    await prefs.remove('aiProxyToken');
    state = state.copyWith(aiWorkerUrl: '', aiProxyToken: '');
  }
}
