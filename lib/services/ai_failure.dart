import 'dart:io';

/// Why an AI call failed, in terms the user can act on.
///
/// The services used to collapse every non-200 into one "unavailable" message,
/// which told a signed-out user to check a Worker URL they never configured and
/// told a rate-limited user nothing about waiting.
enum AiFailure {
  /// Session missing, expired, or revoked. Sign in again.
  signedOut,

  /// Daily quota spent. Nothing to fix; come back tomorrow.
  quotaExhausted,

  /// Worker or upstream model is down. Retrying later may work.
  serverError,

  /// Anything else, including a malformed response.
  unknown,
}

class AiFailureException implements Exception {
  const AiFailureException(this.failure, this.message);

  final AiFailure failure;
  final String message;

  /// Maps an HTTP status to the reason and a message the UI can show as-is.
  factory AiFailureException.fromStatus(int status) => switch (status) {
    HttpStatus.unauthorized || HttpStatus.forbidden => const AiFailureException(
      AiFailure.signedOut,
      'Your AI session has expired. Sign in again from Settings.',
    ),
    HttpStatus.tooManyRequests => const AiFailureException(
      AiFailure.quotaExhausted,
      "You've used today's AI allowance. It resets tomorrow.",
    ),
    >= 500 => const AiFailureException(
      AiFailure.serverError,
      'The AI service is having trouble. Try again in a few minutes.',
    ),
    _ => const AiFailureException(
      AiFailure.unknown,
      'AI is unavailable right now. Try again.',
    ),
  };

  @override
  String toString() => message;
}
