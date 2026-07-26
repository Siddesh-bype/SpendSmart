import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/category.dart';
import '../models/expense.dart';
import '../utils/date_extension.dart';

class AiSpendingInsight {
  const AiSpendingInsight({
    required this.title,
    required this.detail,
    required this.tone,
  });

  final String title;
  final String detail;
  final String tone;
}

class AiSpendingForecast {
  const AiSpendingForecast({
    required this.projectedSpend,
    required this.status,
    required this.confidence,
  });

  final double? projectedSpend;
  final String status;
  final String confidence;
}

class AiSpendingAnomaly {
  const AiSpendingAnomaly({
    required this.category,
    required this.currentAmount,
    required this.baselineAmount,
    required this.severity,
  });

  final String category;
  final double currentAmount;
  final double baselineAmount;
  final String severity;
}

class AiSpendingAnalysis {
  const AiSpendingAnalysis({
    required this.summary,
    required this.forecast,
    required this.anomalies,
    required this.insights,
  });

  final String summary;
  final AiSpendingForecast forecast;
  final List<AiSpendingAnomaly> anomalies;
  final List<AiSpendingInsight> insights;
}

class AiSpendingAnalysisService {
  static const _maxResponseBytes = 12 * 1024;

  static Map<String, dynamic> buildRequest({
    required Iterable<Expense> expenses,
    required String currency,
    required double monthlyBudget,
    required int startingDayOfMonth,
    DateTime? now,
  }) {
    final date = now ?? DateTime.now();
    final periodStart = _periodStart(date, startingDayOfMonth);
    final periodEnd = DateTime(
      periodStart.year,
      periodStart.month + 1,
      startingDayOfMonth,
    ).subtract(const Duration(days: 1));
    final today = DateTime(date.year, date.month, date.day);
    final totalDays = periodEnd.difference(periodStart).inDays + 1;
    final daysElapsed = today.difference(periodStart).inDays + 1;

    final currentMonth = _monthSummary(
      expenses,
      periodStart,
      startingDayOfMonth,
    );
    final history = List.generate(
      3,
      (index) => _monthSummary(
        expenses,
        DateTime(periodStart.year, periodStart.month - index - 1),
        startingDayOfMonth,
      ),
    );

    return {
      'currency': currency,
      'monthlyBudget': monthlyBudget,
      'period': {
        'daysElapsed': daysElapsed,
        'daysRemaining': totalDays - daysElapsed,
        'totalDays': totalDays,
      },
      'currentMonth': currentMonth,
      'history': history,
    };
  }

  static DateTime _periodStart(DateTime date, int startingDayOfMonth) {
    return date.day >= startingDayOfMonth
        ? DateTime(date.year, date.month, startingDayOfMonth)
        : DateTime(date.year, date.month - 1, startingDayOfMonth);
  }

  static Map<String, dynamic> _monthSummary(
    Iterable<Expense> expenses,
    DateTime month,
    int startingDayOfMonth,
  ) {
    final totals = <String, double>{};
    for (final expense in expenses) {
      if (expense.isUncategorized ||
          !expense.date.isTargetCustomMonth(
            month.month,
            month.year,
            startingDayOfMonth,
          )) {
        continue;
      }
      final name = expense.category.displayName;
      totals[name] = (totals[name] ?? 0) + expense.amount;
    }
    final rounded = totals.map(
      (key, value) => MapEntry(key, value.roundToDouble()),
    );
    return {
      'total': rounded.values.fold(0.0, (sum, amount) => sum + amount),
      'categories': rounded,
    };
  }

  static Future<AiSpendingAnalysis> analyze({
    required Uri endpoint,
    required String proxyToken,
    required Map<String, dynamic> request,
  }) async {
    if (endpoint.scheme != 'https' || endpoint.host.isEmpty) {
      throw const FormatException('An HTTPS Worker URL is required.');
    }
    if (proxyToken.trim().length < 16) {
      throw const FormatException('A valid proxy token is required.');
    }

    final client = HttpClient();
    try {
      final call = await client
          .postUrl(endpoint)
          .timeout(const Duration(seconds: 15));
      call.headers.contentType = ContentType.json;
      call.headers.set(HttpHeaders.authorizationHeader, 'Bearer $proxyToken');
      call.add(utf8.encode(jsonEncode(request)));

      final response = await call.close().timeout(const Duration(seconds: 20));
      final body = await _readBounded(response);
      if (response.statusCode != HttpStatus.ok) {
        throw const HttpException('AI analysis is temporarily unavailable.');
      }
      return parseResponse(body);
    } on TimeoutException {
      throw const HttpException('AI analysis timed out.');
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

  static AiSpendingAnalysis parseResponse(String response) {
    final decoded = jsonDecode(response);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Invalid AI response.');
    }
    final summary = _text(decoded['summary'], 600);
    final forecast = _forecast(decoded['forecast']);
    final anomalies = _anomalies(decoded['anomalies']);
    final rawInsights = decoded['insights'];
    if (summary == null ||
        forecast == null ||
        anomalies == null ||
        rawInsights is! List) {
      throw const FormatException('Invalid AI response.');
    }

    final insights = <AiSpendingInsight>[];
    for (final item in rawInsights.take(4)) {
      if (item is! Map<String, dynamic>) continue;
      final title = _text(item['title'], 80);
      final detail = _text(item['detail'], 260);
      final tone = item['tone'];
      if (title == null ||
          detail == null ||
          tone is! String ||
          !{'positive', 'neutral', 'warning'}.contains(tone)) {
        continue;
      }
      insights.add(AiSpendingInsight(title: title, detail: detail, tone: tone));
    }
    if (insights.isEmpty) throw const FormatException('Invalid AI response.');
    return AiSpendingAnalysis(
      summary: summary,
      forecast: forecast,
      anomalies: anomalies,
      insights: insights,
    );
  }

  static AiSpendingForecast? _forecast(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final projectedSpend = value['projectedSpend'];
    final status = value['status'];
    final confidence = value['confidence'];
    if ((projectedSpend != null &&
            (projectedSpend is! num ||
                !projectedSpend.isFinite ||
                projectedSpend < 0)) ||
        status is! String ||
        confidence is! String ||
        !{
          'withinBudget',
          'atRisk',
          'overBudget',
          'unavailable',
        }.contains(status) ||
        !{'low', 'medium', 'high', 'unavailable'}.contains(confidence)) {
      return null;
    }
    return AiSpendingForecast(
      projectedSpend: projectedSpend?.toDouble(),
      status: status,
      confidence: confidence,
    );
  }

  static List<AiSpendingAnomaly>? _anomalies(Object? value) {
    if (value is! List || value.length > 3) return null;
    final anomalies = <AiSpendingAnomaly>[];
    for (final item in value) {
      if (item is! Map<String, dynamic>) return null;
      final category = _text(item['category'], 30);
      final currentAmount = item['currentAmount'];
      final baselineAmount = item['baselineAmount'];
      final severity = item['severity'];
      if (category == null ||
          currentAmount is! num ||
          baselineAmount is! num ||
          !currentAmount.isFinite ||
          !baselineAmount.isFinite ||
          currentAmount < 0 ||
          baselineAmount < 0 ||
          severity is! String ||
          !{'warning', 'critical'}.contains(severity)) {
        return null;
      }
      anomalies.add(
        AiSpendingAnomaly(
          category: category,
          currentAmount: currentAmount.toDouble(),
          baselineAmount: baselineAmount.toDouble(),
          severity: severity,
        ),
      );
    }
    return anomalies;
  }

  static String? _text(Object? value, int maxLength) {
    if (value is! String) return null;
    final text = value.trim();
    return text.isEmpty || text.length > maxLength ? null : text;
  }
}
