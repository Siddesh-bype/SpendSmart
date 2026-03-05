import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_settings_provider.dart';

class SpendingGoal {
  final double monthlyLimit;
  final bool enabled;

  const SpendingGoal({required this.monthlyLimit, required this.enabled});
}

final spendingGoalProvider = NotifierProvider<SpendingGoalNotifier, SpendingGoal>(
  SpendingGoalNotifier.new,
);

class SpendingGoalNotifier extends Notifier<SpendingGoal> {
  @override
  SpendingGoal build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return SpendingGoal(
      monthlyLimit: prefs.getDouble('goal_monthly_limit') ?? 0,
      enabled: prefs.getBool('goal_enabled') ?? false,
    );
  }

  Future<void> setGoal(double limit) async {
    await ref.read(sharedPreferencesProvider).setDouble('goal_monthly_limit', limit);
    await ref.read(sharedPreferencesProvider).setBool('goal_enabled', true);
    state = SpendingGoal(monthlyLimit: limit, enabled: true);
  }

  Future<void> disableGoal() async {
    await ref.read(sharedPreferencesProvider).setBool('goal_enabled', false);
    state = SpendingGoal(monthlyLimit: state.monthlyLimit, enabled: false);
  }
}
