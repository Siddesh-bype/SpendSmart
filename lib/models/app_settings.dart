class AppSettings {
  final String currency;
  final double monthlyBudget;
  final String theme;
  final bool onboardingDone;
  final int startingDayOfMonth;
  final String aiWorkerUrl;
  final String aiProxyToken;

  AppSettings({
    this.currency = '₹',
    this.monthlyBudget = 0.0,
    this.theme = 'system',
    this.onboardingDone = false,
    this.startingDayOfMonth = 1,
    this.aiWorkerUrl = '',
    this.aiProxyToken = '',
  });

  AppSettings copyWith({
    String? currency,
    double? monthlyBudget,
    String? theme,
    bool? onboardingDone,
    int? startingDayOfMonth,
    String? aiWorkerUrl,
    String? aiProxyToken,
  }) {
    return AppSettings(
      currency: currency ?? this.currency,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      theme: theme ?? this.theme,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      startingDayOfMonth: startingDayOfMonth ?? this.startingDayOfMonth,
      aiWorkerUrl: aiWorkerUrl ?? this.aiWorkerUrl,
      aiProxyToken: aiProxyToken ?? this.aiProxyToken,
    );
  }
}
