import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_button.dart';

/// Edit profile routes into individual onboarding screens for each section.
/// This acts as a menu to jump to specific sections.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Tap any section to edit. Changes are saved immediately.',
              style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.textSecondary),
            ),
          ),
          _EditSection(icon: Icons.person_outline, title: 'Basic Information', subtitle: 'Name, age, height, religion', onTap: () => context.push(AppRoutes.onboardingBasic)),
          _EditSection(icon: Icons.notes_outlined, title: 'About Me', subtitle: 'Your personal description', onTap: () => context.push(AppRoutes.onboardingBio)),
          _EditSection(icon: Icons.photo_library_outlined, title: 'Photos', subtitle: 'Manage your profile photos', onTap: () => context.push(AppRoutes.onboardingPhotos)),
          _EditSection(icon: Icons.school_outlined, title: 'Education', subtitle: 'Degree, college, field of study', onTap: () => context.push(AppRoutes.onboardingEducation)),
          _EditSection(icon: Icons.work_outline, title: 'Career', subtitle: 'Profession, company, income', onTap: () => context.push(AppRoutes.onboardingCareer)),
          _EditSection(icon: Icons.family_restroom_outlined, title: 'Family Details', subtitle: 'Parents, siblings, family type', onTap: () => context.push(AppRoutes.onboardingFamily)),
          _EditSection(icon: Icons.restaurant_menu_outlined, title: 'Lifestyle', subtitle: 'Diet, hobbies, interests', onTap: () => context.push(AppRoutes.onboardingLifestyle)),
          _EditSection(icon: Icons.location_on_outlined, title: 'Location & Native Place', subtitle: 'Current city and hometown', onTap: () => context.push(AppRoutes.onboardingNativePlace)),
          _EditSection(icon: Icons.favorite_outline, title: 'Partner Preferences', subtitle: 'What you\'re looking for', onTap: () => context.push(AppRoutes.onboardingPreferences)),
          const Divider(height: 32),
          _EditSection(icon: Icons.verified_user_outlined, title: 'Verification', subtitle: 'Reference or caste certificate', onTap: () => context.push(AppRoutes.verificationSelect)),
          _EditSection(icon: Icons.picture_as_pdf_outlined, title: 'Matrimonial Biodata', subtitle: 'Preview and download PDF', onTap: () => context.push(AppRoutes.biodata)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _EditSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _EditSection({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppTheme.border),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: AppTheme.primaryContainer, borderRadius: BorderRadius.circular(AppRadius.md)),
          child: Icon(icon, size: 22, color: AppTheme.primary),
        ),
        title: Text(title, style: const TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.textSecondary)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
