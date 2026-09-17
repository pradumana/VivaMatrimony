import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

/// Unread notification count — shown as a badge on the bell icon.
/// keepAlive() so it persists across tab switches; invalidated after
/// mark-all-read or individual read actions.
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  ref.keepAlive();
  final r = await ref.read(apiClientProvider).get(
    '/notifications',
    queryParameters: {'limit': 50},
  );
  final notifications = r.data['notifications'] as List? ?? [];
  return notifications.where((n) => n['is_read'] == false).length;
});
