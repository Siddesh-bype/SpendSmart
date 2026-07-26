import '../models/category.dart';

/// Where a [ClassificationResult] came from.
enum ClassificationSource {
  /// Resolved from the learned merchant -> category store.
  ///
  /// [CategoryClassifier] never returns this value: it holds no state and
  /// knows nothing about past corrections. Callers that consult the learned
  /// store before falling back to [CategoryClassifier.classify] report it.
  merchantMemory,

  /// Matched an exact category name or a keyword rule.
  keyword,

  /// Nothing matched; the category is [Category.other].
  fallback,
}

class ClassificationResult {
  const ClassificationResult({
    required this.category,
    required this.isConfident,
    required this.normalizedMerchant,
    required this.source,
  });

  final Category category;
  final bool isConfident; // false => caller sets isUncategorized = true
  final String normalizedMerchant;
  final ClassificationSource source;
}

/// Single source of truth for merchant normalization and keyword categorization.
///
/// Rules are merged from the PDF and CSV importers. Pure Dart: no Hive, no
/// Riverpod, no widgets.
class CategoryClassifier {
  /// Payment-rail prefixes stripped from the front of a descriptor.
  static const _railPrefixes = {
    'upi',
    'pos',
    'atm',
    'neft',
    'imps',
    'rtgs',
    'ach',
    'mandate',
    'bil',
    'ecom',
    'vps',
  };

  /// Trailing reference markers, e.g. `REF123456`, `TXN 99`, `UTR`.
  static const _referenceMarkers = {
    'ref',
    'refno',
    'refid',
    'txn',
    'txnid',
    'trn',
    'rrn',
    'utr',
    'ord',
    'no',
    'id',
  };

  /// Corporate/legal suffixes stripped from the end of a descriptor, so
  /// `SWIGGY LTD` and `Swiggy` land on one key. Trailing only: a merchant
  /// genuinely named `LTD COFFEE` keeps its leading token.
  static const _corporateSuffixes = {
    'ltd',
    'limited',
    'pvt',
    'private',
    'inc',
    'llp',
    'llc',
    'corp',
    'plc',
  };

  /// Education keywords carried over from `pdf_import_service`.
  ///
  /// [Category] has no education member, so that branch returned
  /// [Category.other] — the same result as the fallthrough, i.e. it was dead
  /// code. The keywords are kept here rather than duplicated as a rule that
  /// cannot change an outcome: [classify] deliberately lets them fall through
  /// to the unconfident [Category.other] result, exactly as before. Add a
  /// `Category.education` and these become a real rule group.
  static const educationKeywords = [
    'school',
    'college',
    'course',
    'udemy',
    'books',
    'education',
    'fee',
    'tuition',
  ];

  static final _upiHandle = RegExp(r'@[a-z][a-z0-9._-]*');
  static final _separators = RegExp(r'[-/_*.\\|#]+');
  static final _longDigitRun = RegExp(r'\d{5,}');
  static final _whitespace = RegExp(r'\s+');
  static final _digitsOnly = RegExp(r'^\d+$');
  static final _referenceToken = RegExp(r'^([a-z]+?)\d*$');

  /// Turns a raw bank/UPI descriptor into a stable lookup key.
  ///
  /// `UPI-SWIGGY-9876543210@ybl-REF123456` -> `swiggy`. Returns `''` when
  /// nothing survives.
  static String normalizeMerchant(String raw) {
    var text = raw.toLowerCase().trim();

    final handle = _upiHandle.firstMatch(text);
    if (handle != null) text = text.substring(0, handle.start);

    text = text.replaceAll(_separators, ' ').replaceAll(_longDigitRun, ' ');

    final tokens = text
        .split(_whitespace)
        .where((t) => t.isNotEmpty)
        .toList(growable: false);

    var start = 0;
    while (start < tokens.length && _railPrefixes.contains(tokens[start])) {
      start++;
    }
    var end = tokens.length;
    while (end > start && _isReference(tokens[end - 1])) {
      end--;
    }
    // `end > start + 1` keeps the last token: a descriptor that is only
    // suffixes (`PVT LTD`) degrades to `pvt`, not to `''`. Reference-only
    // descriptors above still normalize to `''`, as before.
    //
    // ponytail: token equality, so `PVT.LTD.` works (separators already became
    // spaces) but `P.V.T. LTD.` leaves `p v t` — per-letter dotting is rare
    // enough to not earn a regex.
    while (end > start + 1 && _corporateSuffixes.contains(tokens[end - 1])) {
      end--;
    }

    return tokens.sublist(start, end).join(' ');
  }

  /// Classifies a raw descriptor or category label.
  ///
  /// An exact [CategoryExtension.displayName] wins first (the CSV importer's
  /// behaviour for an explicit `Category` column), then keyword rules run
  /// against the normalized text, longest keyword first.
  static ClassificationResult classify(String rawText) {
    final normalized = normalizeMerchant(rawText);

    final named = _exactCategory(rawText);
    if (named != null) {
      return ClassificationResult(
        category: named,
        isConfident: true,
        normalizedMerchant: normalized,
        source: ClassificationSource.keyword,
      );
    }

    if (normalized.isNotEmpty) {
      final padded = ' $normalized ';
      for (final rule in _rules) {
        if (rule.matches(normalized, padded)) {
          return ClassificationResult(
            category: rule.category,
            isConfident: true,
            normalizedMerchant: normalized,
            source: ClassificationSource.keyword,
          );
        }
      }
    }

    // Also where [educationKeywords] land.
    return ClassificationResult(
      category: Category.other,
      isConfident: false,
      normalizedMerchant: normalized,
      source: ClassificationSource.fallback,
    );
  }

  static bool _isReference(String token) {
    if (_digitsOnly.hasMatch(token)) return true;
    final letters = _referenceToken.firstMatch(token)?.group(1);
    return letters != null && _referenceMarkers.contains(letters);
  }

  static Category? _exactCategory(String raw) {
    final lower = raw.toLowerCase().trim();
    if (lower.isEmpty) return null;
    for (final category in Category.values) {
      if (category.displayName.toLowerCase() == lower) return category;
    }
    return null;
  }

  /// Keyword rules ordered longest-first, so `swiggy instamart` cannot lose a
  /// specific merchant to a generic word. Ties keep declaration order, which
  /// follows the old `_guessCategory` precedence.
  static final List<_Rule> _rules = _sortByLength([
    // Food — pdf_import_service, plus dining/eat from csv_import_service.
    const _Rule('swiggy', Category.food),
    const _Rule('zomato', Category.food),
    const _Rule('food', Category.food),
    const _Rule('restaurant', Category.food),
    const _Rule('cafe', Category.food),
    const _Rule('starbucks', Category.food),
    const _Rule('pizza', Category.food),
    const _Rule('burger', Category.food),
    const _Rule('hotel', Category.food),
    const _Rule('dining', Category.food),
    const _Rule('eat', Category.food, wholeWord: true),

    // Transport — plus transport/travel from csv_import_service.
    const _Rule('ola', Category.transport, wholeWord: true),
    const _Rule('olacabs', Category.transport),
    const _Rule('uber', Category.transport),
    const _Rule('petrol', Category.transport),
    const _Rule('metro', Category.transport),
    const _Rule('bus', Category.transport, wholeWord: true),
    const _Rule('redbus', Category.transport),
    const _Rule('auto', Category.transport, wholeWord: true),
    const _Rule('fuel', Category.transport),
    const _Rule('irctc', Category.transport),
    const _Rule('train', Category.transport),
    const _Rule('transport', Category.transport),
    const _Rule('travel', Category.transport),

    // Shopping — plus shop/grocery/retail from csv_import_service.
    const _Rule('amazon', Category.shopping),
    const _Rule('flipkart', Category.shopping),
    const _Rule('myntra', Category.shopping),
    const _Rule('ajio', Category.shopping),
    const _Rule('meesho', Category.shopping),
    const _Rule('nykaa', Category.shopping),
    const _Rule('blinkit', Category.shopping),
    const _Rule('zepto', Category.shopping),
    const _Rule('jiomart', Category.shopping),
    const _Rule('shop', Category.shopping), // also covers 'shopping'
    const _Rule('grocery', Category.shopping),
    const _Rule('retail', Category.shopping),

    // Bills — plus bill/util/electric/rent from csv_import_service.
    const _Rule('electric', Category.bills), // also covers 'electricity'
    const _Rule('gas', Category.bills),
    const _Rule('water', Category.bills),
    const _Rule('broadband', Category.bills),
    const _Rule('internet', Category.bills),
    const _Rule('airtel', Category.bills),
    const _Rule('jio', Category.bills, wholeWord: true),
    const _Rule('jiofiber', Category.bills),
    const _Rule('vodafone', Category.bills),
    const _Rule('vi', Category.bills, wholeWord: true),
    const _Rule('bill', Category.bills),
    const _Rule('util', Category.bills),
    const _Rule('rent', Category.bills, wholeWord: true),

    // Health — 'pharma' from csv_import_service covers 'pharmacy'.
    const _Rule('hospital', Category.health),
    const _Rule('pharma', Category.health),
    const _Rule('medical', Category.health),
    const _Rule('medicine', Category.health),
    const _Rule('doctor', Category.health),
    const _Rule('clinic', Category.health),
    const _Rule('apollo', Category.health),
    const _Rule('health', Category.health),

    // Entertainment — plus entertain from csv_import_service.
    const _Rule('netflix', Category.entertainment),
    const _Rule('spotify', Category.entertainment),
    const _Rule('hotstar', Category.entertainment),
    const _Rule('prime', Category.entertainment),
    const _Rule('youtube', Category.entertainment),
    const _Rule('game', Category.entertainment),
    const _Rule('movie', Category.entertainment),
    const _Rule('pvr', Category.entertainment),
    const _Rule('inox', Category.entertainment),
    const _Rule('entertain', Category.entertainment),
  ]);

  static List<_Rule> _sortByLength(List<_Rule> rules) {
    final indexed = rules.asMap().entries.toList()
      ..sort((a, b) {
        final byLength = b.value.keyword.length.compareTo(
          a.value.keyword.length,
        );
        return byLength != 0 ? byLength : a.key.compareTo(b.key);
      });
    return List.unmodifiable(indexed.map((e) => e.value));
  }
}

/// Returns the learned category for [rawMerchant], or null when the store
/// holds no confident match.
///
/// Injected into the importers instead of letting them reach for
/// `StorageService` directly: the parsers stay pure Dart and unit-testable
/// with no Hive box open. `StorageService.lookupMerchantCategory` is the
/// production implementation.
typedef MerchantCategoryLookup = Category? Function(String rawMerchant);

/// Resolution shared by every importer: learned merchant memory outranks the
/// keyword rules, and only a total miss is left for the user to triage.
///
/// Returns the category and the `isUncategorized` flag to store with it.
(Category, bool) resolveImportedCategory(
  String rawTitle,
  MerchantCategoryLookup? memoryLookup,
) {
  final remembered = memoryLookup?.call(rawTitle);
  if (remembered != null) return (remembered, false);

  final classified = CategoryClassifier.classify(rawTitle);
  return (classified.category, !classified.isConfident);
}

class _Rule {
  const _Rule(this.keyword, this.category, {this.wholeWord = false});

  final String keyword;
  final Category category;

  /// Set for short keywords whose substring match is mostly false positives
  /// (`eat` in "theatre", `auto` in "autopay", `rent` in "parent", `ola` in
  /// "coca cola", `bus` in "business", `jio` in "jiomart", `vi` in anything).
  /// `vi` replaces the old `'vi '` literal, which relied on a trailing space
  /// that normalization removes.
  ///
  /// A word-boundary keyword loses the single-token brand spellings that its
  /// substring form used to catch, so each one is paired with explicit rules
  /// for those merchants: `olacabs`, `redbus`, `jiofiber`. The two-word forms
  /// (`ola cabs`, `redbus booking`, `jio recharge`, `jio fiber`) still match
  /// the base keyword.
  final bool wholeWord;

  bool matches(String text, String paddedText) =>
      wholeWord ? paddedText.contains(' $keyword ') : text.contains(keyword);
}
