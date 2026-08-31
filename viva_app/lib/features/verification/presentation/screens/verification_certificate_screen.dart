import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_button.dart';

class VerificationCertificateScreen extends ConsumerStatefulWidget {
  const VerificationCertificateScreen({super.key});
  @override
  ConsumerState<VerificationCertificateScreen> createState() => _State();
}

class _State extends ConsumerState<VerificationCertificateScreen> {
  PlatformFile? _pickedFile;
  bool _loading = false;
  bool _uploaded = false;
  String? _error;
  double _progress = 0;

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );
    if (result == null || result.files.isEmpty) return;
    setState(() { _pickedFile = result.files.first; _error = null; });
  }

  Future<void> _upload() async {
    if (_pickedFile == null) {
      setState(() => _error = 'Please select a file first');
      return;
    }
    setState(() { _loading = true; _error = null; _progress = 0; });

    try {
      final client = ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'certificate': await MultipartFile.fromFile(
          _pickedFile!.path!,
          filename: _pickedFile!.name,
        ),
      });
      await client.postForm(
        '/verification/certificate',
        formData,
        onSendProgress: (sent, total) {
          if (total > 0) setState(() => _progress = sent / total);
        },
      );
      setState(() { _loading = false; _uploaded = true; });
    } on DioException catch (e) {
      setState(() { _loading = false; _error = ApiException.fromDioError(e).message; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Upload Certificate'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _uploaded ? _SuccessView(onDone: () => context.go(AppRoutes.verificationStatus)) : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Upload Caste Certificate', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              const Text('Your certificate is stored securely and reviewed only by our admin team. It is never shared publicly.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 24),

              // Security note
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.success.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppTheme.success.withOpacity(0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_outline, size: 20, color: AppTheme.success),
                    SizedBox(width: 10),
                    Expanded(child: Text('Your document is stored in a private, encrypted vault. Only authorized admins can view it.', style: TextStyle(fontSize: 12, color: AppTheme.success, height: 1.4))),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Accepted formats
              Text('Accepted formats: PDF, JPG, PNG (max ${AppConstants.maxCertSizeMB}MB)', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 16),

              // File picker
              GestureDetector(
                onTap: _loading ? null : _pickFile,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: _pickedFile != null ? AppTheme.primaryContainer : AppTheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: _pickedFile != null ? AppTheme.primary : AppTheme.border,
                      width: 1.5,
                      style: BorderStyle.solid,
                    ),
                  ),
                  child: _pickedFile != null ? Row(
                    children: [
                      const Icon(Icons.insert_drive_file_outlined, size: 36, color: AppTheme.primary),
                      const SizedBox(width: 14),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_pickedFile!.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                          Text('${(_pickedFile!.size / 1024).toStringAsFixed(0)} KB', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        ],
                      )),
                      IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => setState(() => _pickedFile = null)),
                    ],
                  ) : const Column(
                    children: [
                      Icon(Icons.cloud_upload_outlined, size: 44, color: AppTheme.primary),
                      SizedBox(height: 10),
                      Text('Tap to choose file', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                      SizedBox(height: 4),
                      Text('PDF, JPG, PNG supported', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
              ),

              if (_loading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(value: _progress, backgroundColor: AppTheme.border, valueColor: const AlwaysStoppedAnimation(AppTheme.primary), borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 8),
                Text('Uploading... ${(_progress * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],

              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(fontSize: 12, color: AppTheme.error)),
              ],

              const Spacer(),
              VivaButton(label: 'Upload Certificate', isLoading: _loading && _progress == 0, onPressed: _pickedFile != null ? _upload : null),
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
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(color: AppTheme.successSurface, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline, size: 44, color: AppTheme.success),
        ),
        const SizedBox(height: 20),
        const Text('Certificate Uploaded!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Your certificate is under review.\nVerification typically takes ${AppConstants.verificationSlaDays}.', textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
        const SizedBox(height: 32),
        VivaButton(label: 'Continue to Home', onPressed: onDone),
      ],
    );
  }
}
