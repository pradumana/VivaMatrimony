import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
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
        loading: () => const Scaffold(body: Center(child: CircularProgressIndicator(color: AppTheme.primary))),
        error: (e, _) => Scaffold(appBar: AppBar(), body: ErrorView(message: e.toString(), onRetry: () => ref.invalidate(_profileDetailProvider(userId)))),
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

  Map<String, dynamic> get profile => (widget.data['profile'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic>? get education => widget.data['education'] as Map<String, dynamic>?;
  Map<String, dynamic>? get employment => widget.data['employment'] as Map<String, dynamic>?;
  Map<String, dynamic>? get family => widget.data['family'] as Map<String, dynamic>?;
  Map<String, dynamic>? get lifestyle => widget.data['lifestyle'] as Map<String, dynamic>?;
  Map<String, dynamic>? get location => widget.data['current_location'] as Map<String, dynamic>?;
  Map<String, dynamic>? get nativePlace => widget.data['native_place'] as Map<String, dynamic>?;
  String? get photoUrl => widget.data['primary_photo_url'] as String?;
  int? get compatScore => widget.data['compatibility_score'] as int?;

  Future<void> _sendInterest() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Send Interest to ${profile['full_name']}?'),
        content: const Text('They will receive a notification and can accept or decline.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Send Interest')),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final client = ref.read(apiClientProvider);
      await client.post('/interests/${widget.userId}');
      setState(() => _interestSent = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Interest sent to ${profile['full_name']}!'), backgroundColor: AppTheme.success),
        );
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(ApiException.fromDioError(e).message), backgroundColor: AppTheme.error),
        );
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
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final name = profile['full_name'] as String? ?? '';
    final age = profile['age'] as int? ?? 0;
    final isVerified = profile['is_verified'] as bool? ?? false;

    return CustomScrollView(
      slivers: [
        // Hero photo + actions
        SliverAppBar(
          expandedHeight: 420,
          pinned: true,
          backgroundColor: Colors.white,
          leading: IconButton(
            icon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.arrow_back_ios_new_rounded, size: 16, color: Colors.white)),
            onPressed: () => context.pop(),
          ),
          actions: [
            IconButton(
              icon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: Icon(_shortlisted ? Icons.bookmark : Icons.bookmark_border, size: 18, color: Colors.white)),
              onPressed: _toggleShortlist,
            ),
            IconButton(
              icon: Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.black45, shape: BoxShape.circle), child: const Icon(Icons.more_vert, size: 18, color: Colors.white)),
              onPressed: () => _showOptions(context),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: photoUrl != null
                ? CachedNetworkImage(imageUrl: photoUrl!, fit: BoxFit.cover)
                : Container(color: AppTheme.surfaceVariant, child: const Icon(Icons.person_outline, size: 80, color: AppTheme.textTertiary)),
          ),
        ),

        SliverToBoxAdapter(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name & badges
                Row(
                  children: [
                    Expanded(child: Text('$name, $age', style: const TextStyle(fontFamily: 'Poppins', fontSize: 24, fontWeight: FontWeight.w700))),
                    if (isVerified) const VerifiedBadge(),
                  ],
                ),
                const SizedBox(height: 4),
                if (location != null)
                  Row(children: [
                    const Icon(Icons.location_on_outlined, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text('${location!['city'] ?? ''} ${location!['state'] ?? ''}'.trim(), style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.textSecondary)),
                  ]),
                if (employment?['profession'] != null || education?['highest_qualification'] != null) ...[
                  const SizedBox(height: 4),
                  Text([employment?['profession'], education?['degree']].where((e) => e != null).join(' • '), style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.textSecondary)),
                ],

                // Compatibility
                if (compatScore != null) ...[
                  const SizedBox(height: 12),
                  _CompatibilityBar(score: compatScore!),
                ],

                // CTA buttons
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: VivaButton(
                        label: _interestSent ? '✓ Interest Sent' : '❤️ Send Interest',
                        onPressed: _interestSent ? null : _sendInterest,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),

        // Profile sections
        SliverList(
          delegate: SliverChildListDelegate([
            if (profile['about_me'] != null)
              _Section(title: 'About Me', child: Text(profile['about_me'] as String, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, color: AppTheme.textPrimary, height: 1.6))),

            _Section(title: 'Personal Details', child: _Grid([
              _Field('Age', '$age years'),
              if (profile['height_display'] != null) _Field('Height', profile['height_display'] as String),
              _Field('Marital Status', (profile['marital_status'] as String? ?? '').replaceAll('_', ' ').toUpperCase().split(' ').map((w) => w.isEmpty ? w : '${w[0]}${w.substring(1).toLowerCase()}').join(' ')),
              if (profile['mother_tongue'] != null) _Field('Mother Tongue', profile['mother_tongue'] as String),
              if (profile['religion'] != null) _Field('Religion', profile['religion'] as String),
              if (profile['caste'] != null) _Field('Community', profile['caste'] as String),
              if (nativePlace != null) _Field('Native Place', '${nativePlace!['city'] ?? ''}, ${nativePlace!['state'] ?? ''}'.trim().removePrefix(', ')),
            ])),

            if (education != null)
              _Section(title: 'Education', child: _Grid([
                if (education!['degree'] != null) _Field('Degree', education!['degree'] as String),
                if (education!['field_of_study'] != null) _Field('Field', education!['field_of_study'] as String),
                if (education!['college_university'] != null) _Field('College', education!['college_university'] as String),
              ])),

            if (employment != null)
              _Section(title: 'Career', child: _Grid([
                if (employment!['profession'] != null) _Field('Profession', employment!['profession'] as String),
                if (employment!['company'] != null) _Field('Company', employment!['company'] as String),
                if (employment!['income_min_lpa'] != null) _Field('Income', '₹${employment!['income_min_lpa']} LPA'),
              ])),

            if (family != null)
              _Section(title: 'Family', child: _Grid([
                if (family!['family_type'] != null) _Field('Family Type', (family!['family_type'] as String).capitalize),
                if (family!['family_values'] != null) _Field('Values', (family!['family_values'] as String).capitalize),
                _Field('Siblings', '${family!['brothers_count'] ?? 0}B / ${family!['sisters_count'] ?? 0}S'),
              ])),

            if (lifestyle != null)
              _Section(title: 'Lifestyle', child: _Grid([
                if (lifestyle!['diet'] != null) _Field('Diet', (lifestyle!['diet'] as String).replaceAll('_', ' ').capitalize),
                if (lifestyle!['smoking'] != null) _Field('Smoking', (lifestyle!['smoking'] as String).capitalize),
                if (lifestyle!['drinking'] != null) _Field('Drinking', (lifestyle!['drinking'] as String).capitalize),
              ])),

            const SizedBox(height: 100),
          ]),
        ),
      ],
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: AppTheme.error),
              title: const Text('Report Profile'),
              onTap: () { Navigator.pop(context); context.push('/report/${widget.userId}'); },
            ),
            ListTile(
              leading: const Icon(Icons.block, color: AppTheme.error),
              title: const Text('Block User'),
              onTap: () async {
                Navigator.pop(context);
                await ref.read(apiClientProvider).post('/users/${widget.userId}/block');
                if (mounted) context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CompatibilityBar extends StatelessWidget {
  final int score;
  const _CompatibilityBar({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 80 ? AppTheme.success : score >= 60 ? AppTheme.warning : AppTheme.primary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.md), border: Border.all(color: color.withOpacity(0.25))),
      child: Row(
        children: [
          Icon(Icons.favorite, size: 16, color: color),
          const SizedBox(width: 8),
          Text('$score% Compatible', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600, color: color)),
          const Spacer(),
          Text('Based on preferences', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: color.withOpacity(0.7))),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          const SizedBox(height: 12),
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
      spacing: 16, runSpacing: 12,
      children: fields.map((f) => SizedBox(width: (MediaQuery.of(context).size.width - 80) / 2, child: f)).toList(),
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
        Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppTheme.textTertiary, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: AppTheme.textPrimary)),
      ],
    );
  }
}

extension _StringExt on String {
  String get capitalize => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
  String removePrefix(String prefix) => startsWith(prefix) ? substring(prefix.length) : this;
}
