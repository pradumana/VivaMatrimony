import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../../shared/widgets/viva_button.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _myProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.read(apiClientProvider);
  final r = await client.get('/profile');
  return r.data as Map<String, dynamic>;
});

/// Separate provider so verification status refresh is independent.
final _verificationStatusProvider =
    FutureProvider.autoDispose<String>((ref) async {
  try {
    final client = ref.read(apiClientProvider);
    final r = await client.get('/verification/status');
    final data = r.data as Map<String, dynamic>;
    // Returns one of: 'verified', 'pending', 'rejected', 'unverified'
    return data['verification_status'] as String? ?? 'unverified';
  } catch (_) {
    return 'unverified';
  }
});

/// Separate provider so biodata status refresh is independent.
final _biodataStatusProvider =
    FutureProvider.autoDispose<String>((ref) async {
  try {
    final client = ref.read(apiClientProvider);
    final r = await client.get('/biodata');
    final status = (r.data as Map<String, dynamic>)['status'] as String?;
    return status ?? 'not_generated';
  } catch (_) {
    return 'not_generated';
  }
});

// ── Screen ────────────────────────────────────────────────────────────────────

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myProfileProvider);
    return async.when(
      loading: () => const _SkeletonScreen(),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: ErrorView(
          message: 'Couldn\'t load your profile.',
          retryLabel: 'Try Again',
          onRetry: () => ref.invalidate(_myProfileProvider),
        ),
      ),
      data: (data) => _ProfileBody(data: data),
    );
  }
}

// ── Skeleton shown during initial load (avoids null-flash) ────────────────────

class _SkeletonScreen extends StatelessWidget {
  const _SkeletonScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: Column(
          children: [
            // Hero area
            Container(height: 300, color: Colors.white),
            const SizedBox(height: 16),
            // Completion card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            const SizedBox(height: 14),
            // Quick actions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(
                  3,
                  (_) => Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 5),
                      height: 90,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Body ──────────────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  final Map<String, dynamic> data;
  const _ProfileBody({required this.data});

  Map<String, dynamic> get profile =>
      (data['profile'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic>? get location =>
      data['current_location'] as Map<String, dynamic>?;
  String? get photoUrl => data['primary_photo_url'] as String?;
  int get photoCount => data['photo_count'] as int? ?? 0;
  // Backend completion_percentage; never hardcode.
  int get completion => profile['completion_percentage'] as int? ?? 0;
  bool get isVerified => profile['is_verified'] as bool? ?? false;

  // ── Navigation helpers that invalidate the profile cache on return ──────────
  Future<void> _goAndRefresh(
      BuildContext context, WidgetRef ref, String route,
      {Object? extra}) async {
    await context.push(route, extra: extra);
    // Invalidate so the profile reflects any changes made in the sub-screen.
    ref.invalidate(_myProfileProvider);
    ref.invalidate(_verificationStatusProvider);
    ref.invalidate(_biodataStatusProvider);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = (profile['full_name'] as String?)?.trim();
    final age = profile['age'] as int?;
    final memberId = ref.watch(authProvider).valueOrNull?.memberId;
    final verificationAsync = ref.watch(_verificationStatusProvider);
    final biodataAsync = ref.watch(_biodataStatusProvider);

    // Location string — guard empty parts
    final city = (location?['city'] as String?)?.trim() ?? '';
    final state = (location?['state'] as String?)?.trim() ?? '';
    final locationStr = [city, state].where((s) => s.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero ─────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            automaticallyImplyLeading: false,
            actions: [
              _AppBarAction(
                icon: Icons.edit_outlined,
                onTap: () => _goAndRefresh(context, ref, AppRoutes.editProfile),
              ),
              const SizedBox(width: 4),
              _AppBarAction(
                icon: Icons.settings_outlined,
                onTap: () => context.push(AppRoutes.settings),
              ),
              const SizedBox(width: 8),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Photo or placeholder
                  if (photoUrl != null)
                    CachedNetworkImage(
                      imageUrl: photoUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _heroPicturePlaceholder(name),
                      errorWidget: (_, __, ___) => _heroPicturePlaceholder(name),
                    )
                  else
                    _heroPicturePlaceholder(name),

                  // Bottom gradient
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Name + location over photo
                  if (name != null || locationStr.isNotEmpty)
                    Positioned(
                      bottom: 16,
                      left: 16,
                      right: 16,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (name != null && name.isNotEmpty)
                                  Text(
                                    age != null ? '$name, $age' : name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                if (locationStr.isNotEmpty) ...[
                                  const SizedBox(height: 3),
                                  Row(children: [
                                    const Icon(Icons.location_on_rounded,
                                        size: 12, color: Colors.white70),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        locationStr,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          color: Colors.white70,
                                        ),
                                      ),
                                    ),
                                  ]),
                                ],
                              ],
                            ),
                          ),
                          if (isVerified)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: VerifiedBadge(onDark: true),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              children: [
                // ── Completion card ──────────────────────────────────
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    boxShadow: AppShadows.card,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label + percentage (single display — no circular duplicate)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  completion == 100
                                      ? 'Profile Complete ✓'
                                      : completion == 0
                                          ? 'Let\'s complete your profile'
                                          : 'Profile Completion',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$completion%',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: completion == 100
                                        ? AppTheme.success
                                        : AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // Completion colour indicator dot (no duplicate number)
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: completion == 100
                                  ? AppTheme.success
                                  : completion >= 60
                                      ? AppTheme.warning
                                      : AppTheme.primary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      // Single progress bar
                      ClipRRect(
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: (completion.clamp(0, 100)) / 100,
                          backgroundColor: AppTheme.border,
                          valueColor: AlwaysStoppedAnimation(
                            completion == 100
                                ? AppTheme.success
                                : completion >= 60
                                    ? AppTheme.warning
                                    : AppTheme.primary,
                          ),
                          minHeight: 7,
                        ),
                      ),

                      // Member ID
                      if (memberId != null && memberId.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _MemberIdBadge(memberId: memberId),
                      ],

                      // CTA — only when < 100%
                      if (completion < 100) ...[
                        const SizedBox(height: 12),
                        Text(
                          _completionTip(completion),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        VivaButton(
                          label: 'Complete Profile',
                          onPressed: () => _goAndRefresh(
                              context, ref, AppRoutes.editProfile),
                          height: 42,
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Quick actions ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(children: [
                    // Photos
                    _QuickAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Photos',
                      value: photoCount == 0
                          ? 'None added'
                          : photoCount == 1
                              ? '1 photo'
                              : '$photoCount photos',
                      onTap: () => _goAndRefresh(
                          context, ref, AppRoutes.onboardingPhotos,
                          extra: true),
                    ),
                    const SizedBox(width: 10),

                    // Biodata
                    biodataAsync.when(
                      loading: () => _QuickAction(
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'Biodata',
                        value: '…',
                        onTap: () => _goAndRefresh(
                            context, ref, AppRoutes.biodata),
                      ),
                      error: (_, __) => _QuickAction(
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'Biodata',
                        value: 'Tap to create',
                        onTap: () => _goAndRefresh(
                            context, ref, AppRoutes.biodata),
                      ),
                      data: (s) => _QuickAction(
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'Biodata',
                        value: s == 'ready' ? 'PDF ready' : 'Not generated',
                        onTap: () => _goAndRefresh(
                            context, ref, AppRoutes.biodata),
                        color: s == 'ready' ? AppTheme.success : null,
                      ),
                    ),
                    const SizedBox(width: 10),

                    // Verification — shows real state from server
                    verificationAsync.when(
                      loading: () => _QuickAction(
                        icon: Icons.verified_user_outlined,
                        label: 'Verified',
                        value: '…',
                        onTap: () => _goAndRefresh(
                            context, ref, AppRoutes.verificationStatus),
                      ),
                      error: (_, __) => _QuickAction(
                        icon: Icons.verified_user_outlined,
                        label: 'Verified',
                        value: 'Check status',
                        onTap: () => _goAndRefresh(
                            context, ref, AppRoutes.verificationStatus),
                      ),
                      data: (status) {
                        final (icon, label, color) = _verificationDisplay(status);
                        return _QuickAction(
                          icon: icon,
                          label: 'Verified',
                          value: label,
                          onTap: () => _goAndRefresh(
                              context, ref, AppRoutes.verificationStatus),
                          color: color,
                        );
                      },
                    ),
                  ]),
                ),

                const SizedBox(height: 14),

                // ── Profile sections ──────────────────────────────────
                _ProfileSection(
                    title: 'Personal',
                    icon: Icons.person_outline_rounded,
                    items: _buildPersonal()),
                _ProfileSection(
                    title: 'Education & Career',
                    icon: Icons.school_outlined,
                    items: _buildEducation()),
                _ProfileSection(
                    title: 'Family',
                    icon: Icons.family_restroom_outlined,
                    items: _buildFamily()),

                const SizedBox(height: 14),

                // ── Logout ────────────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: VivaButton(
                    label: 'Log Out',
                    isOutlined: true,
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xl)),
                          title: const Text('Log Out?'),
                          content: const Text(
                              'You will need to verify your WhatsApp number to log back in.'),
                          actions: [
                            TextButton(
                                onPressed: () =>
                                    Navigator.pop(context, false),
                                child: const Text('Cancel')),
                            ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(context, true),
                                child: const Text('Log Out')),
                          ],
                        ),
                      );
                      if (confirm == true) {
                        await ref.read(authProvider.notifier).logout();
                      }
                    },
                  ),
                ),
                // Extra bottom padding so content is never behind the nav bar
                const SizedBox(height: 100),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Widget _heroPicturePlaceholder(String? name) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.primaryGradient),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.2),
              ),
              child: const Icon(Icons.person_outline_rounded,
                  size: 40, color: Colors.white70),
            ),
            const SizedBox(height: 10),
            const Text(
              'Add a profile photo',
              style: TextStyle(fontSize: 13, color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }

  // Maps raw verification_status string → (icon, display label, colour)
  (IconData, String, Color?) _verificationDisplay(String status) =>
      switch (status) {
        'verified' => (
            Icons.verified_rounded,
            '✓ Verified',
            AppTheme.verifiedBadge,
          ),
        'pending' => (
            Icons.hourglass_top_rounded,
            'Under review',
            AppTheme.warning,
          ),
        'rejected' => (
            Icons.warning_amber_rounded,
            'Needs attention',
            AppTheme.error,
          ),
        _ => (
            Icons.verified_user_outlined,
            'Get verified',
            null,
          ),
      };

  List<_InfoItem> _buildPersonal() {
    final items = <_InfoItem>[];
    if (profile['gender'] != null)
      items.add(_InfoItem('Gender', _cap(profile['gender'] as String)));
    if (profile['mother_tongue'] != null)
      items.add(_InfoItem(
          'Mother Tongue', profile['mother_tongue'] as String));
    if (profile['height_display'] != null)
      items.add(
          _InfoItem('Height', profile['height_display'] as String));
    if (profile['marital_status'] != null)
      items.add(_InfoItem(
          'Marital Status',
          _cap((profile['marital_status'] as String)
              .replaceAll('_', ' '))));
    if (profile['religion'] != null)
      items.add(_InfoItem('Religion', profile['religion'] as String));
    return items;
  }

  List<_InfoItem> _buildEducation() {
    final edu = data['education'] as Map<String, dynamic>?;
    final emp = data['employment'] as Map<String, dynamic>?;
    final items = <_InfoItem>[];
    if (edu?['degree'] != null)
      items.add(_InfoItem('Degree', edu!['degree'] as String));
    if (emp?['profession'] != null)
      items.add(_InfoItem('Profession', emp!['profession'] as String));
    if (emp?['company'] != null &&
        (emp!['show_company'] as bool? ?? true))
      items.add(_InfoItem('Company', emp['company'] as String));
    return items;
  }

  List<_InfoItem> _buildFamily() {
    final fam = data['family'] as Map<String, dynamic>?;
    if (fam == null) return [];
    return [
      if (fam['family_type'] != null)
        _InfoItem('Family Type', _cap(fam['family_type'] as String)),
      if (fam['family_values'] != null)
        _InfoItem('Values', _cap(fam['family_values'] as String)),
      _InfoItem(
          'Siblings',
          '${fam['brothers_count'] ?? 0} Brothers'
              ' / ${fam['sisters_count'] ?? 0} Sisters'),
    ];
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _completionTip(int pct) {
    if (pct == 0)
      return 'Start by adding your basic information.';
    if (pct < 30)
      return 'Add your education and career details to improve visibility.';
    if (pct < 60)
      return 'Add family details and a photo to get more matches.';
    if (pct < 80)
      return 'Add partner preferences for better match recommendations.';
    return 'Get verified to build trust with potential matches.';
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

class _AppBarAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _AppBarAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 38,
        height: 38,
        margin: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color? color;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: Column(children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: c),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary)),
            const SizedBox(height: 2),
            Text(
              value,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: color ?? AppTheme.textSecondary,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<_InfoItem> items;
  const _ProfileSection(
      {required this.title, required this.icon, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(icon, size: 14, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Text(title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  )),
            ]),
          ),
          const Divider(height: 1, color: AppTheme.divider),
          ...items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 110,
                      child: Text(item.label,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w400,
                          )),
                    ),
                    Expanded(
                      child: Text(
                        item.value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                        // Long values wrap instead of overflowing
                        softWrap: true,
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _InfoItem {
  final String label;
  final String value;
  const _InfoItem(this.label, this.value);
}

// ── Member ID badge with debounced copy feedback ──────────────────────────────

class _MemberIdBadge extends StatefulWidget {
  final String memberId;
  const _MemberIdBadge({required this.memberId});

  @override
  State<_MemberIdBadge> createState() => _MemberIdBadgeState();
}

class _MemberIdBadgeState extends State<_MemberIdBadge> {
  bool _copied = false;

  void _copy() {
    if (_copied) return; // debounce: ignore taps while feedback is showing
    Clipboard.setData(ClipboardData(text: widget.memberId));
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(children: [
          Icon(Icons.copy_rounded, size: 14, color: Colors.white),
          SizedBox(width: 8),
          Text('Member ID copied'),
        ]),
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppTheme.textPrimary,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
    Future.delayed(const Duration(seconds: 2),
        () { if (mounted) setState(() => _copied = false); });
  }

  @override
  Widget build(BuildContext context) {
    // Guard overflow: constrain width, ellipsis on very long IDs
    return GestureDetector(
      onTap: _copy,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
              color: AppTheme.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined,
                size: 14, color: AppTheme.primary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                widget.memberId,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                  letterSpacing: 1.2,
                ),
              ),
            ),
            const SizedBox(width: 6),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: _copied
                  ? const Icon(Icons.check_rounded,
                      key: ValueKey('check'), size: 13, color: AppTheme.success)
                  : Icon(Icons.copy_outlined,
                      key: const ValueKey('copy'),
                      size: 13,
                      color: AppTheme.primary.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }
}
