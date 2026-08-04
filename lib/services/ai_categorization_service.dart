import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/category.dart';
import 'ai_failure.dart';

class MerchantSuggestion {
  const MerchantSuggestion({
    required this.merchant,
    required this.category,
    required this.confidence,
  });

  /// Echoed back by the Worker byte-for-byte, so it matches a string that
  /// [AiCategorizationService.buildBatches] produced.
  final String merchant;

  final Category category;

  final String confidence; // 'low' | 'medium' | 'high'

  bool get isHighConfidence => confidence == 'high';
}

/// Client for the Worker's `/categorize` route.
///
/// Pure Dart apart from the one network method: no Hive, no Riverpod, no
/// widgets, so [buildBatches], [buildRequest], [parseResponse] and
/// [categorizeEndpoint] are testable with zero setup.
class AiCategorizationService {
  static const _maxResponseBytes = 12 * 1024;
  static const _maxBatchSize = 50;
  static const _maxMerchantLength = 64;
  static const _confidenceLevels = {'low', 'medium', 'high'};

  static final Map<String, Category> _categoriesByName = {
    for (final category in Category.values) category.displayName: category,
  };

  /// Settings stores one URL pointing at `.../analyze-spending`; `/categorize`
  /// lives beside it. Replaces the last path segment, or appends when the URL
  /// does not end in `analyze-spending`.
  static Uri categorizeEndpoint(Uri analyzeEndpoint) {
    final segments = analyzeEndpoint.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList();
    if (segments.isNotEmpty && segments.last == 'analyze-spending') {
      segments.removeLast();
    }
    segments.add('categorize');
    return Uri(
      scheme: analyzeEndpoint.scheme,
      userInfo: analyzeEndpoint.userInfo,
      host: analyzeEndpoint.host,
      port: analyzeEndpoint.hasPort ? analyzeEndpoint.port : null,
      pathSegments: segments,
    );
  }

  /// Trimmed, deduped, chunked into requests of at most 50 merchants.
  ///
  /// Trimming is mandatory, not cosmetic: the Worker keys its reply by the
  /// exact string it received, and a model that trims an untrimmed input makes
  /// the result unmatchable, so it gets dropped server-side.
  ///
  /// Entries longer than 64 characters after trim are **dropped, not
  /// truncated**, so every string sent is byte-for-byte one of the caller's
  /// inputs and results join back without a lookup table.
  static List<List<String>> buildBatches(Iterable<String> merchants) {
    final seen = <String>{};
    final unique = <String>[];
    for (final merchant in merchants) {
      final text = merchant.trim();
      if (text.isEmpty || text.length > _maxMerchantLength) continue;
      if (!seen.add(text.toLowerCase())) continue;
      unique.add(text);
    }

    final batches = <List<String>>[];
    for (var start = 0; start < unique.length; start += _maxBatchSize) {
      final end = start + _maxBatchSize;
      batches.add(
        unique.sublist(start, end > unique.length ? unique.length : end),
      );
    }
    return batches;
  }

  static Map<String, dynamic> buildRequest(List<String> batch) => {
    'merchants': batch,
  };

  /// One request for one batch from [buildBatches].
  static Future<List<MerchantSuggestion>> categorize({
    required Uri endpoint,
    required String proxyToken,
    required List<String> merchants,
  }) async {
    if (endpoint.scheme != 'https' || endpoint.host.isEmpty) {
      throw const FormatException('An HTTPS Worker URL is required.');
    }
    if (proxyToken.trim().length < 16) {
      throw const FormatException('A valid session token is required.');
    }
    if (merchants.isEmpty || merchants.length > _maxBatchSize) {
      throw const FormatException('A batch of 1-50 merchants is required.');
    }

    final client = HttpClient();
    try {
      final call = await client
          .postUrl(endpoint)
          .timeout(const Duration(seconds: 15));
      call.headers.contentType = ContentType.json;
      call.headers.set(HttpHeaders.authorizationHeader, 'Bearer $proxyToken');
      call.add(utf8.encode(jsonEncode(buildRequest(merchants))));

      final response = await call.close().timeout(const Duration(seconds: 20));
      final body = await _readBounded(response);
      if (response.statusCode != HttpStatus.ok) {
        throw AiFailureException.fromStatus(response.statusCode);
      }
      return parseResponse(body);
    } on TimeoutException {
      throw const AiFailureException(
        AiFailure.serverError,
        'AI categorization timed out. Try again.',
      );
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _readBounded(HttpClientResponse response) async {
    final bytes = <int>[];
    await for (final chunk in response) {
      bytes.addAll(chunk);
      if (bytes.length > _maxResponseBytes) {
        throw const FormatException('AI response was too large.');
      }
    }
    return utf8.decode(bytes);
  }

  /// An empty `results` list is a valid answer meaning "no suggestions".
  static List<MerchantSuggestion> parseResponse(String response) {
    if (response.length > _maxResponseBytes) {
      throw const FormatException('AI response was too large.');
    }
    final decoded = jsonDecode(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid AI response.');
    }
    final results = decoded['results'];
    if (results is! List || results.length > _maxBatchSize) {
      throw const FormatException('Invalid AI response.');
    }

    final suggestions = <MerchantSuggestion>[];
    for (final item in results) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('Invalid AI response.');
      }
      final merchant = _text(item['merchant'], _maxMerchantLength);
      final categoryName = _text(item['category'], 20);
      final confidence = item['confidence'];
      final category = categoryName == null
          ? null
          : _categoriesByName[categoryName];
      if (merchant == null ||
          category == null ||
          confidence is! String ||
          !_confidenceLevels.contains(confidence)) {
        throw const FormatException('Invalid AI response.');
      }
      suggestions.add(
        MerchantSuggestion(
          merchant: merchant,
          category: category,
          confidence: confidence,
        ),
      );
    }
    return suggestions;
  }

  static String? _text(Object? value, int maxLength) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty || text.length > maxLength ? null : text;
  }
}
