import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingPreferencesScreen extends ConsumerStatefulWidget {
  const OnboardingPreferencesScreen({super.key});
  @override
  ConsumerState<OnboardingPreferencesScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingPreferencesScreen> {
  int _minAge = 22, _maxAge = 35;
  int? _minHeightCm;
  String? _preferredState;
  String? _educationImportance = 'preferred';
  String? _incomeImportance = 'doesnt_matter';
  bool _openToRelocation = true;

  Future<void> _next() async {
    final ok = await ref.read(onboardingProvider.notifier).savePreferences({
      'min_age': _minAge,
      'max_age': _maxAge,
      'age_importance': 'preferred',
      'min_height_cm': _minHeightCm,
      'preferred_states': _preferredState != null ? [_preferredState] : null,
      'education_importance': _educationImportance,
      'income_importance': _incomeImportance,
      'open_to_relocation': _openToRelocation,
    });
    if (ok && mounted) context.push(AppRoutes.onboardingPhotos);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    return OnboardingScaffold(
      currentStep: 6,
      title: 'Partner Preferences',
      subtitle: 'Tell us what you\'re looking for. These help find better matches.',
      isLoading: state.isLoading,
      error: state.error,
      onNext: _next,
      nextLabel: 'Save & Continue',
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Age range
          const Text('Age Range', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Row(
            children: [
              _AgeField(label: 'Min Age', value: _minAge,
                  onChanged: (v) => setState(() => _minAge = v.clamp(18, _maxAge))),
              const SizedBox(width: 12),
              const Text('to', style: TextStyle(fontFamily: 'Poppins', color: AppTheme.textSecondary)),
              const SizedBox(width: 12),
              _AgeField(label: 'Max Age', value: _maxAge,
                  onChanged: (v) => setState(() => _maxAge = v.clamp(_minAge, 70))),
            ],
          ),
          const SizedBox(height: 8),
          Text('$_minAge to $_maxAge years', style: const TextStyle(
            fontFamily: 'Poppins', fontSize: 12, color: AppTheme.primary, fontWeight: FontWeight.w500,
          )),
          const SizedBox(height: 20),

          // Preferred location
          VivaDropdownField<String>(
            label: 'Preferred State (optional)',
            value: _preferredState,
            items: const [
              DropdownMenuItem(value: 'any', child: Text('Any State')),
              DropdownMenuItem(value: 'Uttar Pradesh', child: Text('Uttar Pradesh')),
              DropdownMenuItem(value: 'Maharashtra', child: Text('Maharashtra')),
              DropdownMenuItem(value: 'Delhi', child: Text('Delhi')),
              DropdownMenuItem(value: 'Gujarat', child: Text('Gujarat')),
              DropdownMenuItem(value: 'Rajasthan', child: Text('Rajasthan')),
              DropdownMenuItem(value: 'Bihar', child: Text('Bihar')),
              DropdownMenuItem(value: 'Karnataka', child: Text('Karnataka')),
              DropdownMenuItem(value: 'Tamil Nadu', child: Text('Tamil Nadu')),
            ],
            onChanged: (v) => setState(() => _preferredState = v),
          ),
          const SizedBox(height: 16),

          // Importance dropdowns
          _ImportanceRow(
            label: 'Education matters:',
            value: _educationImportance!,
            onChanged: (v) => setState(() => _educationImportance = v),
          ),
          const SizedBox(height: 12),
          _ImportanceRow(
            label: 'Income matters:',
            value: _incomeImportance!,
            onChanged: (v) => setState(() => _incomeImportance = v),
          ),
          const SizedBox(height: 16),

          // Relocation
          Row(
            children: [
              Switch(
                value: _openToRelocation,
                onChanged: (v) => setState(() => _openToRelocation = v),
                activeColor: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Open to partner\'s relocation', style: TextStyle(
                fontFamily: 'Poppins', fontSize: 13, color: AppTheme.textSecondary,
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _AgeField extends StatelessWidget {
  final String label;
  final int value;
  final void Function(int) onChanged;
  const _AgeField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border, width: 1.5),
              borderRadius: BorderRadius.circular(12),
              color: AppTheme.surfaceVariant,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(onPressed: () => onChanged(value - 1), icon: const Icon(Icons.remove, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                Text('$value', style: const TextStyle(fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w700)),
                IconButton(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add, size: 16), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ImportanceRow extends StatelessWidget {
  final String label;
  final String value;
  final void Function(String?) onChanged;
  const _ImportanceRow({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.textSecondary))),
        DropdownButton<String>(
          value: value,
          underline: const SizedBox.shrink(),
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.primary),
          items: const [
            DropdownMenuItem(value: 'must_have', child: Text('Must Have')),
            DropdownMenuItem(value: 'preferred', child: Text('Preferred')),
            DropdownMenuItem(value: 'doesnt_matter', child: Text("Doesn't Matter")),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}
