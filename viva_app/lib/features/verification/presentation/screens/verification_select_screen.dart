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
      appBar: AppBar(title: const Text('Get Verified'), backgroundColor: Colors.white, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_user, color: Colors.white, size: 36),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Verified Profile', style: TextStyle(fontFamily: 'Poppins', fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white)),
                          Text('Build trust with potential matches', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: Colors.white.withOpacity(0.85))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              const Text('Choose one verification method:', style: TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text('You only need to complete ONE option below.', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.textSecondary)),
              const SizedBox(height: 20),

              // Option A
              _OptionCard(
                isSelected: _selected == 'reference',
                icon: Icons.people_alt_outlined,
                label: 'Option A — Member Reference',
                description: 'Provide the mobile number of an existing registered Viva member who can vouch for you.',
                tag: 'Instant',
                tagColor: AppTheme.success,
                onTap: () => setState(() => _selected = 'reference'),
              ),
              const SizedBox(height: 14),

              // OR divider
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text('OR', style: TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.textTertiary, fontWeight: FontWeight.w500)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),

              // Option B
              _OptionCard(
                isSelected: _selected == 'certificate',
                icon: Icons.upload_file_outlined,
                label: 'Option B — Caste Certificate',
                description: 'Upload your caste/community certificate. Reviewed securely by our admin team (1-2 business days).',
                tag: '1-2 days',
                tagColor: AppTheme.warning,
                onTap: () => setState(() => _selected = 'certificate'),
              ),

              const Spacer(),
              VivaButton(
                label: 'Continue',
                onPressed: _selected == null
                    ? null
                    : () => context.push(_selected == 'reference'
                        ? AppRoutes.verificationReference
                        : AppRoutes.verificationCertificate),
              ),
              const SizedBox(height: 12),
              Center(
                child: TextButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Skip for now (verify later)', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.textSecondary)),
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

  const _OptionCard({required this.isSelected, required this.icon, required this.label, required this.description, required this.tag, required this.tagColor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryContainer : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: isSelected ? AppTheme.primary : AppTheme.border, width: isSelected ? 2 : 1),
          boxShadow: isSelected ? [BoxShadow(color: AppTheme.primary.withOpacity(0.1), blurRadius: 12, offset: const Offset(0, 4))] : [],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.surfaceVariant,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Icon(icon, size: 22, color: isSelected ? Colors.white : AppTheme.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text(label, style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600, color: isSelected ? AppTheme.primary : AppTheme.textPrimary))),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: tagColor.withOpacity(0.12), borderRadius: BorderRadius.circular(AppRadius.full)),
                        child: Text(tag, style: TextStyle(fontFamily: 'Poppins', fontSize: 10, fontWeight: FontWeight.w600, color: tagColor)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: isSelected ? AppTheme.primary : AppTheme.border, size: 22),
          ],
        ),
      ),
    );
  }
}
