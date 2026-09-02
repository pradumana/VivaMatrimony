import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/theme/app_theme.dart';
import 'verified_badge.dart';

/// Match/Search result profile card — premium matrimony style.
class ProfileCard extends StatelessWidget {
  final String userId;
  final String name;
  final int age;
  final String location;
  final String? photoUrl;
  final String? qualification;
  final String? profession;
  final bool isVerified;
  final int? compatibilityScore;
  final VoidCallback? onTap;
  final VoidCallback? onInterest;
  final VoidCallback? onShortlist;
  final bool isShortlisted;

  const ProfileCard({
    super.key,
    required this.userId,
    required this.name,
    required this.age,
    required this.location,
    this.photoUrl,
    this.qualification,
    this.profession,
    this.isVerified = false,
    this.compatibilityScore,
    this.onTap,
    this.onInterest,
    this.onShortlist,
    this.isShortlisted = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: AppShadows.card,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Photo area with overlay info ─────────────────────────
            _buildPhotoWithOverlay(),

            // ── Details ───────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Education / profession pill row
                  if (qualification != null || profession != null)
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        if (profession != null)
                          _InfoPill(
                              icon: Icons.work_outline_rounded,
                              label: profession!),
                        if (qualification != null)
                          _InfoPill(
                              icon: Icons.school_outlined,
                              label: qualification!),
                      ],
                    ),

                  if (qualification != null || profession != null)
                    const SizedBox(height: 12),

                  // Compatibility
                  if (compatibilityScore != null) ...[
                    _buildCompatibility(compatibilityScore!),
                    const SizedBox(height: 12),
                  ],

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _PrimaryActionButton(
                          label: 'Send Interest',
                          icon: Icons.favorite_border_rounded,
                          onTap: onInterest,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ShortlistButton(
                        isShortlisted: isShortlisted,
                        onTap: onShortlist,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoWithOverlay() {
    return Stack(
      children: [
        // Photo
        AspectRatio(
          aspectRatio: 3 / 4,
          child: photoUrl != null
              ? CachedNetworkImage(
                  imageUrl: photoUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Shimmer.fromColors(
                    baseColor: Colors.grey.shade200,
                    highlightColor: Colors.grey.shade100,
                    child: Container(color: Colors.white),
                  ),
                  errorWidget: (_, __, ___) => _photoPlaceholder(),
                )
              : _photoPlaceholder(),
        ),

        // Bottom gradient overlay
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 110,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.72),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Name + location over photo
        Positioned(
          bottom: 14,
          left: 14,
          right: 14,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      '$name, $age',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                        shadows: [
                          Shadow(
                              color: Colors.black45,
                              blurRadius: 4,
                              offset: Offset(0, 1))
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isVerified)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: VerifiedBadge(onDark: true),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_rounded,
                      size: 12, color: Colors.white70),
                  const SizedBox(width: 3),
                  Text(
                    location,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: AppTheme.surfaceVariant,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.border,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_outline_rounded,
                size: 34, color: AppTheme.textTertiary),
          ),
          const SizedBox(height: 10),
          const Text(
            'No Photo',
            style: TextStyle(fontSize: 12, color: AppTheme.textTertiary),
          ),
        ],
      ),
    );
  }

  Widget _buildCompatibility(int score) {
    final color = score >= 80
        ? AppTheme.success
        : score >= 60
            ? AppTheme.warning
            : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            '$score% Compatible',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: AppTheme.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _PrimaryActionButton(
      {required this.label, required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppRadius.md),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 15, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortlistButton extends StatelessWidget {
  final bool isShortlisted;
  final VoidCallback? onTap;

  const _ShortlistButton({required this.isShortlisted, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 46,
        height: 42,
        decoration: BoxDecoration(
          color: isShortlisted
              ? AppTheme.secondary.withOpacity(0.12)
              : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(
            color: isShortlisted
                ? AppTheme.secondary.withOpacity(0.4)
                : AppTheme.border,
            width: 1,
          ),
        ),
        child: Icon(
          isShortlisted ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
          size: 20,
          color: isShortlisted ? AppTheme.secondary : AppTheme.textSecondary,
        ),
      ),
    );
  }
}
