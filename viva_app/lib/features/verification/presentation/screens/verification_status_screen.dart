import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/viva_button.dart';

final _verificationStatusProvider = FutureProvider<VerificationStatus>((ref) async {
  final client = ref.read(apiClientProvider);
  final response = await client.get('/verification/status');
  return VerificationStatus.fromJson(response.data as Map<String, dynamic>);
});

class VerificationStatusScreen extends ConsumerWidget {
  const VerificationStatusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(_verificationStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verification Status')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Could not load status: $e')),
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
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Main status card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: status.isVerified ? const LinearGradient(colors: [AppTheme.success, Color(0xFF2ECC71)]) : AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.xl),
            ),
            child: Column(
              children: [
                Icon(
                  status.isVerified ? Icons.verified : Icons.hourglass_empty,
                  size: 56, color: Colors.white,
                ),
                const SizedBox(height: 12),
                Text(
                  status.isVerified ? '✓ Verified Profile' : _statusTitle(status),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  _statusSubtitle(status),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.9), height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Details
          if (status.method != null)
            _DetailRow(label: 'Verification Method', value: status.method!.toUpperCase()),
          if (status.requestStatus != null)
            _DetailRow(label: 'Request Status', value: status.requestStatus!.toUpperCase()),
          if (status.certificateStatus != null)
            _DetailRow(label: 'Certificate Status', value: status.certificateStatus!.toUpperCase()),
          if (status.certificateRejectionReason != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.error.withOpacity(0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppTheme.error.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rejection Reason:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.error)),
                  const SizedBox(height: 4),
                  Text(status.certificateRejectionReason!, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 12),
                  VivaButton(label: 'Upload New Certificate', onPressed: () => context.push(AppRoutes.verificationCertificate), height: 42),
                ],
              ),
            ),
          ],

          const SizedBox(height: 32),
          if (!status.isVerified)
            VivaButton(label: 'Change Verification Method', isOutlined: true, onPressed: () => context.push(AppRoutes.verificationSelect)),
          const SizedBox(height: 12),
          VivaButton(label: 'Go to Home', onPressed: () => context.go(AppRoutes.home)),
        ],
      ),
    );
  }

  String _statusTitle(VerificationStatus s) {
    if (s.isPending) return 'Under Review';
    if (s.requestStatus == 'rejected') return 'Verification Rejected';
    return 'Unverified';
  }

  String _statusSubtitle(VerificationStatus s) {
    if (s.isVerified) return 'Your profile is verified. Matches can trust your identity.';
    if (s.isPending) return 'Our team is reviewing your verification request.\nThis usually takes ${AppConstants.verificationSlaDays}.';
    if (s.requestStatus == 'rejected') return 'Your verification was rejected. Please see the reason below and try again.';
    return 'Complete verification to unlock all features and build trust with matches.';
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }
}
