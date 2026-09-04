import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingFamilyScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  const OnboardingFamilyScreen({super.key, this.isEditing = false});
  @override
  ConsumerState<OnboardingFamilyScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingFamilyScreen> {
  final _fatherNameCtrl = TextEditingController();
  final _fatherOccCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _motherOccCtrl = TextEditingController();
  int _brothers = 0, _brothersMarried = 0;
  int _sisters = 0, _sistersMarried = 0;
  String? _familyType;
  String? _familyValues;
  final _familyLocCtrl = TextEditingController();

  @override
  void dispose() {
    _fatherNameCtrl.dispose(); _fatherOccCtrl.dispose();
    _motherNameCtrl.dispose(); _motherOccCtrl.dispose();
    _familyLocCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final ok = await ref.read(onboardingProvider.notifier).saveFamily({
      'father_name': _fatherNameCtrl.text.trim().isEmpty ? null : _fatherNameCtrl.text.trim(),
      'father_occupation': _fatherOccCtrl.text.trim().isEmpty ? null : _fatherOccCtrl.text.trim(),
      'mother_name': _motherNameCtrl.text.trim().isEmpty ? null : _motherNameCtrl.text.trim(),
      'mother_occupation': _motherOccCtrl.text.trim().isEmpty ? null : _motherOccCtrl.text.trim(),
      'brothers_count': _brothers,
      'brothers_married': _brothersMarried,
      'sisters_count': _sisters,
      'sisters_married': _sistersMarried,
      'family_type': _familyType,
      'family_values': _familyValues,
      'family_location': _familyLocCtrl.text.trim().isEmpty ? null : _familyLocCtrl.text.trim(),
    });
    if (ok && mounted) {
      if (widget.isEditing) {
        context.pop();
      } else {
        context.go(AppRoutes.onboardingLifestyle);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    return OnboardingScaffold(
      currentStep: 4,
      title: 'Family Details',
      subtitle: 'Your family background matters to many families. All fields are optional.',
      isLoading: state.isLoading,
      error: state.error,
      onNext: _next,
      onBack: () => context.pop(),
      child: Column(
        children: [
          VivaTextField(label: "Father's Name", controller: _fatherNameCtrl),
          const SizedBox(height: 16),
          VivaTextField(label: "Father's Occupation", controller: _fatherOccCtrl),
          const SizedBox(height: 16),
          VivaTextField(label: "Mother's Name", controller: _motherNameCtrl),
          const SizedBox(height: 16),
          VivaTextField(label: "Mother's Occupation", controller: _motherOccCtrl),
          const SizedBox(height: 16),
          // Siblings
          Row(children: [
            Expanded(child: _CounterField(label: 'Brothers', value: _brothers,
              onChanged: (v) { if (v >= 0) setState(() { _brothers = v; if (_brothersMarried > v) _brothersMarried = v; }); })),
            const SizedBox(width: 12),
            Expanded(child: _CounterField(label: 'Married', value: _brothersMarried,
              onChanged: (v) { if (v >= 0 && v <= _brothers) setState(() => _brothersMarried = v); })),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _CounterField(label: 'Sisters', value: _sisters,
              onChanged: (v) { if (v >= 0) setState(() { _sisters = v; if (_sistersMarried > v) _sistersMarried = v; }); })),
            const SizedBox(width: 12),
            Expanded(child: _CounterField(label: 'Married', value: _sistersMarried,
              onChanged: (v) { if (v >= 0 && v <= _sisters) setState(() => _sistersMarried = v); })),
          ]),
          const SizedBox(height: 16),
          VivaDropdownField<String>(
            label: 'Family Type',
            value: _familyType,
            items: const [
              DropdownMenuItem(value: 'nuclear', child: Text('Nuclear Family')),
              DropdownMenuItem(value: 'joint', child: Text('Joint Family')),
              DropdownMenuItem(value: 'extended', child: Text('Extended Family')),
            ],
            onChanged: (v) => setState(() => _familyType = v),
          ),
          const SizedBox(height: 16),
          VivaDropdownField<String>(
            label: 'Family Values',
            value: _familyValues,
            items: const [
              DropdownMenuItem(value: 'traditional', child: Text('Traditional')),
              DropdownMenuItem(value: 'moderate', child: Text('Moderate')),
              DropdownMenuItem(value: 'liberal', child: Text('Liberal')),
            ],
            onChanged: (v) => setState(() => _familyValues = v),
          ),
          const SizedBox(height: 16),
          VivaTextField(label: "Family Location", hint: "City where family resides", controller: _familyLocCtrl),
        ],
      ),
    );
  }
}

class _CounterField extends StatelessWidget {
  final String label;
  final int value;
  final void Function(int) onChanged;
  const _CounterField({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.border, width: 1.5),
            borderRadius: BorderRadius.circular(AppRadius.md),
            color: AppTheme.background,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(onPressed: () => onChanged(value - 1), icon: const Icon(Icons.remove, size: 18)),
              Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              IconButton(onPressed: () => onChanged(value + 1), icon: const Icon(Icons.add, size: 18)),
            ],
          ),
        ),
      ],
    );
  }
}
