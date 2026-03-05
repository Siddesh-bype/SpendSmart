class AppSettings {
  final String currency;
  final double monthlyIncome;
  final String theme;
  final bool onboardingDone;

  AppSettings({
    this.currency = '₹',
    this.monthlyIncome = 0.0,
    this.theme = 'system',
    this.onboardingDone = false,
  });

  AppSettings copyWith({
    String? currency,
    double? monthlyIncome,
    String? theme,
    bool? onboardingDone,
  }) {
    return AppSettings(
      currency: currency ?? this.currency,
      monthlyIncome: monthlyIncome ?? this.monthlyIncome,
      theme: theme ?? this.theme,
      onboardingDone: onboardingDone ?? this.onboardingDone,
    );
  }
}
