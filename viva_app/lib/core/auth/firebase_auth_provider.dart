import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'auth_state.dart';

export 'auth_state.dart';
export 'auth_error.dart';

// ── Repository provider ───────────────────────────────────────────────────────

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return FirebaseAuthRepository(ref);
});

// ── Auth state stream ─────────────────────────────────────────────────────────

/// Single source of truth for auth state, backed by Firebase's idTokenChanges()
/// stream. Replaces the old AsyncNotifier-based authProvider in auth_provider.dart.
///
/// StreamProvider emits AsyncValue<AuthState>:
///   AsyncLoading  — waiting for first emission (cold start)
///   AsyncData     — resolved state (loading, authenticated, emailUnverified, etc.)
///   AsyncError    — unexpected stream error (treated as unauthenticated by router)
final firebaseAuthProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

// ── Convenience status selector ───────────────────────────────────────────────

/// Derives just the [AuthStatus] — avoids rebuilding the whole widget tree
/// when unrelated fields (memberId, email) change.
final firebaseAuthStatusProvider = Provider<AuthStatus>((ref) {
  return ref.watch(firebaseAuthProvider).valueOrNull?.status
      ?? AuthStatus.loading;
});

// ── User-provider reset ───────────────────────────────────────────────────────

// Imported lazily to avoid circular imports — call sites pass the providers.
// The LogoutService calls this after FirebaseAuth.signOut().
//
// Usage:
//   resetUserProviders(ref);
void resetUserProviders(Ref ref) {
  // Invalidate all user-specific providers so they don't serve
  // stale data after a logout or account switch.
  //
  // Add providers here as they are created throughout the migration.
  // Currently using ref.invalidate on providers imported elsewhere is
  // done at call sites (LogoutService) to keep this file import-free.
  //
  // ponytail: centralise here once LogoutService is wired (Phase 7).
}
