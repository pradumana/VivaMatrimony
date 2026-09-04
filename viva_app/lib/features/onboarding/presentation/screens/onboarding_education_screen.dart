import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingEducationScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  const OnboardingEducationScreen({super.key, this.isEditing = false});
  @override
  ConsumerState<OnboardingEducationScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingEducationScreen> {
  String? _qualification;
  final _degreeController = TextEditingController();
  final _fieldController = TextEditingController();
  final _collegeController = TextEditingController();
  int? _gradYear;

  @override
  void dispose() {
    _degreeController.dispose();
    _fieldController.dispose();
    _collegeController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final ok = await ref.read(onboardingProvider.notifier).saveEducation({
      'highest_qualification': _qualification,
      'degree': _degreeController.text.trim().isEmpty ? null : _degreeController.text.trim(),
      'field_of_study': _fieldController.text.trim().isEmpty ? null : _fieldController.text.trim(),
      'college_university': _collegeController.text.trim().isEmpty ? null : _collegeController.text.trim(),
      'graduation_year': _gradYear,
    });
    if (ok && mounted) {
      if (widget.isEditing) {
        context.pop();
      } else {
        context.go(AppRoutes.onboardingCareer);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    return OnboardingScaffold(
      currentStep: 2,
      title: 'Education',
      subtitle: 'Your educational background helps find compatible matches.',
      isLoading: state.isLoading,
      error: state.error,
      onNext: _next,
      onBack: () => context.pop(),
      child: Column(
        children: [
          VivaDropdownField<String>(
            label: 'Highest Qualification',
            value: _qualification,
            items: const [
              DropdownMenuItem(value: 'high_school', child: Text('High School / 12th')),
              DropdownMenuItem(value: 'diploma', child: Text('Diploma')),
              DropdownMenuItem(value: 'bachelor', child: Text('Bachelor\'s Degree')),
              DropdownMenuItem(value: 'master', child: Text('Master\'s Degree')),
              DropdownMenuItem(value: 'phd', child: Text('PhD / Doctorate')),
              DropdownMenuItem(value: 'professional', child: Text('Professional (CA/CS/MBBS/LLB)')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _qualification = v),
          ),
          const SizedBox(height: 16),
          VivaTextField(label: 'Degree', hint: 'e.g. B.Tech, MBA, MBBS', controller: _degreeController),
          const SizedBox(height: 16),
          VivaTextField(label: 'Field of Study', hint: 'e.g. Computer Science, Finance', controller: _fieldController),
          const SizedBox(height: 16),
          VivaTextField(label: 'College / University', hint: 'e.g. Delhi University', controller: _collegeController),
          const SizedBox(height: 16),
          VivaDropdownField<int>(
            label: 'Graduation Year (optional)',
            value: _gradYear,
            items: [
              for (int y = DateTime.now().year + 4; y >= 1970; y--)
                DropdownMenuItem(value: y, child: Text('$y')),
            ],
            onChanged: (v) => setState(() => _gradYear = v),
          ),
        ],
      ),
    );
  }
}
