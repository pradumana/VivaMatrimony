import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class VerifiedBadge extends StatelessWidget {
  final bool small;
  /// Use [onDark] when the badge appears over a dark/photo background.
  final bool onDark;

  const VerifiedBadge({super.key, this.small = false, this.onDark = false});

  @override
  Widget build(BuildContext context) {
    final badgeColor = onDark ? Colors.white : AppTheme.verifiedBadge;
    final bgColor = onDark
        ? Colors.white.withOpacity(0.2)
        : AppTheme.verifiedBadge.withOpacity(0.12);
    final borderColor = onDark
        ? Colors.white.withOpacity(0.4)
        : AppTheme.verifiedBadge.withOpacity(0.4);
    final textColor = onDark ? Colors.white : AppTheme.verifiedBadge;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified_rounded,
            size: small ? 11 : 13,
            color: badgeColor,
          ),
          SizedBox(width: small ? 2 : 3),
          Text(
            'Verified',
            style: TextStyle(
              fontSize: small ? 9 : 10,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}
