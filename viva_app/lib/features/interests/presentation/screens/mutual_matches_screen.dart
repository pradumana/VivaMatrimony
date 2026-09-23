import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/verified_badge.dart';

final _mutualProvider =
    FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  final r = await ref.read(apiClientProvider).get('/interests/mutual');
  return (r.data['mutual'] as List).cast<Map<String, dynamic>>();
});

class MutualMatchesScreen extends ConsumerWidget {
  const MutualMatchesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final async = ref.watch(_mutualProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: Text(l.mutualMatches)),
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(_mutualProvider)),
        data: (matches) => matches.isEmpty
            ? const EmptyStateView(
                icon: Icons.favorite_border_rounded,
                title: 'No connections yet',
                subtitle:
                    'When an interest you sent or received is accepted, they\'ll appear here.',
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: matches.length,
                itemBuilder: (context, i) =>
                    _MutualCard(match: matches[i]),
              ),
      ),
    );
  }
}

class _MutualCard extends StatelessWidget {
  final Map<String, dynamic> match;
  const _MutualCard({required this.match});

  @override
  Widget build(BuildContext context) {
    final name = match['full_name'] as String? ?? '';
    final age = match['age'] as int?;
    final location = match['location'] as String? ?? '';
    final photoUrl = match['primary_photo_url'] as String?;
    final isVerified = match['is_verified'] as bool? ?? false;
    final connectedAt = match['connected_at'] as String?;

    return GestureDetector(
      onTap: () => context.push('/profile/${match['user_id']}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.15)),
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
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.favorite_rounded,
                        size: 10, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      connectedAt != null
                          ? 'Connected ${_formatDate(connectedAt)}'
                          : 'Connected',
                      style: const TextStyle(
                          fontSize: 10,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600),
                    ),
                  ]),
                ),
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

  String _formatDate(String iso) {
    final dt = DateTime.tryParse(iso);
    if (dt == null) return 'recently';
    final diff = DateTime.now().difference(dt);
    if (diff.inDays == 0) return 'today';
    if (diff.inDays == 1) return 'yesterday';
    if (diff.inDays < 7) return '${diff.inDays} days ago';
    return 'on ${dt.day}/${dt.month}/${dt.year}';
  }
}
