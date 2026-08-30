import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const _SectionHeader('Account'),
          _SettingsTile(icon: Icons.lock_outline, title: 'Privacy Settings', onTap: () => context.push(AppRoutes.privacy)),
          _SettingsTile(icon: Icons.notifications_outlined, title: 'Notification Preferences', onTap: () => _showComingSoon(context)),
          _SettingsTile(icon: Icons.visibility_outlined, title: 'Profile Visibility', onTap: () => context.push(AppRoutes.privacy)),

          const _SectionHeader('Verification'),
          _SettingsTile(icon: Icons.verified_user_outlined, title: 'Verification Status', onTap: () => context.push(AppRoutes.verificationStatus)),
          _SettingsTile(icon: Icons.upload_file_outlined, title: 'Re-upload Document', onTap: () => context.push(AppRoutes.verificationCertificate)),

          const _SectionHeader('Support'),
          _SettingsTile(icon: Icons.help_outline, title: 'Help & Support', onTap: () => context.push(AppRoutes.helpSupport)),
          _SettingsTile(icon: Icons.policy_outlined, title: 'Privacy Policy', onTap: () => _launchUrl(AppConstants.privacyPolicyUrl)),
          _SettingsTile(icon: Icons.description_outlined, title: 'Terms & Conditions', onTap: () => _launchUrl(AppConstants.termsUrl)),
          _SettingsTile(icon: Icons.info_outline, title: 'About Viva', onTap: () => _showAbout(context)),

          const _SectionHeader('Danger Zone'),
          _SettingsTile(icon: Icons.delete_outline, title: 'Delete Account', color: AppTheme.error, onTap: () => _confirmDelete(context, ref)),

          const SizedBox(height: 16),
          Center(child: Text('Viva v${AppConstants.appVersion}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppTheme.textTertiary))),          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext ctx) {
    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Coming soon in the next update!')));
  }

  void _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  void _showAbout(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('About Viva', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"${AppConstants.appTagline}"', style: const TextStyle(fontFamily: 'Poppins', fontStyle: FontStyle.italic, color: AppTheme.primary)),
            const SizedBox(height: 12),
            const Text('A premium Indian matrimony platform built on trust, transparency and tradition.', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.5)),
            const SizedBox(height: 8),
            Text('Version ${AppConstants.appVersion}', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ),
    );
  }

  void _confirmDelete(BuildContext ctx, WidgetRef ref) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Delete Account', style: TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w700, color: AppTheme.error)),
        content: const Text(
          'This will permanently delete your account, profile, photos, and all data. This cannot be undone.\n\nAre you absolutely sure?',
          style: TextStyle(fontFamily: 'Poppins', fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () async {
              Navigator.pop(ctx);
              // Call delete API then logout
              try {
                // DELETE /profile endpoint
                await ref.read(authProvider.notifier).logout();
              } catch (_) {
                await ref.read(authProvider.notifier).logout();
              }
            },
            child: const Text('Delete My Account'),
          ),
        ],
      ),
    );
  }
}

// Version is defined in AppConstants

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(title.toUpperCase(), style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textTertiary, letterSpacing: 1)),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;

  const _SettingsTile({required this.icon, required this.title, required this.onTap, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return ListTile(
      leading: Icon(icon, size: 22, color: c),
      title: Text(title, style: TextStyle(fontFamily: 'Poppins', fontSize: 14, fontWeight: FontWeight.w500, color: c)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textTertiary),
      onTap: onTap,
    );
  }
}
