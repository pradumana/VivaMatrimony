import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingCommunityScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  const OnboardingCommunityScreen({super.key, this.isEditing = false});
  @override
  ConsumerState<OnboardingCommunityScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingCommunityScreen> {
  final _religionCtrl  = TextEditingController();
  final _casteCtrl     = TextEditingController();
  final _subcasteCtrl  = TextEditingController();
  final _gotraCtrl     = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _load();
  }

  Future<void> _load() async {
    try {
      final r = await ref.read(apiClientProvider).get('/profile');
      final p = (r.data as Map<String, dynamic>)['profile'] as Map<String, dynamic>? ?? {};
      if (!mounted) return;
      setState(() {
        _religionCtrl.text  = p['religion']  as String? ?? '';
        _casteCtrl.text     = p['caste']     as String? ?? '';
        _subcasteCtrl.text  = p['sub_caste'] as String? ?? '';
        _gotraCtrl.text     = p['gotra']     as String? ?? '';
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _religionCtrl.dispose(); _casteCtrl.dispose();
    _subcasteCtrl.dispose(); _gotraCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final ok = await ref.read(onboardingProvider.notifier).saveBasicInfo({
      'religion':  _religionCtrl.text.trim().isEmpty  ? null : _religionCtrl.text.trim(),
      'caste':     _casteCtrl.text.trim().isEmpty     ? null : _casteCtrl.text.trim(),
      'sub_caste': _subcasteCtrl.text.trim().isEmpty  ? null : _subcasteCtrl.text.trim(),
      'gotra':     _gotraCtrl.text.trim().isEmpty     ? null : _gotraCtrl.text.trim(),
    });
    if (ok && mounted) {
      if (widget.isEditing) {
        context.pop();
      } else {
        context.push(AppRoutes.onboardingPreferences);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final state = ref.watch(onboardingProvider);
    return OnboardingScaffold(
      currentStep: 7,
      title: 'Community & Traditions',
      subtitle:
          'These appear publicly on your profile and biodata. All fields are optional — skip anything you\'d prefer not to share.',
      isLoading: state.isLoading,
      error: state.error,
      onNext: _next,
      nextLabel: widget.isEditing ? 'Save' : 'Continue',
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Row(children: [
              Icon(Icons.info_outline_rounded, size: 14, color: AppTheme.primary),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Caste, sub-caste and gotra are public matrimonial details. '
                'They will appear on your profile and biodata PDF.',
                style: TextStyle(fontSize: 11, color: AppTheme.primary, height: 1.4),
              )),
            ]),
          ),
          const SizedBox(height: 20),
          VivaTextField(
            label: 'Religion (optional)',
            hint: 'e.g. Hindu, Muslim, Sikh, Christian…',
            controller: _religionCtrl,
          ),
          const SizedBox(height: 14),
          VivaTextField(
            label: '${l.caste} (optional)',
            hint: 'e.g. Brahmin, Rajput, Jat, Patel, Kayastha…',
            controller: _casteCtrl,
          ),
          const SizedBox(height: 14),
          VivaTextField(
            label: '${l.subCaste} (optional)',
            hint: 'e.g. Kanyakubj, Anavil, Iyengar…',
            controller: _subcasteCtrl,
          ),
          const SizedBox(height: 14),
          VivaTextField(
            label: '${l.gotra} (optional)',
            hint: 'Leave blank if not known or not applicable',
            controller: _gotraCtrl,
          ),
          const SizedBox(height: 8),
          const Text(
            'Not sure about your gotra? You can leave it blank and update later from your profile.',
            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary, height: 1.4),
          ),
        ],
      ),
    );
  }
}
