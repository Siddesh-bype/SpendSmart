class AppSettings {
  final String currency;
  final double monthlyIncome;
  final String theme;
  final bool onboardingDone;
  final int startingDayOfMonth;

  AppSettings({
    this.currency = '₹',
    this.monthlyIncome = 0.0,
    this.theme = 'system',
    this.onboardingDone = false,
    this.startingDayOfMonth = 1,
  });

  AppSettings copyWith({
    String? currency,
    double? monthlyIncome,
    String? theme,
    bool? onboardingDone,
    int? startingDayOfMonth,
  }) {
    return AppSettings(
      currency: currency ?? this.currency,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      theme: theme ?? this.theme,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      startingDayOfMonth: startingDayOfMonth ?? this.startingDayOfMonth,
    );
  }
}
