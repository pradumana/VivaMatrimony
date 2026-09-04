import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';

/// Edit profile — menu to jump to specific profile sections.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.secondaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                  color: AppTheme.secondary.withValues(alpha: 0.3)),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded,
                  size: 16, color: AppTheme.secondary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Tap any section to edit. Changes are saved immediately.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 20),

          _SectionGroup(
            label: 'Profile Info',
            children: [
              _EditTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Basic Information',
                  subtitle: 'Name, age, height, religion',
                  onTap: () => context.push(AppRoutes.onboardingBasic,
                      extra: true)),
              _EditTile(
                  icon: Icons.notes_outlined,
                  title: 'About Me',
                  subtitle: 'Your personal description',
                  onTap: () =>
                      context.push(AppRoutes.onboardingBio, extra: true)),
              _EditTile(
                  icon: Icons.photo_library_outlined,
                  title: 'Photos',
                  subtitle: 'Manage your profile photos',
                  onTap: () => context.push(AppRoutes.onboardingPhotos,
                      extra: true)),
            ],
          ),

          _SectionGroup(
            label: 'Education & Career',
            children: [
              _EditTile(
                  icon: Icons.school_outlined,
                  title: 'Education',
                  subtitle: 'Degree, college, field of study',
                  onTap: () => context.push(AppRoutes.onboardingEducation,
                      extra: true)),
              _EditTile(
                  icon: Icons.work_outline_rounded,
                  title: 'Career',
                  subtitle: 'Profession, company, income',
                  onTap: () => context.push(AppRoutes.onboardingCareer,
                      extra: true)),
            ],
          ),

          _SectionGroup(
            label: 'Background',
            children: [
              _EditTile(
                  icon: Icons.family_restroom_outlined,
                  title: 'Family Details',
                  subtitle: 'Parents, siblings, family type',
                  onTap: () => context.push(AppRoutes.onboardingFamily,
                      extra: true)),
              _EditTile(
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Lifestyle',
                  subtitle: 'Diet, hobbies, interests',
                  onTap: () => context.push(AppRoutes.onboardingLifestyle,
                      extra: true)),
              _EditTile(
                  icon: Icons.location_on_outlined,
                  title: 'Location & Native Place',
                  subtitle: 'Current city and hometown',
                  onTap: () => context.push(AppRoutes.onboardingNativePlace,
                      extra: true)),
              _EditTile(
                  icon: Icons.favorite_border_rounded,
                  title: 'Partner Preferences',
                  subtitle: 'What you\'re looking for',
                  onTap: () => context.push(AppRoutes.onboardingPreferences,
                      extra: true)),
            ],
          ),

          _SectionGroup(
            label: 'Trust & Documents',
            children: [
              _EditTile(
                  icon: Icons.verified_user_outlined,
                  title: 'Verification',
                  subtitle: 'Reference or caste certificate',
                  onTap: () =>
                      context.push(AppRoutes.verificationSelect)),
              _EditTile(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Matrimonial Biodata',
                  subtitle: 'Preview and download PDF',
                  onTap: () => context.push(AppRoutes.biodata)),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionGroup extends StatelessWidget {
  final String label;
  final List<Widget> children;
  const _SectionGroup({required this.label, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8, left: 2),
          child: Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.textTertiary,
              letterSpacing: 1.2,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            boxShadow: AppShadows.card,
          ),
          child: Column(
            children: List.generate(children.length, (i) {
              return Column(
                children: [
                  children[i],
                  if (i < children.length - 1)
                    const Divider(
                        height: 1,
                        indent: 58,
                        color: AppTheme.divider),
                ],
              );
            }),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }
}

class _EditTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EditTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.primaryContainer,
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Icon(icon, size: 20, color: AppTheme.primary),
      ),
      title: Text(title,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(subtitle,
          style: const TextStyle(
              fontSize: 12, color: AppTheme.textSecondary)),
      trailing: const Icon(Icons.chevron_right_rounded,
          color: AppTheme.textTertiary, size: 20),
      onTap: onTap,
    );
  }
}
