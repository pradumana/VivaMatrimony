import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Shared profile data provider used by both HomeScreen (greeting name)
/// and MyProfileScreen (full profile body).
///
/// Non-autoDispose: keeps the fetched value alive across tab switches so
/// switching between Home and Profile tabs never triggers a re-fetch.
///
/// Logout safety: the router's redirect callback fires before any screen
/// watches this provider again, so stale data from a previous session is
/// never rendered. Explicitly invalidate via ref.invalidate(myProfileProvider)
/// after profile edits (already done in _ProfileBodyState._goAndRefresh).
final myProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final r = await ref.read(apiClientProvider).get('/profile');
  return r.data as Map<String, dynamic>;
});
