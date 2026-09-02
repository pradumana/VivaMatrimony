import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/profile_card.dart';
import '../../../../shared/widgets/viva_logo.dart';

final _matchesProvider =
    FutureProvider.autoDispose<List<ProfileSummary>>((ref) async {
  final client = ref.read(apiClientProvider);
  final response =
      await client.get('/matches', queryParameters: {'limit': 10});
  final data = response.data as Map<String, dynamic>;
  return (data['matches'] as List)
      .map((e) => ProfileSummary.fromJson(e as Map<String, dynamic>))
      .toList();
});

final _userNameProvider = FutureProvider<String?>((ref) async {
  try {
    final client = ref.read(apiClientProvider);
    final response = await client.get('/profile');
    final data = response.data as Map<String, dynamic>;
    final profile = data['profile'] as Map<String, dynamic>?;
    return profile?['full_name'] as String?;
  } catch (_) {
    return null;
  }
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matchesAsync = ref.watch(_matchesProvider);
    final nameAsync = ref.watch(_userNameProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────────
          SliverAppBar(
            floating: true,
            snap: true,
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            shadowColor: AppTheme.shadowColor,
            title: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryContainer,
                  ),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(5),
                      child: VivaLogo(size: 26, variant: VivaLogoVariant.gradient),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Viva',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.notifications_outlined,
                      color: AppTheme.textPrimary, size: 20),
                ),
                onPressed: () => context.push(AppRoutes.notifications),
              ),
              const SizedBox(width: 8),
            ],
          ),

          // ── Greeting + search ─────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  nameAsync.when(
                    loading: () => _GreetingShimmer(),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (name) {
                      final firstName = name?.split(' ').first ?? 'there';
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                                letterSpacing: -0.3,
                              ),
                              children: [
                                TextSpan(text: 'Hello, $firstName '),
                                const TextSpan(text: '👋'),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            AppConstants.appTagline,
                            style: TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // ── Search bar ─────────────────────────────────────
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.search),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: AppShadows.card,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppTheme.primaryContainer,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.sm),
                            ),
                            child: const Icon(Icons.search_rounded,
                                color: AppTheme.primary, size: 18),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Search by name, location, ID…',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppTheme.textTertiary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.full),
                            ),
                            child: const Text(
                              'Search',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── Section header ─────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          gradient: AppTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recommended For You',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            Text(
                              'Based on your preferences',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),

          // ── Matches ────────────────────────────────────────────────
          matchesAsync.when(
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => const _ShimmerCard(),
                childCount: 3,
              ),
            ),
            error: (error, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: ErrorView(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(_matchesProvider),
                ),
              ),
            ),
            data: (matches) => matches.isEmpty
                ? SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: EmptyStateView(
                        icon: Icons.favorite_border_rounded,
                        title: 'No matches yet',
                        subtitle:
                            'Complete your partner preferences to discover better matches.',
                        actionLabel: 'Complete Preferences',
                        onAction: () => context
                            .push(AppRoutes.onboardingPreferences),
                      ),
                    ),
                  )
                : SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final m = matches[index];
                        return ProfileCard(
                          userId: m.userId,
                          name: m.fullName,
                          age: m.age,
                          location: m.location ?? 'India',
                          photoUrl: m.photoUrl,
                          qualification: m.qualification,
                          profession: m.profession,
                          isVerified: m.isVerified,
                          compatibilityScore: m.compatibilityScore,
                          onTap: () => context.push('/profile/${m.userId}'),
                          onInterest: () =>
                              _sendInterest(context, m.userId),
                          onShortlist: () => _shortlist(context, m.userId),
                        );
                      },
                      childCount: matches.length,
                    ),
                  ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _sendInterest(BuildContext context, String userId) {
    context.push('/profile/$userId');
  }

  void _shortlist(BuildContext context, String userId) async {
    try {
      final container = ProviderScope.containerOf(context);
      final client = container.read(apiClientProvider);
      await client.post('/shortlist/$userId');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.bookmark_added_rounded,
                  color: Colors.white, size: 16),
              SizedBox(width: 8),
              Text('Added to shortlist'),
            ],
          ),
          backgroundColor: AppTheme.primary,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Could not shortlist. Please try again.'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }
}

class _GreetingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
              width: 200,
              height: 26,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 8),
          Container(
              width: 160,
              height: 14,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4))),
        ],
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 380,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
        ),
      ),
    );
  }
}
