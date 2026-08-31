import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/constants/app_constants.dart';

/// Secure token storage for JWT tokens and user session.
class SecureStorage {
  final FlutterSecureStorage _storage;

  const SecureStorage(this._storage);

  // ── Token management ─────────────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
    String? memberId,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.accessTokenKey, value: accessToken),
      _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken),
      _storage.write(key: AppConstants.userIdKey, value: userId),
      if (memberId != null)
        _storage.write(key: AppConstants.memberIdKey, value: memberId),
    ]);
  }

  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.accessTokenKey);

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.refreshTokenKey);

  Future<String?> getUserId() =>
      _storage.read(key: AppConstants.userIdKey);

  Future<String?> getMemberId() =>
      _storage.read(key: AppConstants.memberIdKey);

  Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: AppConstants.accessTokenKey),
      _storage.delete(key: AppConstants.refreshTokenKey),
      _storage.delete(key: AppConstants.userIdKey),
      _storage.delete(key: AppConstants.memberIdKey),
    ]);
  }

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
}

// ── Android security note ────────────────────────────────────────────────────
// ponytail: encryptedSharedPreferences=false — known ceiling: JWTs (access +
// refresh), userId, and memberId are stored in unencrypted SharedPreferences on
// Android, which is readable on a rooted device by any root-privileged process.
// On non-rooted stock Android the data is sandboxed per-app and safe in practice.
// iOS is unaffected — flutter_secure_storage always uses the iOS Keychain there.
//
// WHY it is off: AndroidX Security Keystore initialisation hangs on first launch
// across a range of devices running older AndroidX Security versions, causing a
// blank screen on cold start.
//
// UPGRADE PATH when ready:
//   1. Bump androidx.security:security-crypto to 1.1.0+ in android/build.gradle.
//   2. Flip encryptedSharedPreferences: true below.
//   3. Handle the one-time migration: existing plaintext prefs are NOT migrated
//      automatically — call clearSession() on the first launch after the upgrade
//      so users re-authenticate cleanly rather than hitting a decrypt error.
//   4. Smoke-test on low-end Android 6–8 devices before shipping.
// ─────────────────────────────────────────────────────────────────────────────
final secureStorageProvider = Provider<SecureStorage>(
  (ref) => const SecureStorage(FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: false, // see note above before enabling
    ),
  )),
);
