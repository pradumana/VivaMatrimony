import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/constants/app_constants.dart';

/// Stores only app-level data that the Supabase SDK does not manage.
/// JWT tokens and session state are fully owned by supabase_flutter.
class SecureStorage {
  final FlutterSecureStorage _storage;
  const SecureStorage(this._storage);

  // ── Member ID ────────────────────────────────────────────────────────────
  Future<void> saveMemberId(String memberId) =>
      _storage.write(key: AppConstants.memberIdKey, value: memberId);

  Future<String?> getMemberId() =>
      _storage.read(key: AppConstants.memberIdKey);

  // ── Onboarding state ─────────────────────────────────────────────────────
  Future<void> setOnboardingCompleted(bool completed) =>
      _storage.write(
        key: AppConstants.onboardingCompletedKey,
        value: completed.toString(),
      );

  Future<bool> isOnboardingCompleted() async {
    final val = await _storage.read(key: AppConstants.onboardingCompletedKey);
    return val == 'true';
  }

  // ── Clear all app-level local data on logout ─────────────────────────────
  Future<void> clearAppData() => Future.wait([
        _storage.delete(key: AppConstants.memberIdKey),
        _storage.delete(key: AppConstants.onboardingCompletedKey),
      ]);
}

// ponytail: encryptedSharedPreferences=false — see original comment.
// Only non-sensitive app metadata (memberId, onboarding flag) stored here.
// Supabase SDK stores its own tokens in its own secure storage.
final secureStorageProvider = Provider<SecureStorage>(
  (_) => const SecureStorage(FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
  )),
);
