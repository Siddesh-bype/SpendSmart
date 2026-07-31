class AppSettings {
  final String currency;
  final double monthlyBudget;
  final String theme;
  final bool onboardingDone;
  final int startingDayOfMonth;
  final String aiWorkerUrl;
  final String aiProxyToken;
  final bool aiCategorizeConsent;
  final String username;
  final String passwordHash;
  final String passwordSalt;

  /// True once a username and password have been set up.
  bool get hasAccount => username.isNotEmpty && passwordHash.isNotEmpty;

  AppSettings({
    this.currency = '₹',
    this.monthlyBudget = 0.0,
    this.theme = 'system',
    this.onboardingDone = false,
    this.startingDayOfMonth = 1,
    this.aiWorkerUrl = '',
    this.aiProxyToken = '',
    this.aiCategorizeConsent = false,
    this.username = '',
    this.passwordHash = '',
    this.passwordSalt = '',
  });

  AppSettings copyWith({
    String? currency,
    double? monthlyBudget,
    String? theme,
    bool? onboardingDone,
    int? startingDayOfMonth,
    String? aiWorkerUrl,
    String? aiProxyToken,
    bool? aiCategorizeConsent,
    String? username,
    String? passwordHash,
    String? passwordSalt,
  }) {
    return AppSettings(
      currency: currency ?? this.currency,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      theme: theme ?? this.theme,
      onboardingDone: onboardingDone ?? this.onboardingDone,
      startingDayOfMonth: startingDayOfMonth ?? this.startingDayOfMonth,
      aiWorkerUrl: aiWorkerUrl ?? this.aiWorkerUrl,
      aiProxyToken: aiProxyToken ?? this.aiProxyToken,
      aiCategorizeConsent: aiCategorizeConsent ?? this.aiCategorizeConsent,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
    );
  }
}
