import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/profile_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/verified_badge.dart';
import '../../../../shared/widgets/viva_button.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

/// Biodata status is independent of profile — keep its own provider so
/// refreshing biodata doesn't re-fetch the full profile.
/// Let errors propagate so the UI can distinguish "not generated" from
/// "server unreachable" (issue #2).
final _biodataStatusProvider =
    FutureProvider.autoDispose<String>((ref) async {
  final r = await ref.read(apiClientProvider).get('/biodata');
  final data = r.data;
  if (data is! Map<String, dynamic>) {
    throw const FormatException('Invalid biodata response');
  }
  return data['status'] as String? ?? 'not_generated';
});

// ── Safe casting helpers (issue #3) ──────────────────────────────────────────

String? _str(dynamic v) => (v as Object?)?.toString().trim();

int _int(dynamic v, {int fallback = 0}) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v == null ? '' : v.toString()) ?? fallback;
}

bool _bool(dynamic v, {bool fallback = false}) {
  if (v is bool) return v;
  if (v is String) return v.toLowerCase() == 'true';
  if (v is num) return v != 0;
  return fallback;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myProfileProvider);
    final l = AppLocalizations.of(context);
    return async.when(
      loading: () => Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: Text(l.myProfile),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: l.logOut,
              onPressed: () => _confirmLogout(context, ref, l),
            ),
          ],
        ),
        body: const _SkeletonBody(),
      ),
      error: (e, _) => Scaffold(
        appBar: AppBar(
          title: Text(l.myProfile),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout_rounded),
              tooltip: l.logOut,
              onPressed: () => _confirmLogout(context, ref, l),
            ),
          ],
        ),
        body: ErrorView(
          message: 'Couldn\'t load your profile.',
          retryLabel: 'Try Again',
          onRetry: () => ref.invalidate(myProfileProvider),
        ),
      ),
      data: (data) => _ProfileBody(data: data),
    );
  }

  Future<void> _confirmLogout(
      BuildContext context, WidgetRef ref, AppLocalizations l) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Log Out?'),
        content: const Text(
            'You can log back in using your registered account credentials.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.cancel)),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.logOut)),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(authProvider.notifier).logout();
    }
  }
}

// ── Skeleton shown during initial load ────────────────────────────────────────

class _SkeletonBody extends StatelessWidget {
  const _SkeletonBody();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey.shade200,
      highlightColor: Colors.grey.shade100,
      child: SingleChildScrollView(
        physics: const NeverScrollableScrollPhysics(),
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
            const SizedBox(height: 14),
            // Who viewed me
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              height: 60,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
            ),
            const SizedBox(height: 14),
            // Profile sections (3 placeholders)
            ...List.generate(
              3,
              (_) => Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
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

class _ProfileBody extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const _ProfileBody({required this.data});

  @override
  ConsumerState<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends ConsumerState<_ProfileBody> {
  Map<String, dynamic> get profile =>
      (widget.data['profile'] as Map<String, dynamic>?) ?? {};
  Map<String, dynamic>? get location =>
      widget.data['current_location'] as Map<String, dynamic>?;
  String? get photoUrl => widget.data['primary_photo_url'] as String?;

  // issue #3: safe cast
  int get photoCount => _int(widget.data['photo_count']);

  // issue #4: clamp once, use everywhere (display and progress bar both see clamped value)
  int get completion =>
      _int(profile['completion_percentage']).clamp(0, 100);

  bool get isVerified => _bool(profile['is_verified']);

  // ── Route-specific navigation helpers (issue #9) ───────────────────────────

  Future<void> _goAndRefreshProfile(String route, {Object? extra}) async {
    await context.push(route, extra: extra);
    if (!mounted) return;
    ref.invalidate(myProfileProvider);
  }

  Future<void> _goAndRefreshBiodata() async {
    await context.push(AppRoutes.biodata);
    if (!mounted) return;
    ref.invalidate(_biodataStatusProvider);
  }

  Future<void> _goAndRefreshVerification() async {
    await context.push(AppRoutes.verificationStatus);
    if (!mounted) return;
    ref.invalidate(myProfileProvider);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final name = _str(profile['full_name']);
    final age = profile['age'] == null ? null : _int(profile['age']);
    final memberId = ref.watch(authProvider).valueOrNull?.memberId;
    final biodataAsync = ref.watch(_biodataStatusProvider);

    // issue #1: use the raw status string from the profile response;
    // the backend now returns verification_status (unverified/pending/verified/rejected).
    final rawVerifStatus =
        _str(profile['verification_status']) ?? 'unverified';
    final verificationAsync = AsyncValue.data(rawVerifStatus);

    // Location string — guard empty parts
    final city = _str(location?['city']) ?? '';
    final state = _str(location?['state']) ?? '';
    final locationStr = [city, state].where((s) => s.isNotEmpty).join(', ');

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: RefreshIndicator(
        // issue #28: pull-to-refresh
        onRefresh: () async {
          ref.invalidate(myProfileProvider);
          ref.invalidate(_biodataStatusProvider);
          await ref.read(myProfileProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            // ── Hero ─────────────────────────────────────────────────
            SliverAppBar(
              expandedHeight: 300,
              pinned: true,
              backgroundColor: Colors.white,
              automaticallyImplyLeading: false,
              actions: [
                // issue #11/#13: IconButton gives 48dp target + tooltip
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: Colors.white),
                  tooltip: 'Edit profile',
                  onPressed: () => _goAndRefreshProfile(AppRoutes.editProfile),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white),
                  tooltip: 'Settings',
                  onPressed: () => context.push(AppRoutes.settings),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                ),
                const SizedBox(width: 4),
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
                        // issue #16: hint decoder to profile-display width
                        memCacheWidth:
                            (MediaQuery.sizeOf(context).width * 2).round(),
                        placeholder: (_, __) => _heroPicturePlaceholder(name),
                        errorWidget: (_, __, ___) =>
                            _heroPicturePlaceholder(name),
                      )
                    else
                      _heroPicturePlaceholder(name),

                    // issue #17: top scrim so edit/settings icons are always legible
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

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
                              Colors.black.withValues(alpha: 0.7),
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    completion == 100
                                        ? l.profileComplete
                                        : completion == 0
                                            ? 'Let\'s complete your profile'
                                            : l.profileCompletion,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  // issue #4: completion is already clamped
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
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(AppRadius.full),
                          child: LinearProgressIndicator(
                            value: completion / 100,
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

                        if (memberId != null && memberId.isNotEmpty) ...[
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
                            label: l.completeProfile,
                            onPressed: () =>
                                _goAndRefreshProfile(AppRoutes.editProfile),
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
                        onTap: () => _goAndRefreshProfile(
                            AppRoutes.onboardingPhotos,
                            extra: true),
                      ),
                      const SizedBox(width: 10),

                      // Biodata — issue #2: error state now exposed
                      biodataAsync.when(
                        loading: () => _QuickAction(
                          icon: Icons.picture_as_pdf_outlined,
                          label: 'Biodata',
                          value: '…',
                          onTap: _goAndRefreshBiodata,
                        ),
                        error: (_, __) => _QuickAction(
                          icon: Icons.picture_as_pdf_outlined,
                          label: 'Biodata',
                          value: 'Unable to check',
                          onTap: _goAndRefreshBiodata,
                          color: AppTheme.warning,
                        ),
                        data: (s) => _QuickAction(
                          icon: Icons.picture_as_pdf_outlined,
                          label: 'Biodata',
                          value: s == 'ready' ? 'PDF ready' : 'Not generated',
                          onTap: _goAndRefreshBiodata,
                          color: s == 'ready' ? AppTheme.success : null,
                        ),
                      ),
                      const SizedBox(width: 10),

                      // Verification — issue #1: real status from profile
                      verificationAsync.when(
                        loading: () => _QuickAction(
                          icon: Icons.verified_user_outlined,
                          label: 'Verified',
                          value: '…',
                          onTap: _goAndRefreshVerification,
                        ),
                        error: (_, __) => _QuickAction(
                          icon: Icons.verified_user_outlined,
                          label: 'Verified',
                          value: 'Check status',
                          onTap: _goAndRefreshVerification,
                        ),
                        data: (status) {
                          final (icon, label, color) =
                              _verificationDisplay(status);
                          return _QuickAction(
                            icon: icon,
                            label: 'Verified',
                            value: label,
                            onTap: _goAndRefreshVerification,
                            color: color,
                          );
                        },
                      ),
                    ]),
                  ),

                  const SizedBox(height: 14),

                  // ── Who viewed me ─────────────────────────────────────
                  // issue #12: InkWell for ripple + semantics
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        onTap: () => _goAndRefreshProfile(AppRoutes.whoViewedMe),
                        child: Ink(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            boxShadow: AppShadows.card,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(14),
                            child: Row(children: [
                              const Icon(Icons.visibility_outlined,
                                  size: 20, color: AppTheme.primary),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(l.whoViewedMe,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600)),
                                    const Text(
                                        'See who recently visited your profile',
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.textSecondary)),
                                  ],
                                ),
                              ),
                              const Icon(Icons.chevron_right_rounded,
                                  color: AppTheme.textTertiary, size: 20),
                            ]),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Profile sections ──────────────────────────────────
                  _ProfileSection(
                      title: l.personalDetails,
                      icon: Icons.person_outline_rounded,
                      items: _buildPersonal()),
                  _ProfileSection(
                      title: l.community,
                      icon: Icons.diversity_3_outlined,
                      items: _buildCommunity(l)),
                  _ProfileSection(
                      title: '${l.education} & ${l.career}',
                      icon: Icons.school_outlined,
                      items: _buildEducation()),
                  _ProfileSection(
                      title: l.family,
                      icon: Icons.family_restroom_outlined,
                      items: _buildFamily()),

                  const SizedBox(height: 14),

                  // ── Logout ────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: VivaButton(
                      label: l.logOut,
                      isOutlined: true,
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(AppRadius.xl)),
                            // issue #7: corrected logout dialog message
                            title: const Text('Log Out?'),
                            content: const Text(
                                'You can log back in using your registered account credentials.'),
                            actions: [
                              TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: Text(l.cancel)),
                              ElevatedButton(
                                  onPressed: () =>
                                      Navigator.pop(context, true),
                                  child: Text(l.logOut)),
                            ],
                          ),
                        );
                        if (confirm == true) {
                          await ref.read(authProvider.notifier).logout();
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  // issue #18: use name initial in the placeholder
  Widget _heroPicturePlaceholder(String? name) {
    final initial =
        (name != null && name.isNotEmpty) ? name[0].toUpperCase() : null;
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
                color: Colors.white.withValues(alpha: 0.2),
              ),
              child: initial != null
                  ? Center(
                      child: Text(
                        initial,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : const Icon(Icons.person_outline_rounded,
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

  // Maps raw verification_status → (icon, display label, colour)
  (IconData, String, Color?) _verificationDisplay(String status) =>
      switch (status) {
        'verified' => (
            Icons.verified_rounded,
            'Verified',
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

  // issue #3: safe casts in all _build* methods
  List<_InfoItem> _buildPersonal() {
    final items = <_InfoItem>[];
    final gender = _str(profile['gender']);
    if (gender != null) items.add(_InfoItem('Gender', _cap(gender)));
    final tongue = _str(profile['mother_tongue']);
    if (tongue != null) items.add(_InfoItem('Mother Tongue', tongue));
    final height = _str(profile['height_display']);
    if (height != null) items.add(_InfoItem('Height', height));
    final marital = _str(profile['marital_status']);
    if (marital != null) {
      items.add(_InfoItem(
          'Marital Status', _cap(marital.replaceAll('_', ' '))));
    }
    final religion = _str(profile['religion']);
    if (religion != null) items.add(_InfoItem('Religion', religion));
    return items;
  }

  List<_InfoItem> _buildCommunity(AppLocalizations l) {
    final items = <_InfoItem>[];
    final caste = _str(profile['caste']);
    if (caste != null) items.add(_InfoItem(l.caste, caste));
    final sub = _str(profile['sub_caste']);
    if (sub != null) items.add(_InfoItem(l.subCaste, sub));
    final gotra = _str(profile['gotra']);
    if (gotra != null) items.add(_InfoItem(l.gotra, gotra));
    return items;
  }

  List<_InfoItem> _buildEducation() {
    final edu = widget.data['education'] as Map<String, dynamic>?;
    final emp = widget.data['employment'] as Map<String, dynamic>?;
    final items = <_InfoItem>[];
    final degree = _str(edu?['degree']);
    if (degree != null) items.add(_InfoItem('Degree', degree));
    final profession = _str(emp?['profession']);
    if (profession != null) items.add(_InfoItem('Profession', profession));
    // issue #6: safe bool cast for show_company
    if (emp != null &&
        _str(emp['company']) != null &&
        _bool(emp['show_company'], fallback: true)) {
      items.add(_InfoItem('Company', _str(emp['company'])!));
    }
    return items;
  }

  List<_InfoItem> _buildFamily() {
    final fam = widget.data['family'] as Map<String, dynamic>?;
    if (fam == null) return [];
    final items = <_InfoItem>[];
    final famType = _str(fam['family_type']);
    if (famType != null) items.add(_InfoItem('Family Type', _cap(famType)));
    final values = _str(fam['family_values']);
    if (values != null) items.add(_InfoItem('Values', _cap(values)));
    // issue #5: only show siblings when at least one count is explicitly set
    final hasBrothers = fam['brothers_count'] != null;
    final hasSisters = fam['sisters_count'] != null;
    if (hasBrothers || hasSisters) {
      items.add(_InfoItem(
        'Siblings',
        '${_int(fam['brothers_count'])} Brothers'
            ' / ${_int(fam['sisters_count'])} Sisters',
      ));
    }
    return items;
  }

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  String _completionTip(int pct) {
    if (pct == 0) return 'Start by adding your basic information.';
    if (pct < 30) {
      return 'Add your education and career details to improve visibility.';
    }
    if (pct < 60) {
      return 'Add family details and a photo to get more matches.';
    }
    if (pct < 80) {
      return 'Add partner preferences for better match recommendations.';
    }
    return 'Get verified to build trust with potential matches.';
  }
}

// ── Reusable sub-widgets ──────────────────────────────────────────────────────

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
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          // issue #12: ripple on quick-action tiles
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: onTap,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppShadows.card,
            ),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
              child: Column(children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: c.withValues(alpha: 0.1),
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

// ── Member ID badge with copy feedback ───────────────────────────────────────

class _MemberIdBadgeState extends State<_MemberIdBadge> {
  bool _copied = false;
  // issue #23: cancellable timer instead of fire-and-forget Future.delayed
  Timer? _resetTimer;

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }

  void _copy() {
    if (_copied) return;
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
    _resetTimer = Timer(
      const Duration(seconds: 2),
      () { if (mounted) setState(() => _copied = false); },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      // issue #23: semantic tooltip
      message: 'Copy member ID',
      child: GestureDetector(
        onTap: _copy,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.full),
            border:
                Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.badge_outlined,
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
                        key: ValueKey('check'),
                        size: 13,
                        color: AppTheme.success)
                    : Icon(Icons.copy_outlined,
                        key: const ValueKey('copy'),
                        size: 13,
                        color: AppTheme.primary.withValues(alpha: 0.6)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MemberIdBadge extends StatefulWidget {
  final String memberId;
  const _MemberIdBadge({required this.memberId});

  @override
  State<_MemberIdBadge> createState() => _MemberIdBadgeState();
}
