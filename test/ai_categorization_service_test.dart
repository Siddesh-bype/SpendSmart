import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/services/ai_categorization_service.dart';
import 'package:spendsmart/services/ai_failure.dart';

void main() {
  group('parseResponse', () {
    test('maps display names back to categories and flags high confidence', () {
      final results = AiCategorizationService.parseResponse('''
        {
          "results":[
            {"merchant":"SWIGGY","category":"Food","confidence":"high"},
            {"merchant":"UBER TRIP","category":"Transport","confidence":"low"},
            {"merchant":"APOLLO","category":"Health","confidence":"medium"}
          ]
        }
      ''');

      expect(results.length, 3);
      expect(results.first.merchant, 'SWIGGY');
      expect(results.first.category, Category.food);
      expect(results.first.confidence, 'high');
      expect(results.first.isHighConfidence, isTrue);
      expect(results[1].category, Category.transport);
      expect(results[1].isHighConfidence, isFalse);
      expect(results[2].category, Category.health);
      expect(results[2].isHighConfidence, isFalse);
    });

    test('accepts every allowed display name', () {
      for (final category in Category.values) {
        final results = AiCategorizationService.parseResponse(
          '{"results":[{"merchant":"X","category":"${category.displayName}",'
          '"confidence":"high"}]}',
        );
        expect(results.single.category, category);
      }
    });

    test('empty results is a valid answer, not an error', () {
      expect(AiCategorizationService.parseResponse('{"results":[]}'), isEmpty);
    });

    test('unknown category is rejected', () {
      expect(
        () => AiCategorizationService.parseResponse(
          '{"results":[{"merchant":"X","category":"Groceries",'
          '"confidence":"high"}]}',
        ),
        throwsFormatException,
      );
      expect(
        () => AiCategorizationService.parseResponse(
          '{"results":[{"merchant":"X","category":"food","confidence":"high"}]}',
        ),
        throwsFormatException,
      );
    });

    test('bad confidence is rejected', () {
      expect(
        () => AiCategorizationService.parseResponse(
          '{"results":[{"merchant":"X","category":"Food",'
          '"confidence":"certain"}]}',
        ),
        throwsFormatException,
      );
      expect(
        () => AiCategorizationService.parseResponse(
          '{"results":[{"merchant":"X","category":"Food","confidence":1}]}',
        ),
        throwsFormatException,
      );
    });

    test('non-object root is rejected', () {
      expect(
        () => AiCategorizationService.parseResponse('[]'),
        throwsFormatException,
      );
      expect(
        () => AiCategorizationService.parseResponse('"results"'),
        throwsFormatException,
      );
      expect(
        () => AiCategorizationService.parseResponse('7'),
        throwsFormatException,
      );
    });

    test('missing or non-list results is rejected', () {
      expect(
        () => AiCategorizationService.parseResponse('{}'),
        throwsFormatException,
      );
      expect(
        () => AiCategorizationService.parseResponse('{"results":{}}'),
        throwsFormatException,
      );
      expect(
        () => AiCategorizationService.parseResponse('{"results":null}'),
        throwsFormatException,
      );
    });

    test('malformed entries are rejected', () {
      expect(
        () => AiCategorizationService.parseResponse('{"results":["Food"]}'),
        throwsFormatException,
      );
      expect(
        () => AiCategorizationService.parseResponse(
          '{"results":[{"category":"Food","confidence":"high"}]}',
        ),
        throwsFormatException,
      );
      expect(
        () => AiCategorizationService.parseResponse(
          '{"results":[{"merchant":"  ","category":"Food",'
          '"confidence":"high"}]}',
        ),
        throwsFormatException,
      );
    });

    test('more results than a batch can hold is rejected', () {
      final entries = List.generate(
        51,
        (index) =>
            '{"merchant":"M$index","category":"Food","confidence":"low"}',
      ).join(',');
      expect(
        () => AiCategorizationService.parseResponse('{"results":[$entries]}'),
        throwsFormatException,
      );
    });

    test('garbage input is rejected', () {
      expect(
        () => AiCategorizationService.parseResponse('not json at all'),
        throwsFormatException,
      );
      expect(
        () => AiCategorizationService.parseResponse(''),
        throwsFormatException,
      );
    });

    test('oversized input is rejected before decoding', () {
      final oversized = '{"results":[]}${' ' * (12 * 1024)}';
      expect(
        () => AiCategorizationService.parseResponse(oversized),
        throwsFormatException,
      );
    });
  });

  group('buildBatches', () {
    test('trims, drops empties and dedupes case-insensitively', () {
      final batches = AiCategorizationService.buildBatches([
        '  Swiggy  ',
        'SWIGGY',
        'swiggy',
        '',
        '   ',
        'Uber',
      ]);

      expect(batches.length, 1);
      expect(batches.single, ['Swiggy', 'Uber']);
    });

    test('drops entries longer than 64 characters after trim', () {
      final exactly64 = 'a' * 64;
      final tooLong = 'b' * 65;
      final batches = AiCategorizationService.buildBatches([
        exactly64,
        tooLong,
        '  ${'c' * 64}  ',
        '${'d' * 65} ',
      ]);

      expect(batches.single, [exactly64, 'c' * 64]);
    });

    test('no merchants produces no batches', () {
      expect(AiCategorizationService.buildBatches([]), isEmpty);
      expect(AiCategorizationService.buildBatches(['', '  ']), isEmpty);
    });

    test('exactly 50 merchants is a single batch', () {
      final batches = AiCategorizationService.buildBatches(
        List.generate(50, (index) => 'Merchant $index'),
      );

      expect(batches.length, 1);
      expect(batches.single.length, 50);
    });

    test('51 merchants splits into 50 and 1', () {
      final batches = AiCategorizationService.buildBatches(
        List.generate(51, (index) => 'Merchant $index'),
      );

      expect(batches.map((batch) => batch.length), [50, 1]);
      expect(batches.last.single, 'Merchant 50');
    });

    test('hundreds of merchants chunk without loss or duplication', () {
      final input = List.generate(230, (index) => 'Merchant $index');
      final batches = AiCategorizationService.buildBatches([
        ...input,
        ...input.map((merchant) => merchant.toUpperCase()),
      ]);

      expect(batches.map((batch) => batch.length), [50, 50, 50, 50, 30]);
      final flattened = batches.expand((batch) => batch).toList();
      expect(flattened, input);
      expect(flattened.toSet().length, 230);
      expect(batches.every((batch) => batch.length <= 50), isTrue);
    });
  });

  group('categorizeEndpoint', () {
    test('replaces the analyze-spending segment', () {
      expect(
        AiCategorizationService.categorizeEndpoint(
          Uri.parse('https://ai.example.workers.dev/analyze-spending'),
        ).toString(),
        'https://ai.example.workers.dev/categorize',
      );
    });

    test('handles a trailing slash', () {
      expect(
        AiCategorizationService.categorizeEndpoint(
          Uri.parse('https://ai.example.workers.dev/analyze-spending/'),
        ).toString(),
        'https://ai.example.workers.dev/categorize',
      );
    });

    test('preserves a nested base path', () {
      expect(
        AiCategorizationService.categorizeEndpoint(
          Uri.parse('https://ai.example.workers.dev/v1/analyze-spending'),
        ).toString(),
        'https://ai.example.workers.dev/v1/categorize',
      );
    });

    test('appends when the URL does not end in analyze-spending', () {
      expect(
        AiCategorizationService.categorizeEndpoint(
          Uri.parse('https://ai.example.workers.dev/api'),
        ).toString(),
        'https://ai.example.workers.dev/api/categorize',
      );
      expect(
        AiCategorizationService.categorizeEndpoint(
          Uri.parse('https://ai.example.workers.dev/'),
        ).toString(),
        'https://ai.example.workers.dev/categorize',
      );
      expect(
        AiCategorizationService.categorizeEndpoint(
          Uri.parse('https://ai.example.workers.dev'),
        ).toString(),
        'https://ai.example.workers.dev/categorize',
      );
    });

    test('keeps the port and drops query and fragment', () {
      expect(
        AiCategorizationService.categorizeEndpoint(
          Uri.parse('https://localhost:8787/analyze-spending?debug=1#top'),
        ).toString(),
        'https://localhost:8787/categorize',
      );
    });
  });

  group('buildRequest and guards', () {
    test('request carries only the merchants array', () {
      final request = AiCategorizationService.buildRequest(['Swiggy', 'Uber']);

      expect(request.keys, ['merchants']);
      expect(request['merchants'], ['Swiggy', 'Uber']);
    });

    test('non-https endpoint is rejected before any network call', () {
      expect(
        () => AiCategorizationService.categorize(
          endpoint: Uri.parse('http://ai.example.workers.dev/categorize'),
          proxyToken: 'x' * 32,
          merchants: const ['Swiggy'],
        ),
        throwsFormatException,
      );
      expect(
        () => AiCategorizationService.categorize(
          endpoint: Uri.parse('https:///categorize'),
          proxyToken: 'x' * 32,
          merchants: const ['Swiggy'],
        ),
        throwsFormatException,
      );
    });

    test('short proxy token is rejected before any network call', () {
      expect(
        () => AiCategorizationService.categorize(
          endpoint: Uri.parse('https://ai.example.workers.dev/categorize'),
          proxyToken: 'short',
          merchants: const ['Swiggy'],
        ),
        throwsFormatException,
      );
    });

    test('empty or oversized batch is rejected before any network call', () {
      expect(
        () => AiCategorizationService.categorize(
          endpoint: Uri.parse('https://ai.example.workers.dev/categorize'),
          proxyToken: 'x' * 32,
          merchants: const [],
        ),
        throwsFormatException,
      );
      expect(
        () => AiCategorizationService.categorize(
          endpoint: Uri.parse('https://ai.example.workers.dev/categorize'),
          proxyToken: 'x' * 32,
          merchants: List.generate(51, (index) => 'Merchant $index'),
        ),
        throwsFormatException,
      );
    });
  });

  group('AiFailureException.fromStatus', () {
    test('separates the states the user can act on', () {
      // 401/403 must not read as "the service is down": the fix is signing in.
      expect(AiFailureException.fromStatus(401).failure, AiFailure.signedOut);
      expect(AiFailureException.fromStatus(403).failure, AiFailure.signedOut);
      expect(
        AiFailureException.fromStatus(429).failure,
        AiFailure.quotaExhausted,
      );
      expect(AiFailureException.fromStatus(500).failure, AiFailure.serverError);
      expect(AiFailureException.fromStatus(503).failure, AiFailure.serverError);
      expect(AiFailureException.fromStatus(418).failure, AiFailure.unknown);
    });

    test('every message tells the user what to do next', () {
      for (final status in [401, 429, 500, 418]) {
        expect(AiFailureException.fromStatus(status).message, isNotEmpty);
      }
    });
  });
}
