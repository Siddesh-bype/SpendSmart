import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/expense_category_resolver.dart';
import 'custom_category_provider.dart';

final expenseCategoryCatalogProvider = Provider<ExpenseCategoryCatalog>((ref) {
  return ExpenseCategoryCatalog(ref.watch(customCategoryProvider));
});
