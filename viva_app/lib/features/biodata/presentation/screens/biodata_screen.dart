import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/viva_button.dart';

final _biodataStatusProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
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
  String? _savedPath;

  Future<void> _generate() async {
    setState(() { _generating = true; _error = null; });
    try {
      await ref.read(apiClientProvider).post('/biodata/generate');
      ref.invalidate(_biodataStatusProvider);
      setState(() { _generating = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Biodata generated successfully!'), backgroundColor: AppTheme.success));
    } on DioException catch (e) {
      setState(() { _generating = false; _error = ApiException.fromDioError(e).message; });
    }
  }

  Future<void> _download() async {
    setState(() { _downloading = true; _error = null; });
    try {
      final client = ref.read(apiClientProvider);
      // Download PDF bytes
      final response = await client.dio.get<Uint8List>(
        '/biodata/pdf',
        options: Options(responseType: ResponseType.bytes),
      );

      // Save to device
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/viva_biodata.pdf');
      await file.writeAsBytes(response.data!);
      setState(() { _downloading = false; _savedPath = file.path; });

      // Open PDF using url_launcher
      final uri = Uri.file(file.path);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    } on DioException catch (e) {
      setState(() { _downloading = false; _error = ApiException.fromDioError(e).message; });
    } catch (e) {
      setState(() { _downloading = false; _error = 'We couldn\'t generate your biodata. Please try again.'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(_biodataStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Matrimonial Biodata')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (e, _) => Center(child: Text('Could not load biodata status.')),
        data: (status) => SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Column(children: [
                  const Icon(Icons.picture_as_pdf_outlined, size: 56, color: Colors.white),
                  const SizedBox(height: 12),
                  const Text('Matrimonial Biodata', style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('A beautiful PDF ready to share with families', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: Colors.white.withOpacity(0.85))),
                ]),
              ),
              const SizedBox(height: 24),

              // Status
              _StatusCard(status: status),
              const SizedBox(height: 20),

              // What's included
              const Text('What\'s included', style: TextStyle(fontFamily: 'Poppins', fontSize: 15, fontWeight: FontWeight.w600)),
              const SizedBox(height: 12),
              for (final item in [
                '✓  Profile photo and personal details',
                '✓  Education and career information',
                '✓  Family background',
                '✓  Lifestyle and hobbies',
                '✓  Partner expectations',
                '✓  Verification badge (if verified)',
                '✗  Phone number (kept private)',
                '✗  Verification documents',
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(item, style: TextStyle(
                    fontFamily: 'Poppins', fontSize: 13,
                    color: item.startsWith('✗') ? AppTheme.textTertiary : AppTheme.textPrimary,
                  )),
                ),
              const SizedBox(height: 28),

              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
                  child: Text(_error!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.error)),
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              VivaButton(
                label: status['status'] == 'not_generated' || (status['is_stale'] as bool? ?? true) ? 'Generate Biodata' : 'Regenerate Biodata',
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
                onPressed: (status['has_pdf'] as bool? ?? false) || status['status'] == 'ready' ? _download : null,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
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

    IconData icon;
    Color color;
    String label;

    if (s == 'ready' && !isStale) {
      icon = Icons.check_circle_outline; color = AppTheme.success; label = 'Biodata ready';
    } else if (s == 'generating') {
      icon = Icons.hourglass_empty; color = AppTheme.warning; label = 'Generating…';
    } else if (isStale && s == 'ready') {
      icon = Icons.update; color = AppTheme.warning; label = 'Profile updated — regenerate to refresh';
    } else {
      icon = Icons.info_outline; color = AppTheme.textSecondary; label = 'Not yet generated';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w500, color: color)),
      ]),
    );
  }
}
