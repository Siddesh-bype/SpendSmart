class AppSettings {
  final String currency;
  final double monthlyBudget;
  final String theme;
  final bool onboardingDone;
  final int startingDayOfMonth;
  final bool aiCategorizeConsent;

  /// AI account session. Empty when signed out, which disables the network AI
  /// features; everything computed on-device keeps working either way.
  ///
  /// The token itself is held in the Keystore by `SessionStore` and only
  /// mirrored here for the widgets to read.
  final String aiSessionToken;
  final String aiAccountEmail;

  /// Unix milliseconds. 0 means unknown, which is treated as still valid: the
  /// server is the authority and answers 401 when it disagrees.
  final int aiSessionExpiresAt;

  /// True when the session has an end date that has already passed.
  bool aiSessionExpired([DateTime? now]) =>
      aiSessionExpiresAt > 0 &&
      (now ?? DateTime.now()).millisecondsSinceEpoch >= aiSessionExpiresAt;

  /// True when network AI features are available.
  bool get hasAiAccess => aiSessionToken.isNotEmpty && !aiSessionExpired();

  AppSettings({
    this.currency = '₹',
    this.monthlyBudget = 0.0,
    this.theme = 'system',
    this.onboardingDone = false,
    this.startingDayOfMonth = 1,
    this.aiCategorizeConsent = false,
    this.aiSessionToken = '',
    this.aiAccountEmail = '',
    this.aiSessionExpiresAt = 0,
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
    int? aiSessionExpiresAt,
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
      aiSessionExpiresAt: aiSessionExpiresAt ?? this.aiSessionExpiresAt,
    );
  }
}
