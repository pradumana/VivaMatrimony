import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/viva_button.dart';

class ReportScreen extends ConsumerStatefulWidget {
  final String reportedUserId;
  const ReportScreen({super.key, required this.reportedUserId});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  static const _reasons = [
    ('fake_profile', 'Fake Profile'),
    ('fraud', 'Fraud or Scam'),
    ('harassment', 'Harassment'),
    ('impersonation', 'Impersonation'),
    ('offensive_content', 'Offensive Content'),
    ('financial_solicitation', 'Financial Solicitation'),
    ('suspicious_behavior', 'Suspicious Behavior'),
    ('other', 'Other'),
  ];

  String? _selectedReason;
  final _descController = TextEditingController();
  bool _loading = false;
  bool _submitted = false;

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason'), backgroundColor: AppTheme.error),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post(
        '/reports',
        data: {
          'reason': _selectedReason,
          'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        },
        queryParameters: {'reported_user_id': widget.reportedUserId},
      );
      setState(() { _loading = false; _submitted = true; });
    } on DioException catch (e) {
      setState(() => _loading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiException.fromDioError(e).message), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _SuccessView(onDone: () => context.pop());

    return Scaffold(
      appBar: AppBar(title: const Text('Report Profile')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Warning notice
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.warning.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppTheme.warning.withOpacity(0.3)),
                ),
                child: const Row(children: [
                  Icon(Icons.info_outline, size: 18, color: AppTheme.warning),
                  SizedBox(width: 10),
                  Expanded(child: Text('All reports are reviewed by our team. False reports may result in account action.', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, height: 1.4, color: AppTheme.textSecondary))),
                ]),
              ),
              const SizedBox(height: 24),
              const Text('Select reason', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),

              Expanded(
                child: ListView(children: [
                  ..._reasons.map((r) => RadioListTile<String>(
                    value: r.$1,
                    groupValue: _selectedReason,
                    onChanged: (v) => setState(() => _selectedReason = v),
                    title: Text(r.$2, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14)),
                    activeColor: AppTheme.primary,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  )),
                  const SizedBox(height: 16),
                  const Text('Additional details (optional)', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _descController,
                    maxLines: 4,
                    maxLength: 500,
                    decoration: const InputDecoration(hintText: 'Describe what happened...'),
                  ),
                ]),
              ),
              const SizedBox(height: 16),
              VivaButton(label: 'Submit Report', isLoading: _loading, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final VoidCallback onDone;
  const _SuccessView({required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 80, height: 80, decoration: const BoxDecoration(color: Color(0xFFE8F8EF), shape: BoxShape.circle),
              child: const Icon(Icons.check_circle_outline, size: 44, color: AppTheme.success)),
            const SizedBox(height: 20),
            const Text('Report Submitted', style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            const Text('Thank you. Our team will review your report within 24-48 hours and take appropriate action.', textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
            const SizedBox(height: 32),
            VivaButton(label: 'Go Back', onPressed: onDone),
          ]),
        ),
      ),
    );
  }
}
