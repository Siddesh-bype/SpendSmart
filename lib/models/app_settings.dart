class AppSettings {
  final String currency;
  final double monthlyBudget;
  final String theme;
  final bool onboardingDone;
  final int startingDayOfMonth;
  final bool aiCategorizeConsent;

  /// AI account session. Empty when signed out, which disables the network AI
  /// features; everything computed on-device keeps working either way.
  final String aiSessionToken;
  final String aiAccountEmail;

  /// True when network AI features are available.
  bool get hasAiAccess => aiSessionToken.isNotEmpty;

  AppSettings({
    this.currency = '₹',
    this.monthlyBudget = 0.0,
    this.theme = 'system',
    this.onboardingDone = false,
    this.startingDayOfMonth = 1,
    this.aiCategorizeConsent = false,
    this.aiSessionToken = '',
    this.aiAccountEmail = '',
  });

  AppSettings copyWith({
    String? currency,
    double? monthlyBudget,
    String? theme,
    bool? onboardingDone,
    int? startingDayOfMonth,
    bool? aiCategorizeConsent,
    String? aiSessionToken,
    String? aiAccountEmail,
  }) {
    return AppSettings(
      currency: currency ?? this.currency,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      theme: theme ?? this.theme,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      startingDayOfMonth: startingDayOfMonth ?? this.startingDayOfMonth,
      aiCategorizeConsent: aiCategorizeConsent ?? this.aiCategorizeConsent,
      aiSessionToken: aiSessionToken ?? this.aiSessionToken,
      aiAccountEmail: aiAccountEmail ?? this.aiAccountEmail,
    );
  }
}
