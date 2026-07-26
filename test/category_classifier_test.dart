import 'package:flutter_test/flutter_test.dart';
import 'package:spendsmart/models/category.dart';
import 'package:spendsmart/services/category_classifier.dart';

void main() {
  group('normalizeMerchant', () {
    test('strips rail prefix, UPI handle, digit run and reference suffix', () {
      expect(
        CategoryClassifier.normalizeMerchant(
          'UPI-SWIGGY-9876543210@ybl-REF123456',
        ),
        'swiggy',
      );
    });

    test('strips leading payment-rail prefixes', () {
      expect(CategoryClassifier.normalizeMerchant('UPI-ZOMATO'), 'zomato');
      expect(CategoryClassifier.normalizeMerchant('POS AMAZON'), 'amazon');
      expect(
        CategoryClassifier.normalizeMerchant('NEFT-RELIANCE FRESH'),
        'reliance fresh',
      );
      expect(CategoryClassifier.normalizeMerchant('IMPS/RTGS/UBER'), 'uber');
    });

    test('keeps a rail word that is not in leading position', () {
      expect(
        CategoryClassifier.normalizeMerchant('AUTOPAY MANDATE'),
        'autopay mandate',
      );
    });

    test('drops the UPI handle and everything after it', () {
      expect(CategoryClassifier.normalizeMerchant('swiggy@ybl'), 'swiggy');
      expect(
        CategoryClassifier.normalizeMerchant('netflix@okhdfcbank'),
        'netflix',
      );
    });

    test('removes digit runs of five or more', () {
      expect(
        CategoryClassifier.normalizeMerchant('AMAZON 1234567890 PAY'),
        'amazon pay',
      );
      expect(
        CategoryClassifier.normalizeMerchant('STORE 42 MALL'),
        'store 42 mall',
      );
    });

    test('trims trailing reference markers', () {
      expect(CategoryClassifier.normalizeMerchant('ZOMATO REF123456'), 'zomato');
      expect(CategoryClassifier.normalizeMerchant('UBER TXN 99'), 'uber');
      expect(CategoryClassifier.normalizeMerchant('MYNTRA UTR 7788'), 'myntra');
    });

    test('treats separator punctuation as whitespace', () {
      expect(
        CategoryClassifier.normalizeMerchant(r'BIG*BAZAAR/STORE|#3'),
        'big bazaar store',
      );
    });

    test('collapses whitespace and lowercases', () {
      expect(
        CategoryClassifier.normalizeMerchant('   SwIgGy    InStAmArT  '),
        'swiggy instamart',
      );
    });

    test('strips trailing corporate suffixes', () {
      expect(CategoryClassifier.normalizeMerchant('SWIGGY LTD'), 'swiggy');
      expect(CategoryClassifier.normalizeMerchant('Swiggy Pvt Ltd'), 'swiggy');
      expect(
        CategoryClassifier.normalizeMerchant('ACME PRIVATE LIMITED'),
        'acme',
      );
      expect(CategoryClassifier.normalizeMerchant('Acme Inc.'), 'acme');
      expect(CategoryClassifier.normalizeMerchant('ACME LLP'), 'acme');
      expect(CategoryClassifier.normalizeMerchant('Acme LLC'), 'acme');
      expect(CategoryClassifier.normalizeMerchant('ACME CORP'), 'acme');
      expect(CategoryClassifier.normalizeMerchant('Acme PLC'), 'acme');
      expect(CategoryClassifier.normalizeMerchant('SWIGGY PVT.LTD.'), 'swiggy');
    });

    test('strips a corporate suffix under a rail prefix and reference', () {
      expect(
        CategoryClassifier.normalizeMerchant('UPI-SWIGGY PVT LTD-123456'),
        'swiggy',
      );
    });

    test('strips a suffix only in trailing position', () {
      expect(
        CategoryClassifier.normalizeMerchant('LTD COFFEE'),
        'ltd coffee',
      );
      expect(
        CategoryClassifier.normalizeMerchant('PRIVATE HOSPITAL'),
        'private hospital',
      );
    });

    test('a suffix-only descriptor keeps a token instead of emptying', () {
      expect(CategoryClassifier.normalizeMerchant('LTD'), 'ltd');
      expect(CategoryClassifier.normalizeMerchant('PVT LTD'), 'pvt');
      expect(CategoryClassifier.normalizeMerchant('Private Limited'), 'private');
    });

    test('returns empty string for empty or garbage input', () {
      expect(CategoryClassifier.normalizeMerchant(''), '');
      expect(CategoryClassifier.normalizeMerchant('     '), '');
      expect(CategoryClassifier.normalizeMerchant('---///***'), '');
      expect(CategoryClassifier.normalizeMerchant('1234567890'), '');
      expect(CategoryClassifier.normalizeMerchant('UPI-REF123'), '');
    });
  });

  group('classify happy paths', () {
    void expectKeyword(String raw, Category expected) {
      final result = CategoryClassifier.classify(raw);
      expect(result.category, expected, reason: raw);
      expect(result.isConfident, isTrue, reason: raw);
      expect(result.source, ClassificationSource.keyword, reason: raw);
    }

    test('matches one merchant per category', () {
      expectKeyword('UPI-SWIGGY-9876543210@ybl', Category.food);
      expectKeyword('UBER TRIP', Category.transport);
      expectKeyword('AMAZON PAY', Category.shopping);
      expectKeyword('APOLLO PHARMACY', Category.health);
      expectKeyword('NETFLIX SUBSCRIPTION', Category.entertainment);
      expectKeyword('AIRTEL BROADBAND', Category.bills);
    });

    test('exposes the normalized merchant alongside the category', () {
      final result = CategoryClassifier.classify(
        'UPI-SWIGGY-9876543210@ybl-REF123456',
      );

      expect(result.category, Category.food);
      expect(result.normalizedMerchant, 'swiggy');
    });

    test('never reports the merchantMemory source', () {
      const inputs = ['UPI-SWIGGY', 'Food', 'ACME WIDGETS', ''];

      for (final input in inputs) {
        expect(
          CategoryClassifier.classify(input).source,
          isNot(ClassificationSource.merchantMemory),
          reason: input,
        );
      }
    });
  });

  group('exact category name (CSV Category column)', () {
    test('an exact displayName stays confident regardless of case', () {
      for (final category in Category.values) {
        final result = CategoryClassifier.classify(category.displayName);

        expect(result.category, category);
        expect(result.isConfident, isTrue);
        expect(result.source, ClassificationSource.keyword);
      }

      final lower = CategoryClassifier.classify('bills');
      expect(lower.category, Category.bills);
      expect(lower.isConfident, isTrue);
      expect(lower.source, ClassificationSource.keyword);
    });

    test('an exact "Other" is confident, unlike the fallback', () {
      final named = CategoryClassifier.classify('Other');
      expect(named.category, Category.other);
      expect(named.isConfident, isTrue);
      expect(named.source, ClassificationSource.keyword);
    });
  });

  group('fallback', () {
    test('an unknown merchant is unconfident other', () {
      final result = CategoryClassifier.classify('UPI-ACME WIDGETS-REF123456');

      expect(result.category, Category.other);
      expect(result.isConfident, isFalse);
      expect(result.source, ClassificationSource.fallback);
      expect(result.normalizedMerchant, 'acme widgets');
    });

    test('empty input falls back with an empty merchant', () {
      final result = CategoryClassifier.classify('');

      expect(result.category, Category.other);
      expect(result.isConfident, isFalse);
      expect(result.source, ClassificationSource.fallback);
      expect(result.normalizedMerchant, '');
    });

    test('education keywords deliberately fall through', () {
      for (final keyword in CategoryClassifier.educationKeywords) {
        final result = CategoryClassifier.classify(keyword);

        expect(result.category, Category.other, reason: keyword);
        expect(result.isConfident, isFalse, reason: keyword);
        expect(result.source, ClassificationSource.fallback, reason: keyword);
      }
    });
  });

  group('substring collisions', () {
    test('"coca cola" is not transport', () {
      final result = CategoryClassifier.classify('coca cola');

      expect(result.category, isNot(Category.transport));
      expect(result.category, Category.other);
      expect(result.isConfident, isFalse);
    });

    test('"jiomart" is shopping, not bills', () {
      expect(CategoryClassifier.classify('jiomart').category, Category.shopping);
      expect(
        CategoryClassifier.classify('JioMart Groceries').category,
        Category.shopping,
      );
    });

    test('"business" is not transport', () {
      for (final input in ['business', 'businessworld', 'BUSINESSWORLD MAG']) {
        final result = CategoryClassifier.classify(input);

        expect(result.category, isNot(Category.transport), reason: input);
        expect(result.category, Category.other, reason: input);
        expect(result.isConfident, isFalse, reason: input);
      }
    });

    test('ola merchants still resolve to transport', () {
      for (final input in ['OLACABS', 'Ola Cabs', 'UPI-OLA-123']) {
        expect(
          CategoryClassifier.classify(input).category,
          Category.transport,
          reason: input,
        );
      }
    });

    test('bus merchants still resolve to transport', () {
      for (final input in ['REDBUS', 'redbus booking', 'BUS TICKET']) {
        expect(
          CategoryClassifier.classify(input).category,
          Category.transport,
          reason: input,
        );
      }
    });

    test('jio telecom still resolves to bills', () {
      for (final input in ['JIO RECHARGE', 'Jio Fiber', 'JIOFIBER']) {
        expect(
          CategoryClassifier.classify(input).category,
          Category.bills,
          reason: input,
        );
      }
    });
  });

  group('precedence and whole-word rules', () {
    test('the longest keyword wins', () {
      expect(
        CategoryClassifier.classify('UPI AUTOPAY-NETFLIX').category,
        Category.entertainment,
      );
      expect(
        CategoryClassifier.classify('swiggy instamart').category,
        Category.food,
      );
    });

    test('"eat" does not match inside "theatre"', () {
      expect(
        CategoryClassifier.classify('PVR Theatre').category,
        Category.entertainment,
      );
    });

    test('"auto" does not match inside "autopay"', () {
      final result = CategoryClassifier.classify('AUTOPAY MANDATE');

      expect(result.category, isNot(Category.transport));
      expect(result.category, Category.other);
      expect(result.isConfident, isFalse);
    });

    test('"rent" does not match inside "parent"', () {
      expect(
        CategoryClassifier.classify('PARENT TEACHER MEET').category,
        isNot(Category.bills),
      );
      expect(
        CategoryClassifier.classify('HOUSE RENT').category,
        Category.bills,
      );
    });

    test('"vi" matches only as a standalone word', () {
      expect(
        CategoryClassifier.classify('VI POSTPAID').category,
        Category.bills,
      );
      expect(
        CategoryClassifier.classify('VIDEOCON SERVICE').category,
        isNot(Category.bills),
      );
    });
  });
}
