import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/verified_badge.dart';

final _viewersProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final r = await ref.read(apiClientProvider).get('/profile/viewers');
  return (r.data['viewers'] as List).cast<Map<String, dynamic>>();
});

class WhoViewedMeScreen extends ConsumerWidget {
  const WhoViewedMeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_viewersProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Who Viewed My Profile')),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(_viewersProvider)),
        data: (viewers) => viewers.isEmpty
            ? const EmptyStateView(
                icon: Icons.visibility_off_outlined,
                title: 'No profile views yet',
                subtitle:
                    'When someone views your profile, they\'ll appear here.',
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: viewers.length,
                itemBuilder: (context, i) => _ViewerCard(viewer: viewers[i]),
              ),
      ),
    );
  }
}

class _ViewerCard extends StatelessWidget {
  final Map<String, dynamic> viewer;
  const _ViewerCard({required this.viewer});

  @override
  Widget build(BuildContext context) {
    final name = viewer['full_name'] as String? ?? '';
    final age = viewer['age'] as int?;
    final location = viewer['location'] as String? ?? '';
    final photoUrl = viewer['primary_photo_url'] as String?;
    final isVerified = viewer['is_verified'] as bool? ?? false;
    final viewedAt = viewer['viewed_at'] as String?;

    return GestureDetector(
      onTap: () => context.push('/profile/${viewer['user_id']}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 56, height: 68,
              child: photoUrl != null
                  ? CachedNetworkImage(imageUrl: photoUrl, fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder())
                  : _placeholder(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      age != null ? '$name, $age' : name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (isVerified) const VerifiedBadge(small: true),
                ]),
                if (location.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Row(children: [
                    const Icon(Icons.location_on_outlined,
                        size: 12, color: AppTheme.textSecondary),
                    const SizedBox(width: 3),
                    Text(location,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.textSecondary)),
                  ]),
                ],
                if (viewedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    _formatViewedAt(viewedAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppTheme.textTertiary, size: 20),
        ]),
      ),
    );
  }

  Widget _placeholder() => Container(
      color: AppTheme.primaryContainer,
      child: const Icon(Icons.person_outline, color: AppTheme.primary));

  String _formatViewedAt(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'Recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return 'Viewed ${diff.inMinutes}m ago';
    if (diff.inHours < 24) return 'Viewed ${diff.inHours}h ago';
    if (diff.inDays == 1) return 'Viewed yesterday';
    if (diff.inDays < 7) return 'Viewed ${diff.inDays} days ago';
    return 'Viewed over a week ago';
  }
}
