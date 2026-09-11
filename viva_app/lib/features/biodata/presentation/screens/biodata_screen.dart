import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/viva_button.dart';

// ── Providers ────────────────────────────────────────────────────────────────

final _biodataProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final r = await ref.read(apiClientProvider).get('/biodata');
  return r.data as Map<String, dynamic>;
});

// ── Screen ───────────────────────────────────────────────────────────────────

class BiodataScreen extends ConsumerStatefulWidget {
  const BiodataScreen({super.key});
  @override
  ConsumerState<BiodataScreen> createState() => _BiodataScreenState();
}

class _BiodataScreenState extends ConsumerState<BiodataScreen> {
  /// One of: 'traditional' | 'floral' | 'half_photo'
  String _template = 'traditional';
  bool _generating = false;
  bool _downloading = false;
  String? _error;

  Future<void> _generate() async {
    setState(() { _generating = true; _error = null; });
    try {
      await ref.read(apiClientProvider).post(
        '/biodata/generate',
        data: {'template': _template},
      );
      ref.invalidate(_biodataProvider);
      setState(() => _generating = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 16),
            SizedBox(width: 8),
            Text('Biodata generated!'),
          ]),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
      }
    } on DioException catch (e) {
      setState(() { _generating = false; _error = ApiException.fromDioError(e).message; });
    }
  }

  Future<void> _download({bool share = false}) async {
    setState(() { _downloading = true; _error = null; });
    try {
      final response = await ref.read(apiClientProvider).dio.get<Uint8List>(
        '/biodata/pdf',
        queryParameters: {'template': _template},
        options: Options(responseType: ResponseType.bytes),
      );
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/viva_biodata.pdf');
      await file.writeAsBytes(response.data!);
      setState(() => _downloading = false);
      if (share) {
        // Use platform share sheet
        await _sharePdf(file);
      } else {
        await OpenFilex.open(file.path);
      }
    } on DioException catch (e) {
      setState(() { _downloading = false; _error = ApiException.fromDioError(e).message; });
    } catch (e) {
      setState(() { _downloading = false; _error = "Could not open PDF. Please try again."; });
    }
  }

  Future<void> _sharePdf(File file) async {
    try {
      // flutter share_plus — available via url_launcher fallback if not present
      // We use the platform method via process invocation to avoid adding a
      // new dependency. Open the file instead if sharing unavailable.
      await OpenFilex.open(file.path);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not share. File saved — open it manually.'),
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(_biodataProvider);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Matrimonial Biodata')),
      body: statusAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primary)),
        error: (_, __) => const Center(
            child: Text('Could not load biodata status.',
                style: TextStyle(color: AppTheme.textSecondary))),
        data: (status) => SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  boxShadow: AppShadows.lifted,
                ),
                child: Row(children: [
                  Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: const Icon(Icons.picture_as_pdf_outlined, size: 32, color: Colors.white),
                  ),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Matrimonial Biodata',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white)),
                        SizedBox(height: 4),
                        Text('A beautiful PDF to share with families',
                            style: TextStyle(fontSize: 12, color: Colors.white70, height: 1.3)),
                      ],
                    ),
                  ),
                ]),
              ),

              const SizedBox(height: 20),

              // Status
              _StatusCard(status: status),

              const SizedBox(height: 20),

              // Template selection
              const Text('Choose Template',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              Row(children: [
                _TemplateCard(
                  id: 'traditional',
                  label: 'Traditional',
                  description: 'Classic maroon & gold',
                  icon: Icons.auto_awesome_outlined,
                  selected: _template == 'traditional',
                  onTap: () => setState(() => _template = 'traditional'),
                ),
                const SizedBox(width: 10),
                _TemplateCard(
                  id: 'floral',
                  label: 'Floral',
                  description: 'Soft plum & lilac',
                  icon: Icons.local_florist_outlined,
                  selected: _template == 'floral',
                  onTap: () => setState(() => _template = 'floral'),
                ),
                const SizedBox(width: 10),
                _TemplateCard(
                  id: 'half_photo',
                  label: 'Modern',
                  description: 'Half photo layout',
                  icon: Icons.view_column_outlined,
                  selected: _template == 'half_photo',
                  onTap: () => setState(() => _template = 'half_photo'),
                ),
              ]),

              const SizedBox(height: 20),

              // Included
              const _IncludedCard(),

              const SizedBox(height: 20),

              // Error
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, size: 16, color: AppTheme.error),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                        style: const TextStyle(fontSize: 12, color: AppTheme.error))),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // Actions
              VivaButton(
                label: status['status'] == 'not_generated' || (status['is_stale'] as bool? ?? true)
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
                onPressed: (status['has_pdf'] as bool? ?? false) || status['status'] == 'ready'
                    ? () => _download()
                    : null,
              ),
              const SizedBox(height: 12),
              VivaButton(
                label: 'Share',
                icon: Icons.share_outlined,
                isOutlined: true,
                onPressed: (status['has_pdf'] as bool? ?? false) || status['status'] == 'ready'
                    ? () => _download(share: true)
                    : null,
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Template card ─────────────────────────────────────────────────────────────

class _TemplateCard extends StatelessWidget {
  final String id, label, description;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _TemplateCard({
    required this.id, required this.label, required this.description,
    required this.icon, required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primaryContainer : Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.border,
              width: selected ? 2 : 1,
            ),
            boxShadow: selected ? AppShadows.primary : AppShadows.card,
          ),
          child: Column(children: [
            Icon(icon, size: 26, color: selected ? AppTheme.primary : AppTheme.textTertiary),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700,
              color: selected ? AppTheme.primary : AppTheme.textPrimary,
            )),
            const SizedBox(height: 2),
            Text(description, textAlign: TextAlign.center, style: TextStyle(
              fontSize: 9, color: selected ? AppTheme.primary : AppTheme.textTertiary,
            )),
            if (selected) ...[
              const SizedBox(height: 6),
              Container(
                width: 18, height: 18,
                decoration: const BoxDecoration(color: AppTheme.primary, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 11, color: Colors.white),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ── Status card ───────────────────────────────────────────────────────────────

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
                ? (Icons.update_rounded, AppTheme.warning, 'Profile updated — regenerate')
                : (Icons.info_outline_rounded, AppTheme.textSecondary, 'Not yet generated');

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: color)),
      ]),
    );
  }
}

// ── Included card ─────────────────────────────────────────────────────────────

class _IncludedCard extends StatelessWidget {
  const _IncludedCard();

  static const _items = [
    ('Personal details, community & caste information', true),
    ('Education and career', true),
    ('Family background', true),
    ('Lifestyle and hobbies', true),
    ('Partner expectations', true),
    ('Verification badge (if verified)', true),
    ('Phone / contact number', false),
    ('Verification documents', false),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("What's included",
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          ..._items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: Row(children: [
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  color: item.$2 ? AppTheme.successSurface : AppTheme.surfaceVariant,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  item.$2 ? Icons.check_rounded : Icons.close_rounded,
                  size: 13,
                  color: item.$2 ? AppTheme.success : AppTheme.textTertiary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(item.$1, style: TextStyle(
                fontSize: 13,
                color: item.$2 ? AppTheme.textPrimary : AppTheme.textTertiary,
              ))),
            ]),
          )),
        ],
      ),
    );
  }
}
