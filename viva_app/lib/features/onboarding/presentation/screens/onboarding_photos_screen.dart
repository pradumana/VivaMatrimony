import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_button.dart';
import '../providers/onboarding_provider.dart';

class OnboardingPhotosScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  const OnboardingPhotosScreen({super.key, this.isEditing = false});

  @override
  ConsumerState<OnboardingPhotosScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingPhotosScreen> {
  // Backing list — each entry is a photo map from the API or a freshly
  // uploaded photo. Using the photo's server ID as the key for all mutations
  // avoids index-shift bugs when multiple operations run close together.
  final List<Map<String, dynamic>> _photos = [];

  bool _uploading = false;
  bool _loading = true;
  bool _loadError = false; // distinguishes "still loading" from "failed"
  // Per-photo operation flags keyed by photo id
  final Set<String> _deletingIds = {};
  final Set<String> _settingPrimaryIds = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadExistingPhotos();
  }

  // ── Data loading ──────────────────────────────────────────────────────────

  Future<void> _loadExistingPhotos() async {
    setState(() {
      _loading = true;
      _loadError = false;
      _photos.clear(); // prevent double-population on hot-restart / retry
    });
    try {
      final client = ref.read(apiClientProvider);
      final r = await client.get('/profile/photos');
      final list = r.data as List<dynamic>;
      if (mounted) {
        setState(() {
          _photos.addAll(
              list.map((e) => Map<String, dynamic>.from(e as Map)));
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = true;
          _error = 'Couldn\'t load your photos. Tap retry to try again.';
        });
      }
    }
  }

  // ── Upload ────────────────────────────────────────────────────────────────

  Future<void> _pickPhoto() async {
    if (_uploading) return; // debounce rapid taps
    if (_photos.length >= AppConstants.maxPhotos) {
      setState(() =>
          _error = 'Maximum ${AppConstants.maxPhotos} photos allowed');
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

    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final client = ref.read(apiClientProvider);
      final formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(
          picked.path,
          filename: picked.name,
        ),
        // FormData requires strings for booleans; Dio serialises Dart bool
        // inconsistently across versions — use explicit string to be safe.
        'make_primary': _photos.isEmpty ? 'true' : 'false',
      });
      final response =
          await client.postForm('/profile/photos', formData);
      final data = response.data as Map<String, dynamic>;
      if (mounted) {
        setState(() {
          _photos.add({
            'id': data['id'],
            'url': data['url'],
            'is_primary': data['is_primary'] ?? _photos.isEmpty,
            'local_path': picked.path,
          });
          // If the server promoted this as primary, demote the others in UI
          if (data['is_primary'] == true) {
            for (final p in _photos) {
              if (p['id'] != data['id']) p['is_primary'] = false;
            }
          }
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() => _error = ApiException.fromDioError(e).message);
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> _confirmDelete(String photoId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl)),
        title: const Text('Delete photo?',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'This photo will be permanently removed from your profile.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    _deletePhoto(photoId);
  }

  Future<void> _deletePhoto(String photoId) async {
    if (_deletingIds.contains(photoId)) return; // already in flight
    setState(() {
      _deletingIds.add(photoId);
      _error = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      await client.delete('/profile/photos/$photoId');
      if (mounted) {
        setState(() {
          _photos.removeWhere((p) => p['id'] == photoId);
          _deletingIds.remove(photoId);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _deletingIds.remove(photoId);
          _error = 'Could not delete photo. Please try again.';
        });
      }
    }
  }

  // ── Set primary ───────────────────────────────────────────────────────────

  Future<void> _setPrimary(String photoId) async {
    if (_settingPrimaryIds.contains(photoId)) return;
    setState(() {
      _settingPrimaryIds.add(photoId);
      _error = null;
    });
    try {
      final client = ref.read(apiClientProvider);
      // Correct endpoint: PUT /profile/photos/{id}/primary
      await client.put('/profile/photos/$photoId/primary');
      if (mounted) {
        setState(() {
          for (final p in _photos) {
            p['is_primary'] = p['id'] == photoId;
          }
          _settingPrimaryIds.remove(photoId);
        });
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _settingPrimaryIds.remove(photoId);
          _error = ApiException.fromDioError(e).message;
        });
      }
    }
  }

  // ── Done / complete ───────────────────────────────────────────────────────

  Future<void> _done() async {
    if (widget.isEditing) {
      if (mounted) context.pop();
      return;
    }

    if (_photos.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xl)),
          title: const Text('Skip photo?',
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: const Text(
              'Profiles with photos get many more responses. Are you sure you want to skip?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Add Photo')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Skip for now')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    await ref.read(onboardingProvider.notifier).completeOnboarding();
    if (mounted) {
      context.go(AppRoutes.verificationSelect);
      await Future.microtask(() {});
      if (mounted) {
        ref
            .read(onboardingProvider.notifier)
            .markAuthenticatedAfterOnboarding();
      }
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final remaining = AppConstants.maxPhotos - _photos.length;
    final canAddMore = _photos.length < AppConstants.maxPhotos;

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
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Header ──────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Your Photos',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _loading
                              ? 'Loading…'
                              : _photos.isEmpty
                                  ? 'Add your first photo to get more matches'
                                  : '$remaining slot${remaining == 1 ? '' : 's'} remaining',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Photo counter pill
                  if (!_loading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${_photos.length} / ${AppConstants.maxPhotos}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // ── Grid ─────────────────────────────────────────────
              Expanded(
                child: _loading
                    ? _buildLoadingGrid()
                    : _loadError
                        ? _buildLoadError()
                        : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 0.75,
                            ),
                            itemCount: _photos.length +
                                (canAddMore ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == _photos.length) {
                                return _AddPhotoCell(
                                  onTap: _uploading
                                      ? null
                                      : _pickPhoto,
                                  isLoading: _uploading,
                                );
                              }
                              final photo = _photos[index];
                              final id = photo['id'] as String;
                              return _PhotoCell(
                                photo: photo,
                                isDeleting:
                                    _deletingIds.contains(id),
                                isSettingPrimary:
                                    _settingPrimaryIds.contains(id),
                                onDelete: () => _confirmDelete(id),
                                onSetPrimary: (photo['is_primary']
                                            as bool? ??
                                        false)
                                    ? null // already primary
                                    : () => _setPrimary(id),
                              );
                            },
                          ),
              ),

              // ── Error banner ──────────────────────────────────────
              if (_error != null && !_loadError) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.25)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline,
                        size: 15, color: AppTheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_error!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.error)),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _error = null),
                      child: const Icon(Icons.close,
                          size: 14, color: AppTheme.error),
                    ),
                  ]),
                ),
              ],

              const SizedBox(height: 14),
              VivaButton(
                label: widget.isEditing
                    ? 'Done'
                    : _photos.isEmpty
                        ? 'Skip for now'
                        : 'Done — Continue',
                onPressed: _done,
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helper widgets ────────────────────────────────────────────────────────

  Widget _buildLoadingGrid() {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.error.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.photo_library_outlined,
                size: 30, color: AppTheme.error),
          ),
          const SizedBox(height: 14),
          const Text(
            'Couldn\'t load photos',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check your connection and try again.',
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _loadExistingPhotos,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }
}

// ── Photo cell ────────────────────────────────────────────────────────────────

class _PhotoCell extends StatelessWidget {
  final Map<String, dynamic> photo;
  final bool isDeleting;
  final bool isSettingPrimary;
  final VoidCallback onDelete;
  final VoidCallback? onSetPrimary; // null when already primary

  const _PhotoCell({
    required this.photo,
    required this.isDeleting,
    required this.isSettingPrimary,
    required this.onDelete,
    this.onSetPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final isPrimary = photo['is_primary'] as bool? ?? false;
    final isBusy = isDeleting || isSettingPrimary;

    return Stack(
      children: [
        // Image
        ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          child: photo['local_path'] != null
              ? Image.file(
                  File(photo['local_path'] as String),
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                )
              : CachedNetworkImage(
                  imageUrl: photo['url'] as String,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                  placeholder: (_, __) => Shimmer.fromColors(
                    baseColor: Colors.grey.shade300,
                    highlightColor: Colors.grey.shade100,
                    child: Container(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => Container(
                    color: AppTheme.surfaceVariant,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: AppTheme.textTertiary, size: 24),
                        SizedBox(height: 4),
                        Text('Failed',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.textTertiary)),
                      ],
                    ),
                  ),
                ),
        ),

        // Busy overlay
        if (isBusy)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              color: Colors.black45,
              child: const Center(
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              ),
            ),
          ),

        // Primary badge (bottom left)
        if (isPrimary)
          Positioned(
            bottom: 6,
            left: 6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.verifiedBadge.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded,
                      size: 9, color: Colors.white),
                  SizedBox(width: 3),
                  Text('Primary',
                      style: TextStyle(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
          ),

        // Actions: delete (top-right), set-primary (top-left)
        if (!isBusy) ...[
          // Delete
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 26,
                height: 26,
                decoration: const BoxDecoration(
                    color: Colors.black54, shape: BoxShape.circle),
                child:
                    const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),

          // Set as primary (top-left) — only shown for non-primary photos
          if (onSetPrimary != null)
            Positioned(
              top: 6,
              left: 6,
              child: GestureDetector(
                onTap: onSetPrimary,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star_border_rounded,
                      size: 14, color: Colors.white),
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ── Add-photo cell ────────────────────────────────────────────────────────────

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
          border: Border.all(
              color: AppTheme.primary.withValues(alpha: 0.3), width: 1.5),
        ),
        child: isLoading
            ? const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primary, strokeWidth: 2))
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add_a_photo_outlined,
                        size: 20, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 8),
                  const Text('Add Photo',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppTheme.primary,
                          fontWeight: FontWeight.w600)),
                ],
              ),
      ),
    );
  }
}
