import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/error_view.dart';

final _notificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final client = ref.read(apiClientProvider);
  final r = await client.get('/notifications', queryParameters: {'limit': 50});
  return (r.data['notifications'] as List)
      .map((e) => NotificationModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_notificationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              // Mark all as read
              try {
                // We'd call a bulk-read endpoint; for now invalidate to refresh
                ref.invalidate(_notificationsProvider);
              } catch (_) {}
            },
            child: const Text('Mark all read', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_notificationsProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyStateView(
                icon: Icons.notifications_none_outlined,
                title: 'No notifications yet',
                subtitle: 'Interest received, messages and profile updates will appear here.',
              )
            : ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                itemBuilder: (context, i) => _NotificationTile(
                  item: items[i],
                  onTap: () => _handleTap(context, ref, items[i]),
                ),
              ),
      ),
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref, NotificationModel n) async {
    // Mark as read
    if (!n.isRead) {
      try {
        await ref.read(apiClientProvider).put('/notifications/${n.id}/read');
        ref.invalidate(_notificationsProvider);
      } catch (_) {}
    }

    // Navigate to relevant screen
    if (n.entityType == 'interest' && n.entityId != null) {
      context.go(AppRoutes.interests);
    } else if (n.entityType == 'interest' && n.type == 'interest_accepted') {
      // Go to connections tab so they can open WhatsApp
      context.go(AppRoutes.connections);
    } else if (n.type == 'certificate_approved' || n.type == 'certificate_rejected') {
      context.push(AppRoutes.verificationStatus);
    } else if (n.type == 'verification_approved') {
      context.push(AppRoutes.verificationStatus);
    }
  }
}

class _NotificationTile extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onTap;
  const _NotificationTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      onTap: onTap,
      leading: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: _iconColor(item.type).withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Icon(_iconData(item.type), size: 22, color: _iconColor(item.type)),
      ),
      title: Text(
        item.title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: item.isRead ? FontWeight.w400 : FontWeight.w600,
          color: AppTheme.textPrimary,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(item.body, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
          const SizedBox(height: 2),
          Text(_timeAgo(item.createdAt), style: const TextStyle(fontSize: 10, color: AppTheme.textTertiary)),
        ],
      ),
      trailing: !item.isRead
          ? Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle))
          : null,
    );
  }

  IconData _iconData(String type) {
    return switch (type) {
      'interest_received' => Icons.favorite,
      'interest_accepted' => Icons.chat,   // Opens to WhatsApp connections
      'new_message' => Icons.chat_bubble,
      'match_found' => Icons.people,
      'certificate_approved' || 'verification_approved' => Icons.verified,
      'certificate_rejected' || 'verification_rejected' => Icons.cancel,
      _ => Icons.notifications,
    };
  }

  Color _iconColor(String type) {
    return switch (type) {
      'interest_received' || 'interest_accepted' => AppTheme.primary,
      'match_found' => AppTheme.secondary,
      'certificate_approved' || 'verification_approved' => AppTheme.success,
      'certificate_rejected' || 'verification_rejected' => AppTheme.error,
      _ => AppTheme.secondary,
    };
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}
