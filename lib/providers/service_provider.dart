import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/storage_service.dart';
import '../services/sms_service.dart';

final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

final smsServiceProvider = Provider<SMSService>((ref) {
  return SMSService(ref);
});
