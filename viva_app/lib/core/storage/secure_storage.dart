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

final secureStorageProvider = Provider<SecureStorage>(
  (ref) => const SecureStorage(FlutterSecureStorage(
    aOptions: AndroidOptions(
      // ponytail: encryptedSharedPreferences disabled — Android Keystore init
      // hangs on first launch on many devices with older AndroidX Security.
      // Tokens are stored in unencrypted SharedPreferences on Android (readable
      // on rooted devices). Upgrade path: test with AndroidX Security 1.1.0+
      // and re-enable once confirmed stable on target device matrix.
      encryptedSharedPreferences: false,
    ),
  )),
);
