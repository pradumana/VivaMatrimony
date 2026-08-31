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

  factory _ShortlistItem.fromJson(Map<String, dynamic> j) => _ShortlistItem(
        userId: j['user_id'] as String,
        fullName: j['full_name'] as String,
        age: j['age'] as int?,
        location: j['location'] as String?,
        photoUrl: j['primary_photo_url'] as String?,
        isVerified: j['is_verified'] as bool? ?? false,
        privateNotes: j['private_notes'] as String?,
      );
}

final _shortlistProvider = FutureProvider.autoDispose<List<_ShortlistItem>>((ref) async {
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
      appBar: AppBar(title: const Text('Shortlisted')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_shortlistProvider),
        ),
        data: (items) => items.isEmpty
            ? const EmptyStateView(
                icon: Icons.bookmark_border,
                title: 'No profiles shortlisted',
                subtitle: 'Tap the bookmark icon on any profile to save them here.',
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: items.length,
                itemBuilder: (context, i) => _ShortlistTile(
                  item: items[i],
                  onRemove: () async {
                    try {
                      await ref.read(apiClientProvider).delete('/shortlist/${items[i].userId}');
                      ref.invalidate(_shortlistProvider);
                    } catch (_) {}
                  },
                ),
              ),
      ),
    );
  }
}

class _ShortlistTile extends StatelessWidget {
  final _ShortlistItem item;
  final VoidCallback onRemove;
  const _ShortlistTile({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(item.userId),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: AppTheme.error,
        child: const Icon(Icons.delete_outline, color: Colors.white, size: 28),
      ),
      onDismissed: (_) => onRemove(),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        leading: GestureDetector(
          onTap: () => context.push('/profile/${item.userId}'),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: SizedBox(
              width: 56,
              height: 68,
              child: item.photoUrl != null
                  ? CachedNetworkImage(imageUrl: item.photoUrl!, fit: BoxFit.cover)
                  : Container(
                      color: AppTheme.primaryContainer,
                      child: const Icon(Icons.person_outline, color: AppTheme.primary, size: 28),
                    ),
            ),
          ),
        ),
        title: GestureDetector(
          onTap: () => context.push('/profile/${item.userId}'),
          child: Row(children: [
            Text(
              '${item.fullName}${item.age != null ? ', ${item.age}' : ''}',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
            const SizedBox(width: 6),
            if (item.isVerified) const VerifiedBadge(small: true),
          ]),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.location != null)
              Text(item.location!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            // Private notes — only visible to owner
            if (item.privateNotes != null && item.privateNotes!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Row(children: [
                const Icon(Icons.lock_outline, size: 11, color: AppTheme.textTertiary),
                const SizedBox(width: 4),
                Expanded(child: Text(item.privateNotes!, style: const TextStyle(fontSize: 11, color: AppTheme.textTertiary, fontStyle: FontStyle.italic), overflow: TextOverflow.ellipsis)),
              ]),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            GestureDetector(
              onTap: () => context.push('/profile/${item.userId}'),
              child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textTertiary),
            ),
            GestureDetector(
              onTap: () => _editNote(context, item),
              child: const Icon(Icons.edit_note, size: 18, color: AppTheme.textSecondary),
            ),
          ],
        ),
      ),
    );
  }

  void _editNote(BuildContext context, _ShortlistItem item) {
    final ctrl = TextEditingController(text: item.privateNotes ?? '');
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Private Note', style: TextStyle(fontWeight: FontWeight.w600)),
        content: TextField(
          controller: ctrl,
          maxLines: 3,
          maxLength: 200,
          decoration: const InputDecoration(hintText: 'e.g. Discuss with family, good match for values...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              // Save note via API
              try {
                final container = ProviderScope.containerOf(context);
                await container.read(apiClientProvider).post(
                  '/shortlist/${item.userId}',
                  data: {'private_notes': ctrl.text.trim()},
                );
              } catch (_) {}
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}
