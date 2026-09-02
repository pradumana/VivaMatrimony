import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/viva_button.dart';

final _biodataStatusProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final client = ref.read(apiClientProvider);
  final r = await client.get('/biodata');
  return r.data as Map<String, dynamic>;
});

class BiodataScreen extends ConsumerStatefulWidget {
  const BiodataScreen({super.key});

  @override
  ConsumerState<BiodataScreen> createState() => _BiodataScreenState();
}

class _BiodataScreenState extends ConsumerState<BiodataScreen> {
  bool _generating = false;
  bool _downloading = false;
  String? _error;

  Future<void> _generate() async {
    setState(() {
      _generating = true;
      _error = null;
    });
    try {
      await ref.read(apiClientProvider).post('/biodata/generate');
      ref.invalidate(_biodataStatusProvider);
      setState(() => _generating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline_rounded,
                color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Biodata generated successfully!'),
          ]),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ));
      }
    } on DioException catch (e) {
      setState(() {
        _generating = false;
        _error = ApiException.fromDioError(e).message;
      });
    }
  }

  Future<void> _download() async {
    setState(() {
      _downloading = true;
      _error = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      final response = await client.dio.get<Uint8List>(
        '/biodata/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/viva_biodata.pdf');
      await file.writeAsBytes(response.data!);
      setState(() => _downloading = false);
      await OpenFilex.open(file.path);
    } on DioException catch (e) {
      setState(() {
        _downloading = false;
        _error = ApiException.fromDioError(e).message;
      });
    } catch (e) {
      setState(() {
        _downloading = false;
        _error = 'Could not open PDF: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(_biodataStatusProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Matrimonial Biodata')),
      body: statusAsync.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => const Center(
            child: Text('Could not load biodata status.',
                style: TextStyle(color: AppTheme.textSecondary))),
        data: (status) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero card ───────────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.lifted,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius:
                            BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(Icons.picture_as_pdf_outlined,
                          size: 32, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Matrimonial Biodata',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'A beautiful PDF ready to share with families',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.85),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Status
              _StatusCard(status: status),

              const SizedBox(height: 20),

              // ── What's included ──────────────────────────────────
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.card,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "What's included",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ..._included
                        .map((item) => _IncludedRow(
                            label: item.$1, included: item.$2))
                        .toList(),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Error
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppTheme.error.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: AppTheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                        child: Text(_error!,
                            style: const TextStyle(
                                fontSize: 12, color: AppTheme.error))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              VivaButton(
                label: status['status'] == 'not_generated' ||
                        (status['is_stale'] as bool? ?? true)
                    ? 'Generate Biodata'
                    : 'Regenerate Biodata',
                icon: Icons.refresh_rounded,
                isLoading: _generating,
                onPressed: _generate,
              ),
              const SizedBox(height: 12),
              VivaButton(
                label: 'Download PDF',
                icon: Icons.download_rounded,
                isLoading: _downloading,
                isOutlined: status['status'] != 'ready',
                onPressed: (status['has_pdf'] as bool? ?? false) ||
                        status['status'] == 'ready'
                    ? _download
                    : null,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  static const _included = [
    ('Profile photo and personal details', true),
    ('Education and career information', true),
    ('Family background', true),
    ('Lifestyle and hobbies', true),
    ('Partner expectations', true),
    ('Verification badge (if verified)', true),
    ('Phone number (kept private)', false),
    ('Verification documents', false),
  ];
}

class _IncludedRow extends StatelessWidget {
  final String label;
  final bool included;
  const _IncludedRow({required this.label, required this.included});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(children: [
        Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: included
                ? AppTheme.successSurface
                : AppTheme.surfaceVariant,
            shape: BoxShape.circle,
          ),
          child: Icon(
            included
                ? Icons.check_rounded
                : Icons.close_rounded,
            size: 13,
            color: included
                ? AppTheme.success
                : AppTheme.textTertiary,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: included
                ? AppTheme.textPrimary
                : AppTheme.textTertiary,
          ),
        ),
      ]),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final Map<String, dynamic> status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final s = status['status'] as String? ?? 'not_generated';
    final isStale = status['is_stale'] as bool? ?? true;

    final (icon, color, label) = s == 'ready' && !isStale
        ? (Icons.check_circle_outline_rounded, AppTheme.success, 'Biodata ready to download')
        : s == 'generating'
            ? (Icons.hourglass_top_rounded, AppTheme.warning, 'Generating…')
            : isStale && s == 'ready'
                ? (Icons.update_rounded, AppTheme.warning, 'Profile updated — regenerate to refresh')
                : (Icons.info_outline_rounded, AppTheme.textSecondary, 'Not yet generated');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color)),
      ]),
    );
  }
}
