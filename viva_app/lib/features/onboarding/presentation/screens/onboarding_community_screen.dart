import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/constants/community_constants.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingCommunityScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  const OnboardingCommunityScreen({super.key, this.isEditing = false});
  @override
  ConsumerState<OnboardingCommunityScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingCommunityScreen> {
  final _religionCtrl = TextEditingController(text: 'Hindu');
  String? _caste     = CommunityConstants.defaultCaste;
  String? _subCaste  = CommunityConstants.defaultSubCaste;
  String? _gotra;

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
        _religionCtrl.text = p['religion'] as String? ?? 'Hindu';
        _caste    = p['caste']     as String? ?? CommunityConstants.defaultCaste;
        _subCaste = p['sub_caste'] as String? ?? CommunityConstants.defaultSubCaste;
        _gotra    = p['gotra']     as String?;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _religionCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final ok = await ref.read(onboardingProvider.notifier).saveBasicInfo({
      'religion':  _religionCtrl.text.trim().isEmpty ? null : _religionCtrl.text.trim(),
      'caste':     _caste,
      'sub_caste': _subCaste,
      'gotra':     _gotra,
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

          // Religion — free text (still needed for non-Vishwakarma paths)
          _buildLabel('Religion (optional)'),
          const SizedBox(height: 6),
          TextField(
            controller: _religionCtrl,
            decoration: _inputDeco('e.g. Hindu, Muslim, Sikh, Christian…'),
          ),
          const SizedBox(height: 16),

          // Caste — dropdown, default Vishwakarma
          _buildLabel('${l.caste} (optional)'),
          const SizedBox(height: 6),
          _CommunityDropdown<String>(
            value: _caste,
            hint: 'Select caste',
            items: CommunityConstants.castes,
            onChanged: (v) => setState(() => _caste = v),
          ),
          const SizedBox(height: 16),

          // Sub-caste — dropdown, default Panchal
          _buildLabel('${l.subCaste} (optional)'),
          const SizedBox(height: 6),
          _CommunityDropdown<String>(
            value: _subCaste,
            hint: 'Select sub-caste',
            items: CommunityConstants.vishwakarmaSubCastes,
            onChanged: (v) => setState(() => _subCaste = v),
          ),
          const SizedBox(height: 16),

          // Gotra — dropdown
          _buildLabel('${l.gotra} (optional)'),
          const SizedBox(height: 6),
          _CommunityDropdown<String>(
            value: _gotra,
            hint: 'Select gotra (optional)',
            items: CommunityConstants.vishwakarmaGotras,
            allowNull: true,
            onChanged: (v) => setState(() => _gotra = v),
          ),
          const SizedBox(height: 8),
          const Text(
            'Not sure about your gotra? Leave it blank and update later from your profile.',
            style: TextStyle(fontSize: 11, color: AppTheme.textTertiary, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: AppTheme.textSecondary,
    ),
  );

  InputDecoration _inputDeco(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: AppTheme.surfaceVariant,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppTheme.border, width: 1.5),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.md),
      borderSide: const BorderSide(color: AppTheme.border, width: 1.5),
    ),
  );
}

// ---------------------------------------------------------------------------
// Reusable community dropdown
// ---------------------------------------------------------------------------
class _CommunityDropdown<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final List<String> items;
  final bool allowNull;
  final void Function(String?) onChanged;

  const _CommunityDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
    this.allowNull = false,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: value as String?,
      isExpanded: true,
      decoration: InputDecoration(
        filled: true,
        fillColor: AppTheme.surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppTheme.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppTheme.border, width: 1.5),
        ),
      ),
      hint: Text(hint, style: const TextStyle(color: AppTheme.textTertiary)),
      items: [
        if (allowNull)
          const DropdownMenuItem<String>(value: null, child: Text('Not specified')),
        ...items.map((s) => DropdownMenuItem(value: s, child: Text(s))),
      ],
      onChanged: onChanged,
    );
  }
}
