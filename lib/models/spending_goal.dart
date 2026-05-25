/// Model class for a user's monthly spending goal.
/// Separated from [SpendingGoalNotifier] to enforce SoC.
class SpendingGoal {
  final double monthlyLimit;
  final bool enabled;

  const SpendingGoal({required this.monthlyLimit, required this.enabled});

  SpendingGoal copyWith({double? monthlyLimit, bool? enabled}) => SpendingGoal(
        monthlyLimit: monthlyLimit ?? this.monthlyLimit,
        enabled: enabled ?? this.enabled,
      );
}
