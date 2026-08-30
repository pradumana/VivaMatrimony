import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_button.dart';
import '../providers/onboarding_provider.dart';

class OnboardingPhotosScreen extends ConsumerStatefulWidget {
  const OnboardingPhotosScreen({super.key});
  @override
  ConsumerState<OnboardingPhotosScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingPhotosScreen> {
  final List<Map<String, dynamic>> _photos = [];
  bool _uploading = false;
  String? _error;

  Future<void> _pickPhoto() async {
    if (_photos.length >= AppConstants.maxPhotos) {
      setState(() => _error = 'Maximum ${AppConstants.maxPhotos} photos allowed');
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
      maxHeight: 1500,
    );
    if (picked == null) return;

    setState(() { _uploading = true; _error = null; });

    try {
      final client = ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          picked.path,
          filename: picked.name,
        ),
        'make_primary': _photos.isEmpty,
      });
      final response = await client.postForm('/profile/photos', formData);
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _photos.add({
          'id': data['id'],
          'url': data['url'],
          'is_primary': data['is_primary'],
          'local_path': picked.path,
        });
      });
    } on DioException catch (e) {
      setState(() => _error = ApiException.fromDioError(e).message);
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _deletePhoto(String photoId, int index) async {
    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/profile/photos/$photoId');
      setState(() => _photos.removeAt(index));
    } catch (_) {
      setState(() => _error = 'Could not delete photo. Please try again.');
    }
  }

  Future<void> _done() async {
    if (_photos.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Skip photo?'),
          content: const Text('Profiles with photos get many more responses. Are you sure you want to skip?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Add Photo')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Skip for now')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    await ref.read(onboardingProvider.notifier).completeOnboarding();
    if (mounted) context.go(AppRoutes.verificationSelect);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Profile Photos'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add your photos', style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              const Text('Upload up to 10 photos. Your first photo will be your primary profile photo.', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 24),

              // Photo grid
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 0.75,
                  ),
                  itemCount: _photos.length + (_photos.length < AppConstants.maxPhotos ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _photos.length) {
                      return _AddPhotoCell(
                        onTap: _uploading ? null : _pickPhoto,
                        isLoading: _uploading,
                      );
                    }
                    return _PhotoCell(
                      photo: _photos[index],
                      index: index,
                      onDelete: () => _deletePhoto(_photos[index]['id'], index),
                    );
                  },
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.error)),
              ],

              const SizedBox(height: 16),
              VivaButton(
                label: _photos.isEmpty ? 'Skip for now' : 'Done — Continue to Verification',
                onPressed: _done,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddPhotoCell extends StatelessWidget {
  final VoidCallback? onTap;
  final bool isLoading;
  const _AddPhotoCell({this.onTap, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppTheme.primary.withOpacity(0.3), width: 1.5),
        ),
        child: isLoading
            ? const Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2))
            : const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 28, color: AppTheme.primary),
                  SizedBox(height: 6),
                  Text('Add Photo', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w500)),
                ],
              ),
      ),
    );
  }
}

class _PhotoCell extends StatelessWidget {
  final Map<String, dynamic> photo;
  final int index;
  final VoidCallback onDelete;
  const _PhotoCell({required this.photo, required this.index, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isPrimary = photo['is_primary'] as bool? ?? false;
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: photo['local_path'] != null
              ? Image.file(File(photo['local_path']), fit: BoxFit.cover, width: double.infinity, height: double.infinity)
              : Image.network(photo['url'], fit: BoxFit.cover, width: double.infinity, height: double.infinity),
        ),
        if (isPrimary)
          Positioned(
            bottom: 6, left: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.verifiedBadge.withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: const Text('Primary', style: TextStyle(fontFamily: 'Poppins', fontSize: 9, color: Colors.white, fontWeight: FontWeight.w600)),
            ),
          ),
        Positioned(
          top: 6, right: 6,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              width: 24, height: 24,
              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
