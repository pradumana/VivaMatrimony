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
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: AppTheme.border, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Photo
            _buildPhoto(),
            // Info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$name, $age',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 17, fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (isVerified) const VerifiedBadge(),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined,
                          size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 2),
                      Text(
                        location,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12, color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (qualification != null || profession != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      [if (profession != null) profession, if (qualification != null) qualification]
                          .join(' • '),
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12, color: AppTheme.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (compatibilityScore != null) ...[
                    const SizedBox(height: 10),
                    _buildCompatibility(compatibilityScore!),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          label: 'Send Interest',
                          icon: Icons.favorite_border,
                          color: AppTheme.primary,
                          onTap: onInterest,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _ShortlistIconButton(
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

  Widget _buildPhoto() {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
      child: AspectRatio(
        aspectRatio: 4 / 5,
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
    );
  }

  Widget _photoPlaceholder() {
    return Container(
      color: AppTheme.surfaceVariant,
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_outline, size: 60, color: AppTheme.textTertiary),
          SizedBox(height: 8),
          Text(
            'No Photo',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12, color: AppTheme.textTertiary,
            ),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            '$score% Compatible',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11, fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _ActionButton({
    required this.label, required this.icon,
    required this.color, this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 12, fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortlistIconButton extends StatelessWidget {
  final bool isShortlisted;
  final VoidCallback? onTap;

  const _ShortlistIconButton({required this.isShortlisted, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isShortlisted
              ? AppTheme.secondary.withOpacity(0.1)
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
          isShortlisted ? Icons.bookmark : Icons.bookmark_border,
          size: 20,
          color: isShortlisted ? AppTheme.secondary : AppTheme.textSecondary,
        ),
      ),
    );
  }
}
