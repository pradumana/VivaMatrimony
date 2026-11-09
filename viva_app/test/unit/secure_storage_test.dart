// Self-check for SecureStorage Keystore-failure resilience.
//
// Verifies: when flutter_secure_storage throws (simulating a destroyed Keystore
// key after Android clear-data), SecureStorage.isOnboardingCompleted() and
// getMemberId() return safe defaults instead of rethrowing.
//
// Run with: flutter test test/unit/secure_storage_test.dart
//
// No frameworks, no fixtures. Uses flutter_test + a hand-rolled fake storage.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:viva_app/core/storage/secure_storage.dart';

void main() {
  group('SecureStorage — Keystore failure resilience', () {
    test('isOnboardingCompleted returns false when storage throws', () async {
      final storage = SecureStorage(_ThrowingSecureStorage());
      final result = await storage.isOnboardingCompleted();
      expect(result, false,
          reason: 'must default to false; must not rethrow PlatformException');
    });

    test('getMemberId returns null when storage throws', () async {
      final storage = SecureStorage(_ThrowingSecureStorage());
      final result = await storage.getMemberId();
      expect(result, isNull,
          reason: 'must default to null; must not rethrow PlatformException');
    });

    test('isOnboardingCompleted returns true when key is set', () async {
      final storage = SecureStorage(_MemorySecureStorage({'viva_onboarding_done': 'true'}));
      expect(await storage.isOnboardingCompleted(), true);
    });

    test('getMemberId returns the stored value', () async {
      final storage = SecureStorage(_MemorySecureStorage({'viva_member_id': 'M-12345'}));
      expect(await storage.getMemberId(), 'M-12345');
    });
  });
}

// ── Fakes ─────────────────────────────────────────────────────────────────────

/// Simulates a destroyed Keystore key — every read throws.
class _ThrowingSecureStorage extends Fake implements FlutterSecureStorage {
  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    throw Exception('PlatformException: Keystore operation failed — key not found');
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    // No-op in the throwing scenario (clearAppData calls delete).
  }
}

/// In-memory storage for the happy-path tests.
class _MemorySecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data;
  _MemorySecureStorage(this._data);

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _data[key];

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async => _data.remove(key);
}
