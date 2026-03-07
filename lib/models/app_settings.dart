class AppSettings {
  final String currency;
  final double monthlyBudget;
  final String theme;
  final bool onboardingDone;
  final int startingDayOfMonth;

  AppSettings({
    this.currency = '₹',
    this.monthlyBudget = 0.0,
    this.theme = 'system',
    this.onboardingDone = false,
    this.startingDayOfMonth = 1,
  });

  AppSettings copyWith({
    String? currency,
    double? monthlyBudget,
    String? theme,
    bool? onboardingDone,
    int? startingDayOfMonth,
  }) {
    return AppSettings(
      currency: currency ?? this.currency,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      theme: theme ?? this.theme,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      startingDayOfMonth: startingDayOfMonth ?? this.startingDayOfMonth,
    );
  }
}
