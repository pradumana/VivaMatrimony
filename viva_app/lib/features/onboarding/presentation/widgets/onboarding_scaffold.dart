import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_button.dart';

/// Shared scaffold for all onboarding steps.
class OnboardingScaffold extends StatelessWidget {
  final int currentStep; // 0-indexed, out of 9
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onNext;
  final VoidCallback? onBack;
  final bool isLoading;
  final String nextLabel;
  final bool showBack;
  final bool showSkip;
  final String? error;

  const OnboardingScaffold({
    super.key,
    required this.currentStep,
    required this.title,
    required this.subtitle,
    required this.child,
    this.onNext,
    this.onBack,
    this.isLoading = false,
    this.nextLabel = 'Continue',
    this.showBack = true,
    this.showSkip = true,
    this.error,
  });

  int get _totalSteps => AppConstants.onboardingSteps.length;
  double get _progress => (currentStep + 1) / _totalSteps;
  String get _stepName => AppConstants.onboardingSteps[currentStep];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: showBack && onBack != null
            ? IconButton(
                icon: Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppTheme.surfaceVariant,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 14, color: AppTheme.textPrimary),
                ),
                onPressed: onBack,
              )
            : const SizedBox.shrink(),
        title: Column(
          children: [
            // Step label
            Text(
              '${currentStep + 1} of $_totalSteps  ·  $_stepName',
              style: const TextStyle(
                fontSize: 11,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 7),
            // Segmented progress bar
            SizedBox(
              width: 180,
              height: 5,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.full),
                child: LinearProgressIndicator(
                  value: _progress,
                  backgroundColor: AppTheme.border,
                  valueColor:
                      const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                ),
              ),
            ),
          ],
        ),
        actions: showSkip
            ? [
                TextButton(
                  onPressed: onNext,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  child: const Text(
                    'Skip',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Step pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'STEP ${currentStep + 1}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),

                    // Subtle divider
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.primary.withValues(alpha: 0.3),
                              AppTheme.border.withValues(alpha: 0.3),
                              Colors.transparent,
                            ],
                          ),
                        ),
                      ),
                    ),

                    child,
                  ],
                ),
              ),
            ),

            // Error banner
            if (error != null)
              Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppTheme.error.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: AppTheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.error),
                      ),
                    ),
                  ],
                ),
              ),

            // Bottom CTA
            Container(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: AppTheme.divider, width: 1),
                ),
              ),
              child: VivaButton(
                label: nextLabel,
                isLoading: isLoading,
                onPressed: onNext,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
