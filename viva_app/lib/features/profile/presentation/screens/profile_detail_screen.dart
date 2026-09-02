import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../../shared/widgets/viva_button.dart';

final _profileDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/profile/$userId');
  return response.data as Map<String, dynamic>;
});

class ProfileDetailScreen extends ConsumerWidget {
  final String userId;
  const ProfileDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(_profileDetailProvider(userId));

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: profileAsync.when(
        loading: () => const Scaffold(
            body: Center(
                child: CircularProgressIndicator(color: AppTheme.primary))),
        error: (e, _) => Scaffold(
            appBar: AppBar(),
            body: ErrorView(
                message: e.toString(),
                onRetry: () =>
                    ref.invalidate(_profileDetailProvider(userId)))),
        data: (data) => _ProfileBody(userId: userId, data: data),
      ),
    );
  }
}

class _ProfileBody extends ConsumerStatefulWidget {
  final String userId;
  final Map<String, dynamic> data;
  const _ProfileBody({required this.userId, required this.data});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  bool _interestSent = false;
  bool _shortlisted = false;

  Map<String, dynamic> get profile =>
      (widget.data['profile'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic>? get education =>
      widget.data['education'] as Map<String, dynamic>?;
  Map<String, dynamic>? get employment =>
      widget.data['employment'] as Map<String, dynamic>?;
  Map<String, dynamic>? get family =>
      widget.data['family'] as Map<String, dynamic>?;
  Map<String, dynamic>? get lifestyle =>
      widget.data['lifestyle'] as Map<String, dynamic>?;
  Map<String, dynamic>? get location =>
      widget.data['current_location'] as Map<String, dynamic>?;
  Map<String, dynamic>? get nativePlace =>
      widget.data['native_place'] as Map<String, dynamic>?;
  String? get photoUrl => widget.data['primary_photo_url'] as String?;
  int? get compatScore => widget.data['compatibility_score'] as int?;
  String? get memberId => widget.data['member_id'] as String?;

  Future<void> _sendInterest() async {
    final name = profile['full_name'] as String? ?? '';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: Text(
            'Send Interest${name.isNotEmpty ? ' to $name' : ''}?'),
        content: const Text(
            'They will receive a notification and can accept or decline.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Send Interest')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final client = ref.read(apiClientProvider);
      await client.post('/interests/${widget.userId}');
      setState(() => _interestSent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              name.isNotEmpty ? 'Interest sent to $name!' : 'Interest sent!'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiException.fromDioError(e).message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  Future<void> _toggleShortlist() async {
    try {
      final client = ref.read(apiClientProvider);
      if (_shortlisted) {
        await client.delete('/shortlist/${widget.userId}');
      } else {
        await client.post('/shortlist/${widget.userId}');
      }
      setState(() => _shortlisted = !_shortlisted);
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiException.fromDioError(e).message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = profile['full_name'] as String? ?? '';
    final age = profile['age'] as int? ?? 0;
    final isVerified = profile['is_verified'] as bool? ?? false;

    return Stack(
      children: [
        CustomScrollView(
          slivers: [
            // ── Hero photo ──────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 440,
              pinned: true,
              backgroundColor: Colors.white,
              leading: Padding(
                padding: const EdgeInsets.all(8),
                child: GestureDetector(
                  onTap: () => context.pop(),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.35),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 16, color: Colors.white),
                  ),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: GestureDetector(
                    onTap: _toggleShortlist,
                    child: Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _shortlisted
                            ? Icons.bookmark_rounded
                            : Icons.bookmark_border_rounded,
                        size: 18,
                        color: _shortlisted
                            ? AppTheme.secondary
                            : Colors.white,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => _showOptions(context),
                    child: Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.more_vert,
                          size: 18, color: Colors.white),
                    ),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                background: photoUrl != null
                    ? CachedNetworkImage(
                        imageUrl: photoUrl!, fit: BoxFit.cover)
                    : Container(
                        color: AppTheme.primaryContainer,
                        child: const Icon(Icons.person_outline,
                            size: 80, color: AppTheme.primary)),
              ),
            ),

            // ── Name + basic info ───────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$name, $age',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.textPrimary,
                                  letterSpacing: -0.4,
                                ),
                              ),
                              if (memberId != null) ...[
                                const SizedBox(height: 4),
                                Row(children: [
                                  const Icon(Icons.badge_outlined,
                                      size: 13,
                                      color: AppTheme.textSecondary),
                                  const SizedBox(width: 4),
                                  Text(memberId!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppTheme.textSecondary,
                                        letterSpacing: 0.8,
                                      )),
                                ]),
                              ],
                            ],
                          ),
                        ),
                        if (isVerified) const VerifiedBadge(),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Meta chips row
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (location != null)
                          _MetaChip(
                            icon: Icons.location_on_outlined,
                            label:
                                '${location!['city'] ?? ''} ${location!['state'] ?? ''}'
                                    .trim(),
                          ),
                        if (employment?['profession'] != null)
                          _MetaChip(
                            icon: Icons.work_outline_rounded,
                            label: employment!['profession'] as String,
                          ),
                        if (education?['degree'] != null)
                          _MetaChip(
                            icon: Icons.school_outlined,
                            label: education!['degree'] as String,
                          ),
                      ],
                    ),

                    // Compatibility
                    if (compatScore != null) ...[
                      const SizedBox(height: 14),
                      _CompatibilityBar(score: compatScore!),
                    ],

                    const SizedBox(height: 20),
                    // CTA
                    VivaButton(
                      label: _interestSent
                          ? '✓ Interest Sent'
                          : '❤️  Send Interest',
                      onPressed: _interestSent ? null : _sendInterest,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ── Profile sections ────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (profile['about_me'] != null)
                    _Section(
                      title: 'About',
                      icon: Icons.person_outline_rounded,
                      child: Text(
                        profile['about_me'] as String,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textPrimary,
                          height: 1.65,
                        ),
                      ),
                    ),

                  _Section(
                    title: 'Personal Details',
                    icon: Icons.info_outline_rounded,
                    child: _Grid([
                      _Field('Age', '$age years'),
                      if (profile['height_display'] != null)
                        _Field('Height',
                            profile['height_display'] as String),
                      _Field(
                          'Marital Status',
                          (profile['marital_status'] as String? ?? '')
                              .replaceAll('_', ' ')
                              .toUpperCase()
                              .split(' ')
                              .map((w) => w.isEmpty
                                  ? w
                                  : '${w[0]}${w.substring(1).toLowerCase()}')
                              .join(' ')),
                      if (profile['mother_tongue'] != null)
                        _Field('Mother Tongue',
                            profile['mother_tongue'] as String),
                      if (profile['religion'] != null)
                        _Field('Religion', profile['religion'] as String),
                      if (profile['caste'] != null)
                        _Field('Community', profile['caste'] as String),
                      if (nativePlace != null)
                        _Field(
                            'Native Place',
                            '${nativePlace!['city'] ?? ''}, ${nativePlace!['state'] ?? ''}'
                                .trim()
                                .removePrefix(', ')),
                    ]),
                  ),

                  if (education != null)
                    _Section(
                      title: 'Education',
                      icon: Icons.school_outlined,
                      child: _Grid([
                        if (education!['degree'] != null)
                          _Field('Degree', education!['degree'] as String),
                        if (education!['field_of_study'] != null)
                          _Field('Field',
                              education!['field_of_study'] as String),
                        if (education!['college_university'] != null)
                          _Field('College',
                              education!['college_university'] as String),
                      ]),
                    ),

                  if (employment != null)
                    _Section(
                      title: 'Career',
                      icon: Icons.work_outline_rounded,
                      child: _Grid([
                        if (employment!['profession'] != null)
                          _Field('Profession',
                              employment!['profession'] as String),
                        if (employment!['company'] != null)
                          _Field('Company',
                              employment!['company'] as String),
                        if (employment!['income_min_lpa'] != null)
                          _Field('Income',
                              '₹${employment!['income_min_lpa']} LPA'),
                      ]),
                    ),

                  if (family != null)
                    _Section(
                      title: 'Family',
                      icon: Icons.family_restroom_outlined,
                      child: _Grid([
                        if (family!['family_type'] != null)
                          _Field('Family Type',
                              (family!['family_type'] as String).capitalize),
                        if (family!['family_values'] != null)
                          _Field('Values',
                              (family!['family_values'] as String).capitalize),
                        _Field('Siblings',
                            '${family!['brothers_count'] ?? 0}B / ${family!['sisters_count'] ?? 0}S'),
                      ]),
                    ),

                  if (lifestyle != null)
                    _Section(
                      title: 'Lifestyle',
                      icon: Icons.spa_outlined,
                      child: _Grid([
                        if (lifestyle!['diet'] != null)
                          _Field(
                              'Diet',
                              (lifestyle!['diet'] as String)
                                  .replaceAll('_', ' ')
                                  .capitalize),
                        if (lifestyle!['smoking'] != null)
                          _Field('Smoking',
                              (lifestyle!['smoking'] as String).capitalize),
                        if (lifestyle!['drinking'] != null)
                          _Field('Drinking',
                              (lifestyle!['drinking'] as String).capitalize),
                      ]),
                    ),
                ]),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.flag_outlined,
                      color: AppTheme.error, size: 18),
                ),
                title: const Text('Report Profile',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/report/${widget.userId}');
                },
              ),
              ListTile(
                leading: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.block_rounded,
                      color: AppTheme.error, size: 18),
                ),
                title: const Text('Block User',
                    style: TextStyle(fontWeight: FontWeight.w500)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    await ref
                        .read(apiClientProvider)
                        .post('/users/${widget.userId}/block');
                    if (mounted) context.pop();
                  } on DioException catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(ApiException.fromDioError(e).message),
                        backgroundColor: AppTheme.error,
                        behavior: SnackBarBehavior.floating,
                      ));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppTheme.textSecondary),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompatibilityBar extends StatelessWidget {
  final int score;
  const _CompatibilityBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80
        ? AppTheme.success
        : score >= 60
            ? AppTheme.warning
            : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.favorite_rounded, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            '$score% Compatible',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const Spacer(),
          Text(
            'Based on preferences',
            style: TextStyle(
              fontSize: 11,
              color: color.withOpacity(0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  const _Section(
      {required this.title, required this.icon, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Icon(icon, size: 15, color: AppTheme.primary),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Grid extends StatelessWidget {
  final List<_Field> fields;
  const _Grid(this.fields);

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 16,
      runSpacing: 14,
      children: fields
          .map((f) => SizedBox(
              width: (MediaQuery.of(context).size.width - 96) / 2,
              child: f))
          .toList(),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final String value;
  const _Field(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            color: AppTheme.textTertiary,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}

extension _StringExt on String {
  String get capitalize =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
  String removePrefix(String prefix) =>
      startsWith(prefix) ? substring(prefix.length) : this;
}
