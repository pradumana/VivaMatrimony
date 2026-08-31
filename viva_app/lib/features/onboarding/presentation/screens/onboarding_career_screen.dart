import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingCareerScreen extends ConsumerStatefulWidget {
  const OnboardingCareerScreen({super.key});
  @override
  ConsumerState<OnboardingCareerScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingCareerScreen> {
  final _professionController = TextEditingController();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  String? _empType;
  String? _incomeRange;
  bool _showIncome = false;
  bool _showCompany = true;

  @override
  void dispose() {
    _professionController.dispose();
    _titleController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    // Parse income
    double? incomeMin, incomeMax;
    if (_incomeRange != null) {
      final parts = _incomeRange!.split('-');
      incomeMin = double.tryParse(parts[0]);
      incomeMax = parts.length > 1 ? double.tryParse(parts[1]) : incomeMin;
    }

    final ok = await ref.read(onboardingProvider.notifier).saveEmployment({
      'profession': _professionController.text.trim().isEmpty ? null : _professionController.text.trim(),
      'job_title': _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
      'company': _companyController.text.trim().isEmpty ? null : _companyController.text.trim(),
      'employment_type': _empType,
      'income_min_lpa': incomeMin,
      'income_max_lpa': incomeMax,
      'show_income': _showIncome,
      'show_company': _showCompany,
    });
    if (ok && mounted) context.go(AppRoutes.onboardingFamily);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    return OnboardingScaffold(
      currentStep: 3,
      title: 'Career',
      subtitle: 'Share your professional background. You control what\'s visible.',
      isLoading: state.isLoading,
      error: state.error,
      onNext: _next,
      onBack: () => context.pop(),
      child: Column(
        children: [
          VivaDropdownField<String>(
            label: 'Employment Type',
            value: _empType,
            items: const [
              DropdownMenuItem(value: 'salaried', child: Text('Salaried')),
              DropdownMenuItem(value: 'self_employed', child: Text('Self Employed')),
              DropdownMenuItem(value: 'business', child: Text('Business / Entrepreneur')),
              DropdownMenuItem(value: 'government', child: Text('Government / PSU')),
              DropdownMenuItem(value: 'not_working', child: Text('Not Working')),
              DropdownMenuItem(value: 'student', child: Text('Student')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _empType = v),
          ),
          const SizedBox(height: 16),
          VivaTextField(label: 'Profession', hint: 'e.g. Software Engineer, Doctor, Teacher', controller: _professionController),
          const SizedBox(height: 16),
          VivaTextField(label: 'Job Title / Designation', hint: 'e.g. Senior Manager', controller: _titleController),
          const SizedBox(height: 16),
          VivaTextField(
            label: 'Company / Organisation',
            hint: 'e.g. TCS, HDFC Bank',
            controller: _companyController,
            suffixIcon: IconButton(
              icon: Icon(_showCompany ? Icons.visibility : Icons.visibility_off,
                  size: 18, color: AppTheme.textSecondary),
              onPressed: () => setState(() => _showCompany = !_showCompany),
              tooltip: _showCompany ? 'Visible to others' : 'Hidden from others',
            ),
          ),
          const SizedBox(height: 16),
          VivaDropdownField<String>(
            label: 'Annual Income (optional)',
            value: _incomeRange,
            items: const [
              DropdownMenuItem(value: '0-3', child: Text('Up to ₹3 LPA')),
              DropdownMenuItem(value: '3-6', child: Text('₹3–6 LPA')),
              DropdownMenuItem(value: '6-10', child: Text('₹6–10 LPA')),
              DropdownMenuItem(value: '10-15', child: Text('₹10–15 LPA')),
              DropdownMenuItem(value: '15-25', child: Text('₹15–25 LPA')),
              DropdownMenuItem(value: '25-50', child: Text('₹25–50 LPA')),
              DropdownMenuItem(value: '50-100', child: Text('₹50 LPA+')),
            ],
            onChanged: (v) => setState(() => _incomeRange = v),
          ),
          const SizedBox(height: 12),
          // Income visibility toggle
          Row(
            children: [
              Switch(
                value: _showIncome,
                onChanged: (v) => setState(() => _showIncome = v),
                activeColor: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Show income on profile', style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary,
              )),
            ],
          ),
        ],
      ),
    );
  }
}
