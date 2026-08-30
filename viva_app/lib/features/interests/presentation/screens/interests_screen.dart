import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/viva_button.dart';

final _sentInterestsProvider = FutureProvider.autoDispose<List<InterestModel>>((ref) async {
  final client = ref.read(apiClientProvider);
  final r = await client.get('/interests/sent');
  return (r.data['interests'] as List).map((e) => InterestModel.fromJson(e as Map<String, dynamic>)).toList();
});

final _receivedInterestsProvider = FutureProvider.autoDispose<List<InterestModel>>((ref) async {
  final client = ref.read(apiClientProvider);
  final r = await client.get('/interests/received');
  return (r.data['interests'] as List).map((e) => InterestModel.fromJson(e as Map<String, dynamic>)).toList();
});

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});
  @override
  ConsumerState<InterestsScreen> createState() => _State();
}

class _State extends ConsumerState<InterestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() { _tabController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interests'),
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.primary,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.primary,
          labelStyle: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600),
          tabs: const [Tab(text: 'Received'), Tab(text: 'Sent')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InterestList(provider: _receivedInterestsProvider, isReceived: true),
          _InterestList(provider: _sentInterestsProvider, isReceived: false),
        ],
      ),
    );
  }
}

class _InterestList extends ConsumerWidget {
  final ProviderBase<AsyncValue<List<InterestModel>>> provider;
  final bool isReceived;
  const _InterestList({required this.provider, required this.isReceived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(message: e.toString(), onRetry: () => ref.invalidate(provider)),
      data: (items) => items.isEmpty
          ? EmptyStateView(
              icon: Icons.favorite_border,
              title: isReceived ? 'No interests received yet' : 'No interests sent yet',
              subtitle: isReceived
                  ? 'Complete your profile so others can find you.'
                  : 'Browse matches and send interests to connect.',
              actionLabel: isReceived ? 'Edit Profile' : 'Browse Matches',
              onAction: () => context.go(isReceived ? AppRoutes.myProfile : AppRoutes.home),
            )
          : ListView.builder(
              itemCount: items.length,
              itemBuilder: (context, i) => _InterestTile(item: items[i], isReceived: isReceived),
            ),
    );
  }
}

class _InterestTile extends ConsumerWidget {
  final InterestModel item;
  final bool isReceived;
  const _InterestTile({required this.item, required this.isReceived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: GestureDetector(
        onTap: () => context.push('/profile/${item.userId}'),
        child: CircleAvatar(
          radius: 28,
          backgroundColor: AppTheme.surfaceVariant,
          backgroundImage: item.photoUrl != null ? CachedNetworkImageProvider(item.photoUrl!) : null,
          child: item.photoUrl == null ? const Icon(Icons.person_outline, color: AppTheme.textTertiary) : null,
        ),
      ),
      title: GestureDetector(
        onTap: () => context.push('/profile/${item.userId}'),
        child: Text(item.fullName, style: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 14)),
      ),
      subtitle: Text(
        '${item.age != null ? "${item.age} yrs • " : ""}${item.location ?? ""}',
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.textSecondary),
      ),
      trailing: isReceived && item.status == 'sent'
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ActionBtn(label: 'Accept', color: AppTheme.success,
                  onTap: () => _accept(context, ref, item.interestId)),
                const SizedBox(width: 8),
                _ActionBtn(label: 'Decline', color: AppTheme.error,
                  onTap: () => _decline(context, ref, item.interestId)),
              ],
            )
          : _StatusChip(status: item.status),
    );
  }

  Future<void> _accept(BuildContext ctx, WidgetRef ref, String id) async {
    try {
      final client = ref.read(apiClientProvider);
      // Accept the interest — backend now returns whatsapp_url
      final r = await client.post('/interests/$id/accept');
      final data = r.data as Map<String, dynamic>;
      final waUrl = data['whatsapp_url'] as String?;

      ref.invalidate(_receivedInterestsProvider);

      if (!ctx.mounted) return;

      // Show success bottom sheet with WhatsApp CTA
      showModalBottomSheet(
        context: ctx,
        isDismissible: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) => _AcceptedSheet(
          waUrl: waUrl,
          name: item.fullName,
          onOpenWhatsApp: waUrl != null
              ? () async {
                  Navigator.pop(ctx);
                  final uri = Uri.parse(waUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                }
              : null,
        ),
      );
    } on DioException catch (e) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
          content: Text(ApiException.fromDioError(e).message),
          backgroundColor: AppTheme.error,
        ));
      }
    }
  }

  Future<void> _decline(BuildContext ctx, WidgetRef ref, String id) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/interests/$id/decline');
      ref.invalidate(_receivedInterestsProvider);
    } catch (_) {}
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _ActionBtn({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.full), border: Border.all(color: color.withOpacity(0.4))),
        child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final colors = {
      'sent': AppTheme.warning, 'accepted': AppTheme.success,
      'declined': AppTheme.error, 'withdrawn': AppTheme.textSecondary,
    };
    final color = colors[status] ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(AppRadius.full)),
      child: Text(status.toUpperCase(), style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: color)),
    );
  }
}

// ── Accepted bottom sheet ────────────────────────────────────────────────────

class _AcceptedSheet extends StatelessWidget {
  final String? waUrl;
  final String name;
  final VoidCallback? onOpenWhatsApp;

  const _AcceptedSheet({
    required this.waUrl,
    required this.name,
    this.onOpenWhatsApp,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Celebration icon
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Color(0xFFE8F8EF),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_outline,
                size: 40,
                color: AppTheme.success,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'You\'re connected! 🎉',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You and $name have mutually accepted each other\'s interest. '
              'Continue the conversation on WhatsApp.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            // WhatsApp CTA
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat, size: 20),
                label: Text(
                  'Chat on WhatsApp',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                onPressed: onOpenWhatsApp,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Later — view in Connections',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
