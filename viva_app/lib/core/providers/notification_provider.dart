import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Unread notification count — shown as a badge on the bell icon.
/// Uses the dedicated /unread-count endpoint (single COUNT query)
/// instead of fetching 50 full notification objects just to count them.
/// keepAlive() so it persists across tab switches; invalidated after
/// mark-all-read or individual read actions.
final unreadNotificationCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final r = await ref.read(apiClientProvider).get('/notifications/unread-count');
  return (r.data['unread_count'] as num).toInt();
});
