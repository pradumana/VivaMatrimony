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

final _sentInterestsProvider =
    FutureProvider.autoDispose<List<InterestModel>>((ref) async {
  final client = ref.read(apiClientProvider);
  final r = await client.get('/interests/sent');
  return (r.data['interests'] as List)
      .map((e) => InterestModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _receivedInterestsProvider =
    FutureProvider.autoDispose<List<InterestModel>>((ref) async {
  final client = ref.read(apiClientProvider);
  final r = await client.get('/interests/received');
  return (r.data['interests'] as List)
      .map((e) => InterestModel.fromJson(e as Map<String, dynamic>))
      .toList();
});

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});
  @override
  ConsumerState<InterestsScreen> createState() => _State();
}

class _State extends ConsumerState<InterestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Interests'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            height: 40,
            decoration: BoxDecoration(
              color: AppTheme.surfaceVariant,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: Colors.transparent,
              labelColor: Colors.white,
              unselectedLabelColor: AppTheme.textSecondary,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              tabs: const [
                Tab(text: 'Received'),
                Tab(text: 'Sent'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _InterestList(
              provider: _receivedInterestsProvider, isReceived: true),
          _InterestList(
              provider: _sentInterestsProvider, isReceived: false),
        ],
      ),
    );
  }
}

class _InterestList extends ConsumerWidget {
  final ProviderBase<AsyncValue<List<InterestModel>>> provider;
  final bool isReceived;
  const _InterestList(
      {required this.provider, required this.isReceived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(provider);
    return async.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
          message: e.toString(),
          onRetry: () => ref.invalidate(provider)),
      data: (items) => items.isEmpty
          ? EmptyStateView(
              icon: Icons.favorite_border_rounded,
              title: isReceived
                  ? 'No interests received yet'
                  : 'No interests sent yet',
              subtitle: isReceived
                  ? 'Complete your profile so others can find you.'
                  : 'Browse matches and send interests to connect.',
              actionLabel:
                  isReceived ? 'Edit Profile' : 'Browse Matches',
              onAction: () => context
                  .go(isReceived ? AppRoutes.myProfile : AppRoutes.home),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, i) =>
                  _InterestCard(item: items[i], isReceived: isReceived),
            ),
    );
  }
}

class _InterestCard extends ConsumerWidget {
  final InterestModel item;
  final bool isReceived;
  const _InterestCard(
      {required this.item, required this.isReceived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          // Photo
          GestureDetector(
            onTap: () => context.push('/profile/${item.userId}'),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: SizedBox(
                width: 60,
                height: 72,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () =>
                      context.push('/profile/${item.userId}'),
                  child: Text(
                    item.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (item.age != null) '${item.age} yrs',
                    if (item.location != null) item.location!,
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 10),
                // Actions or status
                isReceived && item.status == 'sent'
                    ? Row(
                        children: [
                          _ActionBtn(
                            label: 'Accept',
                            color: AppTheme.success,
                            onTap: () => _accept(
                                context, ref, item.interestId),
                          ),
                          const SizedBox(width: 8),
                          _ActionBtn(
                            label: 'Decline',
                            color: AppTheme.error,
                            onTap: () => _decline(
                                context, ref, item.interestId),
                          ),
                        ],
                      )
                    : _StatusBadge(status: item.status),
              ],
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

  Future<void> _accept(
      BuildContext ctx, WidgetRef ref, String id) async {
    try {
      final client = ref.read(apiClientProvider);
      final r = await client.post('/interests/$id/accept');
      final data = r.data as Map<String, dynamic>;
      final waUrl = data['whatsapp_url'] as String?;
      ref.invalidate(_receivedInterestsProvider);
      if (!ctx.mounted) return;
      showModalBottomSheet(
        context: ctx,
        isDismissible: true,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(20)),
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
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  Future<void> _decline(
      BuildContext ctx, WidgetRef ref, String id) async {
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
  const _ActionBtn(
      {required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: color)),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      'accepted' => (AppTheme.success, Icons.check_circle_rounded, 'Accepted'),
      'declined' => (AppTheme.error, Icons.cancel_rounded, 'Declined'),
      'withdrawn' =>
        (AppTheme.textSecondary, Icons.remove_circle_outline, 'Withdrawn'),
      _ => (AppTheme.warning, Icons.schedule_rounded, 'Pending'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Accepted bottom sheet ─────────────────────────────────────────────────────

class _AcceptedSheet extends StatelessWidget {
  final String? waUrl;
  final String name;
  final VoidCallback? onOpenWhatsApp;

  const _AcceptedSheet(
      {required this.waUrl,
      required this.name,
      this.onOpenWhatsApp});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppTheme.successSurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_outline_rounded,
                  size: 42, color: AppTheme.success),
            ),
            const SizedBox(height: 16),
            const Text(
              'You\'re connected! 🎉',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'You and $name have mutually accepted each other\'s interest. '
              'Continue the conversation on WhatsApp.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.whatsAppGreen,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppRadius.lg)),
                  elevation: 0,
                ),
                icon: const Icon(Icons.chat_rounded, size: 20),
                label: const Text('Chat on WhatsApp',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                onPressed: onOpenWhatsApp,
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Later — view in Connections',
                  style: TextStyle(
                      fontSize: 13, color: AppTheme.textSecondary)),
            ),
          ],
        ),
      ),
    );
  }
}
