import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class VerifiedBadge extends StatelessWidget {
  final bool small;
  const VerifiedBadge({super.key, this.small = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 6 : 8,
        vertical: small ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: AppTheme.verifiedBadge.withOpacity(0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(
          color: AppTheme.verifiedBadge.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.verified,
            size: small ? 11 : 13,
            color: AppTheme.verifiedBadge,
          ),
          SizedBox(width: small ? 2 : 3),
          Text(
            'Verified',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: small ? 9 : 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.verifiedBadge,
            ),
          ),
        ],
      ),
    );
  }
}
