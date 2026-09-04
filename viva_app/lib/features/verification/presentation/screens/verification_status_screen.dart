import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/viva_button.dart';

final _verificationStatusProvider =
    FutureProvider<VerificationStatus>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/verification/status');
  return VerificationStatus.fromJson(
      response.data as Map<String, dynamic>);
});

class VerificationStatusScreen extends ConsumerWidget {
  const VerificationStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(_verificationStatusProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Verification Status')),
      body: statusAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(
            child: Text('Could not load status: $e',
                style: const TextStyle(color: AppTheme.textSecondary))),
        data: (status) => _StatusBody(status: status),
      ),
    );
  }
}

class _StatusBody extends StatelessWidget {
  final VerificationStatus status;
  const _StatusBody({required this.status});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // ── Status hero card ─────────────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: status.isVerified
                  ? const LinearGradient(
                      colors: [AppTheme.success, Color(0xFF2ECC71)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              boxShadow: AppShadows.lifted,
            ),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    status.isVerified
                        ? Icons.verified_rounded
                        : status.isPending
                            ? Icons.hourglass_top_rounded
                            : Icons.shield_outlined,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  status.isVerified
                      ? 'Profile Verified'
                      : _statusTitle(status),
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _statusSubtitle(status),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withValues(alpha: 0.9),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Detail rows ───────────────────────────────────────────
          if (status.method != null ||
              status.requestStatus != null ||
              status.certificateStatus != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                boxShadow: AppShadows.card,
              ),
              child: Column(
                children: [
                  if (status.method != null)
                    _DetailRow(
                        label: 'Method',
                        value: status.method!
                            .replaceAll('_', ' ')
                            .toUpperCase()),
                  if (status.requestStatus != null) ...[
                    if (status.method != null)
                      const Divider(height: 20, color: AppTheme.divider),
                    _DetailRow(
                        label: 'Request Status',
                        value: status.requestStatus!.toUpperCase()),
                  ],
                  if (status.certificateStatus != null) ...[
                    const Divider(height: 20, color: AppTheme.divider),
                    _DetailRow(
                        label: 'Certificate',
                        value: status.certificateStatus!.toUpperCase()),
                  ],
                ],
              ),
            ),

          // Rejection reason
          if (status.certificateRejectionReason != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                    color: AppTheme.error.withValues(alpha: 0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: const [
                    Icon(Icons.error_outline_rounded,
                        size: 16, color: AppTheme.error),
                    SizedBox(width: 8),
                    Text('Rejection Reason',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.error,
                        )),
                  ]),
                  const SizedBox(height: 8),
                  Text(
                    status.certificateRejectionReason!,
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 14),
                  VivaButton(
                    label: 'Upload New Certificate',
                    onPressed: () => context
                        .push(AppRoutes.verificationCertificate),
                    height: 44,
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),

          if (!status.isVerified) ...[
            VivaButton(
              label: 'Change Verification Method',
              isOutlined: true,
              onPressed: () =>
                  context.push(AppRoutes.verificationSelect),
            ),
            const SizedBox(height: 12),
          ],
          VivaButton(
            label: 'Go to Home',
            onPressed: () => context.go(AppRoutes.home),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  String _statusTitle(VerificationStatus s) {
    if (s.isPending) { return 'Under Review'; }
    if (s.requestStatus == 'rejected') { return 'Verification Rejected'; }
    return 'Not Yet Verified';
  }

  String _statusSubtitle(VerificationStatus s) {
    if (s.isVerified) {
      return 'Your profile is verified.\nMatches can trust your identity.';
    }
    if (s.isPending) {
      return 'Our team is reviewing your request.\nThis usually takes ${AppConstants.verificationSlaDays}.';
    }
    if (s.requestStatus == 'rejected') {
      return 'Your verification was rejected.\nSee the reason below and try again.';
    }
    return 'Complete verification to unlock all features\nand build trust with matches.';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label,
          style: const TextStyle(
              fontSize: 13, color: AppTheme.textSecondary)),
      const Spacer(),
      Text(value,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary)),
    ]);
  }
}
