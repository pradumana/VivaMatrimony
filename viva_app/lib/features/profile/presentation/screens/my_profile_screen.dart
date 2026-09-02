import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../../shared/widgets/viva_button.dart';

final _myProfileProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.read(apiClientProvider);
  final r = await client.get('/profile');
  return r.data as Map<String, dynamic>;
});

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_myProfileProvider);
    return async.when(
      loading: () => const Scaffold(body: LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(title: const Text('My Profile')),
        body: ErrorView(
            message: e.toString(),
            onRetry: () => ref.invalidate(_myProfileProvider)),
      ),
      data: (data) => _ProfileBody(data: data),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final Map<String, dynamic> data;
  const _ProfileBody({required this.data});

  Map<String, dynamic> get profile =>
      (data['profile'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic>? get location =>
      data['current_location'] as Map<String, dynamic>?;
  String? get photoUrl => data['primary_photo_url'] as String?;
  int get photoCount => data['photo_count'] as int? ?? 0;
  int get completion => profile['completion_percentage'] as int? ?? 0;
  bool get isVerified => profile['is_verified'] as bool? ?? false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile['full_name'] as String? ?? 'Your Profile';
    final age = profile['age'] as int?;
    final memberId = ref.watch(authProvider).valueOrNull?.memberId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── Hero ───────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: Colors.white,
            automaticallyImplyLeading: false,
            actions: [
              _AppBarAction(
                icon: Icons.edit_outlined,
                onTap: () => context.push(AppRoutes.editProfile),
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
                  photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl!, fit: BoxFit.cover)
                      : Container(
                          decoration: const BoxDecoration(
                              gradient: AppTheme.primaryGradient),
                          child: const Icon(Icons.person_outline,
                              size: 80, color: Colors.white54)),
                  // Gradient overlay
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
                            children: [
                              Text(
                                '$name${age != null ? ", $age" : ""}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              if (location != null) ...[
                                const SizedBox(height: 3),
                                Row(children: [
                                  const Icon(Icons.location_on_rounded,
                                      size: 12, color: Colors.white70),
                                  const SizedBox(width: 3),
                                  Text(
                                    '${location!['city'] ?? ''} ${location!['state'] ?? ''}'
                                        .trim(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.white70,
                                    ),
                                  ),
                                ]),
                              ],
                            ],
                          ),
                        ),
                        if (isVerified)
                          const VerifiedBadge(onDark: true),
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
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Profile Completion',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$completion% Complete',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Circular percent
                        SizedBox(
                          width: 52,
                          height: 52,
                          child: Stack(
                            children: [
                              CircularProgressIndicator(
                                value: completion / 100,
                                strokeWidth: 5,
                                backgroundColor: AppTheme.border,
                                valueColor: AlwaysStoppedAnimation(
                                  completion >= 80
                                      ? AppTheme.success
                                      : AppTheme.primary,
                                ),
                              ),
                              Center(
                                child: Text(
                                  '$completion',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ]),

                      // Progress bar
                      const SizedBox(height: 14),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: completion / 100,
                          backgroundColor: AppTheme.border,
                          valueColor: AlwaysStoppedAnimation(
                            completion >= 80
                                ? AppTheme.success
                                : AppTheme.primary,
                          ),
                          minHeight: 6,
                        ),
                      ),

                      if (memberId != null) ...[
                        const SizedBox(height: 14),
                        _MemberIdBadge(memberId: memberId),
                      ],

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
                          onPressed: () =>
                              context.push(AppRoutes.editProfile),
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
                    _QuickAction(
                      icon: Icons.photo_library_outlined,
                      label: 'Photos',
                      value: '$photoCount added',
                      onTap: () => context.push(AppRoutes.onboardingPhotos,
                          extra: true),
                    ),
                    const SizedBox(width: 10),
                    _QuickAction(
                      icon: Icons.picture_as_pdf_outlined,
                      label: 'Biodata',
                      value: 'PDF ready',
                      onTap: () => context.push(AppRoutes.biodata),
                    ),
                    const SizedBox(width: 10),
                    _QuickAction(
                      icon: isVerified
                          ? Icons.verified_rounded
                          : Icons.verified_user_outlined,
                      label: 'Verified',
                      value: isVerified ? '✓ Active' : 'Get verified',
                      onTap: () =>
                          context.push(AppRoutes.verificationStatus),
                      color: isVerified ? AppTheme.verifiedBadge : null,
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
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<_InfoItem> _buildPersonal() {
    final items = <_InfoItem>[];
    if (profile['gender'] != null)
      items.add(_InfoItem('Gender', _cap(profile['gender'] as String)));
    if (profile['mother_tongue'] != null)
      items.add(
          _InfoItem('Mother Tongue', profile['mother_tongue'] as String));
    if (profile['height_display'] != null)
      items.add(_InfoItem('Height', profile['height_display'] as String));
    if (profile['marital_status'] != null)
      items.add(_InfoItem('Marital Status',
          _cap((profile['marital_status'] as String).replaceAll('_', ' '))));
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
      _InfoItem('Siblings',
          '${fam['brothers_count'] ?? 0} Brothers / ${fam['sisters_count'] ?? 0} Sisters'),
    ];
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _completionTip(int pct) {
    if (pct < 30) return 'Add your education and career details to improve visibility.';
    if (pct < 60) return 'Add family details and a photo to get more matches.';
    if (pct < 80) return 'Add partner preferences for better match recommendations.';
    return 'Get verified to build trust with potential matches.';
  }
}

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
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
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
            Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
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
                child: Row(children: [
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
                    child: Text(item.value,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        )),
                  ),
                ]),
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

class _MemberIdBadge extends StatelessWidget {
  final String memberId;
  const _MemberIdBadge({required this.memberId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: memberId));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.copy_rounded, size: 14, color: Colors.white),
              SizedBox(width: 8),
              Text('Member ID copied'),
            ]),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppTheme.textPrimary,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
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
            Text(
              memberId,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppTheme.primary,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.copy_outlined,
                size: 13,
                color: AppTheme.primary.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}
