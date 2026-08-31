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

final _matchesProvider = FutureProvider.autoDispose<List<ProfileSummary>>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/matches', queryParameters: {'limit': 10});
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
          // App bar
          SliverAppBar(
            floating: true,
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 1,
            shadowColor: const Color(0x1A000000),
            title: Row(
              children: [
                const VivaLogo(
                  size: 32,
                  variant: VivaLogoVariant.gradient,
                ),
                const SizedBox(width: 8),
                const Text('Viva', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined, color: AppTheme.textPrimary),
                onPressed: () => context.push(AppRoutes.notifications),
              ),
            ],
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Greeting
                  nameAsync.when(
                    loading: () => const SizedBox(height: 40),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (name) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello, ${name?.split(' ').first ?? 'there'} 👋',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                        const SizedBox(height: 4),
                        Text(AppConstants.appTagline,
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Search CTA
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.search),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8, offset: const Offset(0, 2))],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.search, color: AppTheme.textSecondary, size: 20),
                          const SizedBox(width: 10),
                          const Expanded(child: Text('Search matches by name, location...', style: TextStyle(fontSize: 13, color: AppTheme.textTertiary))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(AppRadius.full)),
                            child: const Text('Search', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  const Text('Recommended For You', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 4),
                  const Text('Based on your preferences', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 4),
                ],
              ),
            ),
          ),

          // Matches list
          matchesAsync.when(
            loading: () => SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) => _ShimmerCard(),
                childCount: 3,
              ),
            ),
            error: (error, _) => SliverToBoxAdapter(
              child: ErrorView(
                message: error.toString(),
                onRetry: () => ref.invalidate(_matchesProvider),
              ),
            ),
            data: (matches) => matches.isEmpty
                ? SliverToBoxAdapter(
                    child: EmptyStateView(
                      icon: Icons.favorite_outline,
                      title: 'No matches yet',
                      subtitle: 'Complete your partner preferences to discover better matches.',
                      actionLabel: 'Complete Preferences',
                      onAction: () => context.push(AppRoutes.onboardingPreferences),
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
                          onInterest: () => _sendInterest(context, m.userId),
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

  void _sendInterest(BuildContext context, String userId) async {
    // Handled in profile detail for confirmation
    context.push('/profile/$userId');
  }

  void _shortlist(BuildContext context, String userId) async {
    // Quick shortlist
    try {
      final container = ProviderScope.containerOf(context);
      final client = container.read(apiClientProvider);
      await client.post('/shortlist/$userId');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Added to shortlist ♡'), backgroundColor: AppTheme.primary),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not shortlist. Please try again.'), backgroundColor: AppTheme.error),
      );
    }
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        height: 320,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
