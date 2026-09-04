import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/extensions/string_extensions.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/error_view.dart';

final _notificationsProvider =
    FutureProvider.autoDispose<List<NotificationModel>>((ref) async {
  final client = ref.read(apiClientProvider);
  final r = await client
      .get('/notifications', queryParameters: {'limit': 50});
  return (r.data['notifications'] as List)
      .map((e) =>
          NotificationModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_notificationsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () => _markAllRead(context, ref),
            child: const Text('Mark all read',
                style: TextStyle(
                    fontSize: 12, color: AppTheme.primary)),
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
                subtitle:
                    'Interests, matches and profile updates will appear here.',
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, i) => _NotificationCard(
                  item: items[i],
                  onTap: () =>
                      _handleTap(context, ref, items[i]),
                ),
              ),
      ),
    );
  }

  Future<void> _markAllRead(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(apiClientProvider).post('/notifications/mark-all-read');
    } catch (_) {
      // Best-effort: even if the API fails, refresh the list below
    }
    ref.invalidate(_notificationsProvider);
  }

  Future<void> _handleTap(
      BuildContext context, WidgetRef ref, NotificationModel n) async {
    if (!n.isRead) {
      try {
        await ref
            .read(apiClientProvider)
            .put('/notifications/${n.id}/read');
        ref.invalidate(_notificationsProvider);
      } catch (_) {}
    }
    if (!context.mounted) return;
    if (n.entityType == 'interest' && n.entityId != null) {
      context.go(AppRoutes.interests);
    } else if (n.type == 'interest_accepted') {
      context.go(AppRoutes.connections);
    } else if (n.type == 'certificate_approved' ||
        n.type == 'certificate_rejected' ||
        n.type == 'verification_approved') {
      context.push(AppRoutes.verificationStatus);
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final NotificationModel item;
  final VoidCallback onTap;
  const _NotificationCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _iconColor(item.type);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.white : AppTheme.primaryContainer.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
          border: item.isRead
              ? null
              : Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.15), width: 1),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(_iconData(item.type), size: 22, color: color),
            ),
            const SizedBox(width: 12),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: item.isRead
                                ? FontWeight.w500
                                : FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 3, left: 6),
                          decoration: const BoxDecoration(
                            color: AppTheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.body,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    item.createdAt.timeAgo,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _iconData(String type) => switch (type) {
        'interest_received' => Icons.favorite_rounded,
        'interest_accepted' => Icons.people_rounded,
        'new_message' => Icons.chat_bubble_rounded,
        'match_found' => Icons.auto_awesome_rounded,
        'certificate_approved' ||
        'verification_approved' =>
          Icons.verified_rounded,
        'certificate_rejected' ||
        'verification_rejected' =>
          Icons.cancel_rounded,
        _ => Icons.notifications_rounded,
      };

  Color _iconColor(String type) => switch (type) {
        'interest_received' || 'interest_accepted' => AppTheme.primary,
        'match_found' => AppTheme.secondary,
        'certificate_approved' ||
        'verification_approved' =>
          AppTheme.success,
        'certificate_rejected' ||
        'verification_rejected' =>
          AppTheme.error,
        _ => AppTheme.secondary,
      };
}
