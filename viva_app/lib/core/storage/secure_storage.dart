import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../shared/constants/app_constants.dart';

/// Secure token storage for JWT tokens and user session.
class SecureStorage {
  final FlutterSecureStorage _storage;

  const SecureStorage(this._storage);

  static const FlutterSecureStorage _instance = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: false),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  // ── Token management ─────────────────────────────────────────────────────

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
    required String userId,
  }) async {
    await Future.wait([
      _storage.write(key: AppConstants.accessTokenKey, value: accessToken),
      _storage.write(key: AppConstants.refreshTokenKey, value: refreshToken),
      _storage.write(key: AppConstants.userIdKey, value: userId),
    ]);
  }

  Future<String?> getAccessToken() =>
      _storage.read(key: AppConstants.accessTokenKey);

  Future<String?> getRefreshToken() =>
      _storage.read(key: AppConstants.refreshTokenKey);

  Future<String?> getUserId() =>
      _storage.read(key: AppConstants.userIdKey);

  Future<bool> hasValidSession() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: AppConstants.accessTokenKey),
      _storage.delete(key: AppConstants.refreshTokenKey),
      _storage.delete(key: AppConstants.userIdKey),
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
      // encryptedSharedPreferences causes Android Keystore init to hang on
      // first launch on many devices. Disabled for reliability.
      encryptedSharedPreferences: false,
    ),
  )),
);
