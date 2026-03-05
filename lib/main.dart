import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'app.dart';
import 'providers/app_settings_provider.dart';
import 'providers/service_provider.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'utils/supabase_config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ── Supabase Init ──────────────────────────────────────
  // Fill in your URL and anon key in lib/utils/supabase_config.dart
  if (SupabaseConfig.url != 'YOUR_SUPABASE_URL') {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      anonKey: SupabaseConfig.anonKey,
    );
  }

  // ── Local Storage Init ─────────────────────────────────
  final prefs = await SharedPreferences.getInstance();

  // Generate a stable anonymous user ID (stored in prefs)
  String userId = prefs.getString('user_id') ?? '';
  if (userId.isEmpty) {
    userId = const Uuid().v4();
    await prefs.setString('user_id', userId);
  }
  SupabaseService.setUserId(userId);

  final storageService = StorageService();
  await storageService.init();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        storageServiceProvider.overrideWithValue(storageService),
      ],
      child: const SpendSmartApp(),
    ),
  );
}
