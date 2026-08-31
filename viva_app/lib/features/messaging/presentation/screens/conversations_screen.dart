import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/verified_badge.dart';

// ── Model ─────────────────────────────────────────────────────────────────────

class _Connection {
  final String interestId;
  final String userId;
  final String fullName;
  final int? age;
  final String? location;
  final String? photoUrl;
  final bool isVerified;
  final DateTime? acceptedAt;

  const _Connection({
    required this.interestId,
    required this.userId,
    required this.fullName,
    this.age,
    this.location,
    this.photoUrl,
    this.isVerified = false,
    this.acceptedAt,
  });

  factory _Connection.fromJson(Map<String, dynamic> j) => _Connection(
        interestId: j['interest_id'] as String,
        userId: j['user_id'] as String,
        fullName: j['full_name'] as String,
        age: j['age'] as int?,
        location: j['location'] as String?,
        photoUrl: j['primary_photo_url'] as String?,
        isVerified: j['is_verified'] as bool? ?? false,
        acceptedAt: j['sent_at'] != null
            ? DateTime.tryParse(j['sent_at'] as String)
            : null,
      );
}

// ── Provider ─────────────────────────────────────────────────────────────────

final _connectionsProvider =
    FutureProvider.autoDispose<List<_Connection>>((ref) async {
  final client = ref.read(apiClientProvider);
  // Fetch all interests where status == 'accepted' from both sent and received
  final results = await Future.wait([
    client.get('/interests/sent'),
    client.get('/interests/received'),
  ]);

  final all = <_Connection>[];
  for (final r in results) {
    final items = (r.data['interests'] as List)
        .map((e) => e as Map<String, dynamic>)
        .where((e) => e['status'] == 'accepted')
        .map(_Connection.fromJson)
        .toList();
    all.addAll(items);
  }

  // Deduplicate by userId (if both sent and received somehow overlap)
  final seen = <String>{};
  return all.where((c) => seen.add(c.userId)).toList()
    ..sort((a, b) => (b.acceptedAt ?? DateTime(0))
        .compareTo(a.acceptedAt ?? DateTime(0)));
});

// ── Screen ────────────────────────────────────────────────────────────────────

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_connectionsProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Connections')),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(_connectionsProvider),
        ),
        data: (connections) => connections.isEmpty
            ? const EmptyStateView(
                icon: Icons.people_outline_rounded,
                title: 'No connections yet',
                subtitle:
                    'When someone accepts your interest (or you accept theirs), '
                    'their WhatsApp contact will appear here.',
                actionLabel: 'Browse Matches',
              )
            : ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: connections.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 80),
                itemBuilder: (context, i) =>
                    _ConnectionTile(connection: connections[i]),
              ),
      ),
    );
  }
}

// ── Tile ─────────────────────────────────────────────────────────────────────

class _ConnectionTile extends ConsumerStatefulWidget {
  final _Connection connection;
  const _ConnectionTile({super.key, required this.connection});

  @override
  ConsumerState<_ConnectionTile> createState() => _ConnectionTileState();
}

class _ConnectionTileState extends ConsumerState<_ConnectionTile> {
  bool _loadingWa = false;

  Future<void> _openWhatsApp() async {
    setState(() => _loadingWa = true);
    try {
      final client = ref.read(apiClientProvider);
      final r = await client.get(
          '/interests/${widget.connection.interestId}/whatsapp');
      final data = r.data as Map<String, dynamic>;
      final waUrl = data['whatsapp_url'] as String;

      final uri = Uri.parse(waUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showError('Could not open WhatsApp. Is it installed?');
      }
    } on DioException catch (e) {
      _showError(ApiException.fromDioError(e).message);
    } finally {
      if (mounted) setState(() => _loadingWa = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.connection;
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: GestureDetector(
        onTap: () => context.push('/profile/${c.userId}'),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 52,
                height: 64,
                child: c.photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: c.photoUrl!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          color: AppTheme.primaryContainer,
                          child: const Icon(Icons.person_outline,
                              color: AppTheme.primary, size: 26),
                        ),
                      )
                    : Container(
                        color: AppTheme.primaryContainer,
                        child: const Icon(Icons.person_outline,
                            color: AppTheme.primary, size: 26),
                      ),
              ),
            ),
            if (c.isVerified)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: const BoxDecoration(
                    color: AppTheme.verifiedBadge,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check,
                      size: 10, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
      title: GestureDetector(
        onTap: () => context.push('/profile/${c.userId}'),
        child: Row(children: [
          Text(
            '${c.fullName}${c.age != null ? ", ${c.age}" : ""}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 6),
          if (c.isVerified) const VerifiedBadge(small: true),
        ]),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (c.location != null)
            Text(
              c.location!,
              style: const TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
              ),
            ),
          const SizedBox(height: 2),
          // Connected label
          Row(children: [
            const Icon(Icons.check_circle_outline,
                size: 11, color: AppTheme.success),
            const SizedBox(width: 3),
            Text(
              'Mutually connected',
              style: const TextStyle(
                fontSize: 10,
                color: AppTheme.success,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
        ],
      ),
      trailing: _loadingWa
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppTheme.success,
              ),
            )
          : _WhatsAppButton(onTap: _openWhatsApp),
    );
  }
}

// ── WhatsApp button ───────────────────────────────────────────────────────────

class _WhatsAppButton extends StatelessWidget {
  final VoidCallback onTap;
  const _WhatsAppButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.whatsAppGreen,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.chat, size: 14, color: Colors.white),
            SizedBox(width: 4),
            Text(
              'WhatsApp',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
