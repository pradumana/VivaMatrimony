import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_button.dart';

class VerificationSelectScreen extends StatefulWidget {
  const VerificationSelectScreen({super.key});
  @override
  State<VerificationSelectScreen> createState() => _State();
}

class _State extends State<VerificationSelectScreen> {
  String? _selected; // 'reference' | 'certificate'

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Get Verified'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Hero trust banner ───────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified_user_rounded,
                          color: Colors.white, size: 30),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Verified Profile',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Build trust with potential matches',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.85),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              const Text(
                'Choose a verification method',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'You only need to complete ONE option below.',
                style: TextStyle(
                    fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 20),

              // ── Option A ──────────────────────────────────────────
              _OptionCard(
                isSelected: _selected == 'reference',
                icon: Icons.people_alt_outlined,
                label: 'Member Reference',
                description:
                    'Provide the mobile number of an existing registered Viva member who can vouch for you.',
                tag: 'Instant',
                tagColor: AppTheme.success,
                onTap: () => setState(() => _selected = 'reference'),
              ),

              const SizedBox(height: 14),

              // OR divider
              Row(children: const [
                Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    'OR',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.textTertiary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Expanded(child: Divider()),
              ]),

              const SizedBox(height: 14),

              // ── Option B ──────────────────────────────────────────
              _OptionCard(
                isSelected: _selected == 'certificate',
                icon: Icons.upload_file_outlined,
                label: 'Caste Certificate',
                description:
                    'Upload your caste/community certificate. Reviewed securely by our admin team (${AppConstants.verificationSlaDays}).',
                tag: '1-2 days',
                tagColor: AppTheme.warning,
                onTap: () => setState(() => _selected = 'certificate'),
              ),

              const SizedBox(height: 36),

              VivaButton(
                label: 'Continue',
                onPressed: _selected == null
                    ? null
                    : () => context.push(_selected == 'reference'
                        ? AppRoutes.verificationReference
                        : AppRoutes.verificationCertificate),
              ),
              const SizedBox(height: 14),
              Center(
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text(
                    'Skip for now — verify later',
                    style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final bool isSelected;
  final IconData icon;
  final String label;
  final String description;
  final String tag;
  final Color tagColor;
  final VoidCallback onTap;

  const _OptionCard({
    required this.isSelected,
    required this.icon,
    required this.label,
    required this.description,
    required this.tag,
    required this.tagColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.12),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  )
                ]
              : AppShadows.card,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon box
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary
                    : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(
                icon,
                size: 24,
                color: isSelected
                    ? Colors.white
                    : AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: isSelected
                              ? AppTheme.primary
                              : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: tagColor.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        tag,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: tagColor,
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 5),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: isSelected ? AppTheme.primary : AppTheme.border,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
