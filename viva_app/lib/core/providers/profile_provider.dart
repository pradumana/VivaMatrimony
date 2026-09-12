import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../providers/auth_provider.dart';

/// Shared profile data provider used by both HomeScreen (greeting name)
/// and MyProfileScreen (full profile body).
///
/// Non-autoDispose so the value is kept alive across tab switches without
/// re-fetching. Safe on logout: the router redirects to /login before any
/// screen can watch this provider again, so stale data is never displayed.
/// Invalidated explicitly on profile edits via ref.invalidate(myProfileProvider).
final myProfileProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  // Invalidate automatically when the user logs out so the next login
  // always fetches a fresh profile (handles account-switching edge case).
  ref.listen<AsyncValue<AuthState>>(authProvider, (_, next) {
    final status = next.valueOrNull?.status;
    if (status == AuthStatus.unauthenticated) {
      ref.invalidateSelf();
    }
  });

  final r = await ref.read(apiClientProvider).get('/profile');
  return r.data as Map<String, dynamic>;
});
