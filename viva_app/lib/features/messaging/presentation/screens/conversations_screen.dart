import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
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
              )
            : ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: connections.length,
                itemBuilder: (context, i) =>
                    _ConnectionCard(connection: connections[i]),
              ),
      ),
    );
  }
}

// ── Card ─────────────────────────────────────────────────────────────────────

class _ConnectionCard extends ConsumerStatefulWidget {
  final _Connection connection;
  const _ConnectionCard({required this.connection});

  @override
  ConsumerState<_ConnectionCard> createState() =>
      _ConnectionCardState();
}

class _ConnectionCardState extends ConsumerState<_ConnectionCard> {
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
      SnackBar(
        content: Text(msg),
        backgroundColor: AppTheme.error,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.connection;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          // Photo with verified dot
          GestureDetector(
            onTap: () => context.push('/profile/${c.userId}'),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: SizedBox(
                    width: 58,
                    height: 70,
                    child: c.photoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: c.photoUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _placeholder(),
                          )
                        : _placeholder(),
                  ),
                ),
                if (c.isVerified)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: AppTheme.verifiedBadge,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 14),

          // Info
          Expanded(
            child: GestureDetector(
              onTap: () => context.push('/profile/${c.userId}'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text(
                      '${c.fullName}${c.age != null ? ", ${c.age}" : ""}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (c.isVerified) const VerifiedBadge(small: true),
                  ]),
                  if (c.location != null) ...[
                    const SizedBox(height: 3),
                    Row(children: [
                      const Icon(Icons.location_on_outlined,
                          size: 12, color: AppTheme.textSecondary),
                      const SizedBox(width: 3),
                      Text(c.location!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          )),
                    ]),
                  ],
                  const SizedBox(height: 6),
                  const Row(children: [
                    Icon(Icons.check_circle_outline_rounded,
                        size: 12, color: AppTheme.success),
                    SizedBox(width: 4),
                    Text(
                      'Mutually connected',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ),

          // WhatsApp button
          const SizedBox(width: 10),
          _loadingWa
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.whatsAppGreen,
                  ),
                )
              : GestureDetector(
                  onTap: _openWhatsApp,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 9),
                    decoration: BoxDecoration(
                      color: AppTheme.whatsAppGreen,
                      borderRadius:
                          BorderRadius.circular(AppRadius.md),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.whatsAppGreen
                              .withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.chat_rounded,
                            size: 14, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'Chat',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _placeholder() => Container(
        color: AppTheme.primaryContainer,
        child: const Icon(Icons.person_outline,
            color: AppTheme.primary, size: 28),
      );
}
