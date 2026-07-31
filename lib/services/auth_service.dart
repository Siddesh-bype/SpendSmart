import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../utils/constants.dart';

/// A signed-in AI account.
class AiAccount {
  const AiAccount({
    required this.token,
    required this.email,
    required this.expiresAt,
    this.displayName,
  });

  final String token;
  final String email;
  final int expiresAt;
  final String? displayName;

  bool get isExpired => DateTime.now().millisecondsSinceEpoch >= expiresAt;
}

/// Today's AI usage against the account's daily allowance.
class AiUsage {
  const AiUsage({
    required this.email,
    required this.callsToday,
    required this.dailyLimit,
    this.displayName,
  });

  final String email;
  final int callsToday;
  final int dailyLimit;
  final String? displayName;

  int get remaining => (dailyLimit - callsToday).clamp(0, dailyLimit);
}

/// Raised when the server rejects the request for a reason worth showing the
/// user, e.g. a wrong password. The message comes from the Worker, which is
/// careful not to reveal whether an address is registered.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Client for the Worker's account routes.
///
/// Signing in unlocks the AI features only. Expenses stay on-device and are
/// never uploaded, so being signed out costs nothing but AI.
class AuthService {
  static const Duration _connectTimeout = Duration(seconds: 15);
  static const Duration _responseTimeout = Duration(seconds: 20);
  static const int _maxResponseBytes = 8 * 1024;

  const AuthService._();

  static Uri _endpoint(String path) =>
      Uri.parse('${AppConfig.workerBaseUrl}$path');

  static Future<AiAccount> signup({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final json = await _post('/auth/signup', {
      'email': email.trim(),
      'password': password,
      if (displayName != null && displayName.trim().isNotEmpty)
        'displayName': displayName.trim(),
    });
    return _accountFrom(json, fallbackEmail: email);
  }

  static Future<AiAccount> login({
    required String email,
    required String password,
  }) async {
    final json = await _post('/auth/login', {
      'email': email.trim(),
      'password': password,
    });
    return _accountFrom(json, fallbackEmail: email);
  }

  /// Best-effort: a failure here still means the client should drop its token.
  static Future<void> logout(String token) async {
    try {
      await _post('/auth/logout', const {}, token: token);
    } catch (_) {
      // The local token is cleared regardless.
    }
  }

  static Future<AiUsage> me(String token) async {
    final json = await _get('/auth/me', token);
    return AiUsage(
      email: (json['email'] as String?) ?? '',
      displayName: json['displayName'] as String?,
      callsToday: (json['callsToday'] as num?)?.toInt() ?? 0,
      dailyLimit: (json['dailyLimit'] as num?)?.toInt() ?? 0,
    );
  }

  static AiAccount _accountFrom(
    Map<String, dynamic> json, {
    required String fallbackEmail,
  }) {
    final token = json['token'];
    if (token is! String || token.isEmpty) {
      throw const AuthFailure('The server did not return a session.');
    }
    return AiAccount(
      token: token,
      email: (json['email'] as String?) ?? fallbackEmail.trim().toLowerCase(),
      displayName: json['displayName'] as String?,
      expiresAt: (json['expiresAt'] as num?)?.toInt() ?? 0,
    );
  }

  static Future<Map<String, dynamic>> _post(
    String path,
    Map<String, dynamic> body, {
    String? token,
  }) async {
    final client = HttpClient();
    try {
      final call = await client
          .postUrl(_endpoint(path))
          .timeout(_connectTimeout);
      call.headers.contentType = ContentType.json;
      if (token != null) {
        call.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      call.add(utf8.encode(jsonEncode(body)));
      return _decode(await call.close().timeout(_responseTimeout));
    } on TimeoutException {
      throw const AuthFailure('The server took too long to respond.');
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> _get(String path, String token) async {
    final client = HttpClient();
    try {
      final call = await client.getUrl(_endpoint(path)).timeout(_connectTimeout);
      call.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      return _decode(await call.close().timeout(_responseTimeout));
    } on TimeoutException {
      throw const AuthFailure('The server took too long to respond.');
    } finally {
      client.close(force: true);
    }
  }

  static Future<Map<String, dynamic>> _decode(
    HttpClientResponse response,
  ) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > _maxResponseBytes) {
        throw const AuthFailure('The server response was too large.');
      }
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      json = null;
    }

    if (response.statusCode == HttpStatus.ok) {
      if (json == null) throw const AuthFailure('Unexpected server response.');
      return json;
    }
    // Prefer the server's wording: it is deliberately worded to avoid
    // revealing whether an account exists.
    throw AuthFailure(
      (json?['error'] as String?) ?? 'Could not reach the AI service.',
    );
  }
}
