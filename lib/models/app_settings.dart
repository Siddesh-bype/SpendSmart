class AppSettings {
  final String currency;
  final double monthlyBudget;
  final String theme;
  final bool onboardingDone;
  final int startingDayOfMonth;
  final bool aiCategorizeConsent;
  final String username;
  final String passwordHash;
  final String passwordSalt;

  /// Master key wrapped by the password, and by the recovery code. Both
  /// unwrap to the same key, so either secret opens the data.
  final String wrappedKeyByPassword;
  final String wrappedKeyByRecovery;
  final String recoverySalt;

  /// AI account session. Empty when signed out, which disables the network AI
  /// features; everything computed on-device keeps working either way.
  final String aiSessionToken;
  final String aiAccountEmail;

  /// True once a username and password have been set up.
  bool get hasAccount => username.isNotEmpty && passwordHash.isNotEmpty;

  /// True when the Hive boxes are encrypted. Installs created before
  /// encryption shipped have an account but no wrapped key.
  bool get isEncrypted => wrappedKeyByPassword.isNotEmpty;

  /// True when network AI features are available.
  bool get hasAiAccess => aiSessionToken.isNotEmpty;

  AppSettings({
    this.currency = '₹',
    this.monthlyBudget = 0.0,
    this.theme = 'system',
    this.onboardingDone = false,
    this.startingDayOfMonth = 1,
    this.aiCategorizeConsent = false,
    this.username = '',
    this.passwordHash = '',
    this.passwordSalt = '',
    this.wrappedKeyByPassword = '',
    this.wrappedKeyByRecovery = '',
    this.recoverySalt = '',
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
    String? username,
    String? passwordHash,
    String? passwordSalt,
    String? wrappedKeyByPassword,
    String? wrappedKeyByRecovery,
    String? recoverySalt,
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
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      passwordSalt: passwordSalt ?? this.passwordSalt,
      wrappedKeyByPassword:
          wrappedKeyByPassword ?? this.wrappedKeyByPassword,
      wrappedKeyByRecovery: wrappedKeyByRecovery ?? this.wrappedKeyByRecovery,
      recoverySalt: recoverySalt ?? this.recoverySalt,
      aiSessionToken: aiSessionToken ?? this.aiSessionToken,
      aiAccountEmail: aiAccountEmail ?? this.aiAccountEmail,
    );
  }
}
