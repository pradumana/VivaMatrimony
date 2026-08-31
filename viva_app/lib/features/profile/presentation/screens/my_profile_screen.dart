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

final _myProfileProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
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
        body: ErrorView(message: e.toString(), onRetry: () => ref.invalidate(_myProfileProvider)),
      ),
      data: (data) => _ProfileBody(data: data),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  final Map<String, dynamic> data;
  const _ProfileBody({required this.data});

  Map<String, dynamic> get profile => (data['profile'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic>? get location => data['current_location'] as Map<String, dynamic>?;
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
          // Header
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: Colors.white,
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => context.push(AppRoutes.editProfile),
                tooltip: 'Edit Profile',
              ),
              IconButton(
                icon: const Icon(Icons.settings_outlined),
                onPressed: () => context.push(AppRoutes.settings),
                tooltip: 'Settings',
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  photoUrl != null
                      ? CachedNetworkImage(imageUrl: photoUrl!, fit: BoxFit.cover)
                      : Container(color: AppTheme.primaryContainer,
                          child: const Icon(Icons.person_outline, size: 80, color: AppTheme.primary)),
                  // Gradient overlay at bottom
                  Positioned(
                    bottom: 0, left: 0, right: 0,
                    child: Container(
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [Colors.black.withOpacity(0.6), Colors.transparent],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16, left: 16, right: 16,
                    child: Row(children: [
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('$name${age != null ? ", $age" : ""}',
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
                          if (location != null)
                            Text('${location!['city'] ?? ''} ${location!['state'] ?? ''}'.trim(),
                                style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.85))),
                        ],
                      )),
                      if (isVerified) const VerifiedBadge(),
                    ]),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Column(children: [
              // Completion card
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppTheme.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(child: Text('Profile ${completion}% Complete',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))),
                      Text('$completion%', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
                    ]),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: completion / 100,
                      backgroundColor: AppTheme.border,
                      valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    if (memberId != null) ...[
                      const SizedBox(height: 12),
                      _MemberIdBadge(memberId: memberId),
                    ],
                    if (completion < 100) ...[
                      const SizedBox(height: 10),
                      Text(_completionTip(completion),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 10),
                      VivaButton(label: 'Complete Profile', onPressed: () => context.push(AppRoutes.editProfile), height: 40),
                    ],
                  ],
                ),
              ),

              // Quick actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(children: [
                  _QuickAction(icon: Icons.photo_library_outlined, label: 'Photos\n$photoCount added', onTap: () => context.push(AppRoutes.editProfile)),
                  const SizedBox(width: 10),
                  _QuickAction(icon: Icons.picture_as_pdf_outlined, label: 'My\nBiodata', onTap: () => context.push(AppRoutes.biodata)),
                  const SizedBox(width: 10),
                  _QuickAction(icon: isVerified ? Icons.verified : Icons.verified_user_outlined, label: isVerified ? 'Verified ✓' : 'Get\nVerified', onTap: () => context.push(AppRoutes.verificationStatus), color: isVerified ? AppTheme.verifiedBadge : null),
                ]),
              ),
              const SizedBox(height: 16),

              // Profile sections
              _ProfileSection(title: 'Personal', items: _buildPersonal()),
              _ProfileSection(title: 'Education & Career', items: _buildEducation()),
              _ProfileSection(title: 'Family', items: _buildFamily()),

              // Logout
              Padding(
                padding: const EdgeInsets.all(16),
                child: VivaButton(
                  label: 'Log Out',
                  isOutlined: true,
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Log Out?'),
                        content: const Text('You will need to verify your WhatsApp number to log back in.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log Out')),
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
            ]),
          ),
        ],
      ),
    );
  }

  List<_InfoItem> _buildPersonal() {
    final items = <_InfoItem>[];
    if (profile['gender'] != null) items.add(_InfoItem('Gender', (profile['gender'] as String).capitalize));
    if (profile['mother_tongue'] != null) items.add(_InfoItem('Mother Tongue', profile['mother_tongue'] as String));
    if (profile['height_display'] != null) items.add(_InfoItem('Height', profile['height_display'] as String));
    if (profile['marital_status'] != null) items.add(_InfoItem('Marital Status', (profile['marital_status'] as String).replaceAll('_', ' ').capitalize));
    if (profile['religion'] != null) items.add(_InfoItem('Religion', profile['religion'] as String));
    return items;
  }

  List<_InfoItem> _buildEducation() {
    final edu = data['education'] as Map<String, dynamic>?;
    final emp = data['employment'] as Map<String, dynamic>?;
    final items = <_InfoItem>[];
    if (edu?['degree'] != null) items.add(_InfoItem('Degree', edu!['degree'] as String));
    if (emp?['profession'] != null) items.add(_InfoItem('Profession', emp!['profession'] as String));
    if (emp?['company'] != null && (emp!['show_company'] as bool? ?? true)) items.add(_InfoItem('Company', emp['company'] as String));
    return items;
  }

  List<_InfoItem> _buildFamily() {
    final fam = data['family'] as Map<String, dynamic>?;
    if (fam == null) return [];
    return [
      if (fam['family_type'] != null) _InfoItem('Family Type', (fam['family_type'] as String).capitalize),
      if (fam['family_values'] != null) _InfoItem('Values', (fam['family_values'] as String).capitalize),
      _InfoItem('Siblings', '${fam['brothers_count'] ?? 0} Brothers / ${fam['sisters_count'] ?? 0} Sisters'),
    ];
  }

  String _completionTip(int pct) {
    if (pct < 30) return 'Add your education and career details to improve visibility.';
    if (pct < 60) return 'Add family details and a photo to get more matches.';
    if (pct < 80) return 'Add partner preferences for better match recommendations.';
    return 'Get verified to build trust with potential matches.';
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  const _QuickAction({required this.icon, required this.label, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.primary;
    return Expanded(child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: c.withOpacity(0.08),
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: c.withOpacity(0.2)),
        ),
        child: Column(children: [
          Icon(icon, size: 24, color: c),
          const SizedBox(height: 6),
          Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: c, height: 1.3)),
        ]),
      ),
    ));
  }
}

class _ProfileSection extends StatelessWidget {
  final String title;
  final List<_InfoItem> items;
  const _ProfileSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(children: [
              SizedBox(width: 110, child: Text(item.label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary))),
              Expanded(child: Text(item.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            ]),
          )),
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

/// Displays the member ID with a copy-to-clipboard tap.
class _MemberIdBadge extends StatelessWidget {
  final String memberId;
  const _MemberIdBadge({required this.memberId});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Clipboard.setData(ClipboardData(text: memberId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member ID copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 14, color: AppTheme.primary),
            const SizedBox(width: 6),
            Text(
              memberId,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
                letterSpacing: 1,
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.copy_outlined, size: 13, color: AppTheme.primary.withOpacity(0.6)),
          ],
        ),
      ),
    );
  }
}

extension on String {
  String get capitalize => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
