import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  static const _faqs = [
    _Faq('How do I get verified?', 'You can verify by providing a reference from an existing Viva member, or by uploading your caste certificate. Verification typically takes ${AppConstants.verificationSlaDays} for certificate review.'),
    _Faq('Who can see my profile?', 'By default, your profile is visible to registered members only. You can change this in Settings → Privacy Settings.'),
    _Faq('Is my caste certificate safe?', 'Yes. Your certificate is stored in a private, encrypted vault and can only be viewed by authorised admin staff for verification purposes. It is never shared publicly.'),
    _Faq('How are matches calculated?', 'We use a rule-based compatibility score across 7 factors: age, location, education, profession, lifestyle, preferences, and family. It is a guide, not a guarantee.'),
    _Faq('Can I delete my account?', 'Yes. Go to Settings → Delete Account. This permanently removes your profile and data.'),
    _Faq('What happens when I block someone?', 'They will no longer appear in your search or recommendations, and you will not receive messages or interests from them.'),
    _Faq('How do I report a fake profile?', 'On any profile, tap the ⋮ menu → Report. Our team reviews all reports within ${AppConstants.reportReviewHours}.'),
    _Faq('Can I use Viva without a WhatsApp number?', 'No. WhatsApp is our primary verification method to ensure real people join the platform.'),
    _Faq('Why didn\'t I receive my OTP?', 'Make sure your WhatsApp is active on the number entered. If not received in 60 seconds, tap Resend OTP. Check that your number includes the country code (+91 for India).'),
    _Faq('How do I generate my matrimonial biodata?', 'Go to Profile → My Biodata. Tap Generate Biodata to create a PDF. Download and share it with families directly.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help & Support')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Contact card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Row(children: [
              const Icon(Icons.support_agent, size: 36, color: Colors.white),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Contact Support', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                  Text(AppConstants.supportEmail, style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9))),
                  const Text('Response within 24 hours', style: TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              )),
              IconButton(
                icon: const Icon(Icons.email_outlined, color: Colors.white),
                onPressed: () async {
                  final uri = Uri.parse('mailto:${AppConstants.supportEmail}');
                  if (!await canLaunchUrl(uri)) return;
                  launchUrl(uri);
                },
              ),
            ]),
          ),
          const SizedBox(height: 24),

          const Text('Frequently Asked Questions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),

          ..._faqs.map((f) => _FaqTile(faq: f)),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final _Faq faq;
  const _FaqTile({required this.faq});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: _expanded ? AppTheme.primary.withValues(alpha: 0.3) : AppTheme.border),
      ),
      child: Column(children: [
        ListTile(
          title: Text(widget.faq.question, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          trailing: Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, size: 20, color: AppTheme.primary),
          onTap: () => setState(() => _expanded = !_expanded),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
        ),
        if (_expanded)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: Text(widget.faq.answer, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.6)),
          ),
      ]),
    );
  }
}

class _Faq {
  final String question;
  final String answer;
  const _Faq(this.question, this.answer);
}
