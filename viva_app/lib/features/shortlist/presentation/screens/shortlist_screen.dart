import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/verified_badge.dart';

class _ShortlistItem {
  final String userId;
  final String fullName;
  final int? age;
  final String? location;
  final String? photoUrl;
  final bool isVerified;
  final String? privateNotes;

  const _ShortlistItem({
    required this.userId,
    required this.fullName,
    this.age,
    this.location,
    this.photoUrl,
    this.isVerified = false,
    this.privateNotes,
  });

  factory _ShortlistItem.fromJson(Map<String, dynamic> j) =>
      _ShortlistItem(
        userId: j['user_id'] as String,
        fullName: j['full_name'] as String,
        age: j['age'] as int?,
        location: j['location'] as String?,
        photoUrl: j['primary_photo_url'] as String?,
        isVerified: j['is_verified'] as bool? ?? false,
        privateNotes: j['private_notes'] as String?,
      );
}

final _shortlistProvider =
    FutureProvider.autoDispose<List<_ShortlistItem>>((ref) async {
  final client = ref.read(apiClientProvider);
  final r = await client.get('/shortlist');
  return (r.data['shortlist'] as List)
      .map((e) => _ShortlistItem.fromJson(e as Map<String, dynamic>))
      .toList();
});

class ShortlistScreen extends ConsumerWidget {
  const ShortlistScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_shortlistProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Shortlisted')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_shortlistProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyStateView(
                icon: Icons.bookmark_border_rounded,
                title: 'No profiles shortlisted',
                subtitle:
                    'Tap the bookmark icon on any profile to save them here.',
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, i) => _ShortlistCard(
                  item: items[i],
                  onRemove: () async {
                    try {
                      await ref
                          .read(apiClientProvider)
                          .delete('/shortlist/${items[i].userId}');
                      ref.invalidate(_shortlistProvider);
                    } catch (_) {}
                  },
                  onEditNote: () => _editNote(context, ref, items[i]),
                ),
              ),
      ),
    );
  }

  void _editNote(
      BuildContext context, WidgetRef ref, _ShortlistItem item) {
    final ctrl = TextEditingController(text: item.privateNotes ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Private Note',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText:
                'e.g. Discuss with family, good match for values…',
            filled: true,
            fillColor: AppTheme.surfaceVariant,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.md),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(apiClientProvider).post(
                  '/shortlist/${item.userId}',
                  data: {'private_notes': ctrl.text.trim()},
                );
                ref.invalidate(_shortlistProvider);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Could not save note. Please try again.'),
                    backgroundColor: AppTheme.error,
                    behavior: SnackBarBehavior.floating,
                  ));
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _ShortlistCard extends StatelessWidget {
  final _ShortlistItem item;
  final VoidCallback onRemove;
  final VoidCallback onEditNote;

  const _ShortlistCard({
    required this.item,
    required this.onRemove,
    required this.onEditNote,
  });

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.userId),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        decoration: BoxDecoration(
          color: AppTheme.error,
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.delete_outline_rounded,
                color: Colors.white, size: 24),
            SizedBox(height: 4),
            Text('Remove',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
      onDismissed: (_) => onRemove(),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          boxShadow: AppShadows.card,
        ),
        child: Row(
          children: [
            // Photo
            GestureDetector(
              onTap: () => context.push('/profile/${item.userId}'),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: SizedBox(
                  width: 58,
                  height: 70,
                  child: item.photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: item.photoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _placeholder(),
                        )
                      : _placeholder(),
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Info
            Expanded(
              child: GestureDetector(
                onTap: () => context.push('/profile/${item.userId}'),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(
                          '${item.fullName}${item.age != null ? ', ${item.age}' : ''}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (item.isVerified)
                        const VerifiedBadge(small: true),
                    ]),
                    if (item.location != null) ...[
                      const SizedBox(height: 3),
                      Row(children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppTheme.textSecondary),
                        const SizedBox(width: 3),
                        Text(item.location!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                            )),
                      ]),
                    ],
                    // Private note
                    if (item.privateNotes != null &&
                        item.privateNotes!.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppTheme.secondaryContainer,
                          borderRadius:
                              BorderRadius.circular(AppRadius.sm),
                        ),
                        child: Row(children: [
                          const Icon(Icons.lock_outline_rounded,
                              size: 11,
                              color: AppTheme.textSecondary),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              item.privateNotes!,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppTheme.textSecondary,
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            // Actions
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () => context.push('/profile/${item.userId}'),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryContainer,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 13, color: AppTheme.primary),
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: onEditNote,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: AppTheme.surfaceVariant,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit_note_rounded,
                        size: 16, color: AppTheme.textSecondary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppTheme.primaryContainer,
        child: const Icon(Icons.person_outline,
            color: AppTheme.primary, size: 28),
      );
}
