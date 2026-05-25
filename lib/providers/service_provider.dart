import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';

/// Must be overridden in main.dart with an initialized StorageService instance.
/// Accessing this before the override will throw an UnimplementedError.
final storageServiceProvider = Provider<StorageService>((ref) {
  throw UnimplementedError(
    'storageServiceProvider was not initialized. '
    'Call ProviderScope(overrides: [storageServiceProvider.overrideWithValue(...)]) in main.dart.',
  );
});
