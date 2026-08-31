import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingBasicScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  const OnboardingBasicScreen({super.key, this.isEditing = false});

  @override
  ConsumerState<OnboardingBasicScreen> createState() =>
      _OnboardingBasicScreenState();
}

class _OnboardingBasicScreenState
    extends ConsumerState<OnboardingBasicScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  String? _gender;
  DateTime? _dob;
  int? _heightCm;
  String? _maritalStatus;
  String? _motherTongue;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  String get _dobDisplay =>
      _dob != null ? DateFormat('dd MMM yyyy').format(_dob!) : 'Select Date';

  int? get _age {
    if (_dob == null) return null;
    final now = DateTime.now();
    int age = now.year - _dob!.year;
    if (now.month < _dob!.month ||
        (now.month == _dob!.month && now.day < _dob!.day)) age--;
    return age;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 25),
      firstDate: DateTime(now.year - 70),
      lastDate: DateTime(now.year - 18),
      helpText: 'Select Date of Birth',
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: AppTheme.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _next() async {
    if (!_formKey.currentState!.validate()) return;
    if (_dob == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your date of birth'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your gender'),
          backgroundColor: AppTheme.error,
        ),
      );
      return;
    }

    final ok = await ref.read(onboardingProvider.notifier).saveBasicInfo({
      'full_name': _nameController.text.trim(),
      'gender': _gender,
      'date_of_birth': DateFormat('yyyy-MM-dd').format(_dob!),
      'height_cm': _heightCm,
      'marital_status': _maritalStatus ?? 'never_married',
      'mother_tongue': _motherTongue,
    });

    if (ok && mounted) {
      if (widget.isEditing) context.pop();
      else context.go(AppRoutes.onboardingBio);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);

    return OnboardingScaffold(
      currentStep: 0,
      title: 'Basic Information',
      subtitle: 'Tell us about yourself to create your matrimonial profile.',
      isLoading: state.isLoading,
      error: state.error,
      onNext: _next,
      showBack: false,
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            VivaTextField(
              label: 'Full Name',
              hint: 'As on your documents',
              controller: _nameController,
              validator: (v) =>
                  (v == null || v.trim().length < 2) ? 'Please enter your full name' : null,
            ),
            const SizedBox(height: 16),

            // Gender
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Gender', style: TextStyle(
                fontSize: 13,
                color: AppTheme.textSecondary, fontWeight: FontWeight.w500,
              )),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final g in ['male', 'female', 'other']) ...[
                  _GenderChip(
                    label: g == 'male' ? '♂ Male' : g == 'female' ? '♀ Female' : '⊕ Other',
                    isSelected: _gender == g,
                    onTap: () => setState(() => _gender = g),
                  ),
                  if (g != 'other') const SizedBox(width: 10),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // DOB
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppTheme.border, width: 1.5),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 18, color: AppTheme.textSecondary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date of Birth', style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          )),
                          Text(
                            _dob != null
                                ? '$_dobDisplay  •  ${_age!} years'
                                : 'Tap to select',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _dob != null
                                  ? AppTheme.textPrimary
                                  : AppTheme.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: AppTheme.textSecondary),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Height
            VivaDropdownField<int>(
              label: 'Height (optional)',
              value: _heightCm,
              items: [
                for (int h = AppConstants.minHeightCm;
                    h <= AppConstants.maxHeightCm;
                    h += 1)
                  DropdownMenuItem(
                    value: h,
                    child: Text('${h}cm  (${_cmToFt(h)})'),
                  ),
              ],
              onChanged: (v) => setState(() => _heightCm = v),
            ),
            const SizedBox(height: 16),

            // Marital status
            VivaDropdownField<String>(
              label: 'Marital Status',
              value: _maritalStatus ?? 'never_married',
              items: const [
                DropdownMenuItem(value: 'never_married', child: Text('Never Married')),
                DropdownMenuItem(value: 'divorced', child: Text('Divorced')),
                DropdownMenuItem(value: 'widowed', child: Text('Widowed')),
                DropdownMenuItem(value: 'separated', child: Text('Separated')),
              ],
              onChanged: (v) => setState(() => _maritalStatus = v),
            ),
            const SizedBox(height: 16),

            // Mother tongue
            VivaDropdownField<String>(
              label: 'Mother Tongue (optional)',
              value: _motherTongue,
              items: const [
                DropdownMenuItem(value: 'Hindi', child: Text('Hindi')),
                DropdownMenuItem(value: 'Bengali', child: Text('Bengali')),
                DropdownMenuItem(value: 'Telugu', child: Text('Telugu')),
                DropdownMenuItem(value: 'Marathi', child: Text('Marathi')),
                DropdownMenuItem(value: 'Tamil', child: Text('Tamil')),
                DropdownMenuItem(value: 'Gujarati', child: Text('Gujarati')),
                DropdownMenuItem(value: 'Kannada', child: Text('Kannada')),
                DropdownMenuItem(value: 'Malayalam', child: Text('Malayalam')),
                DropdownMenuItem(value: 'Punjabi', child: Text('Punjabi')),
                DropdownMenuItem(value: 'Odia', child: Text('Odia')),
                DropdownMenuItem(value: 'Urdu', child: Text('Urdu')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _motherTongue = v),
            ),
          ],
        ),
      ),
    );
  }

  String _cmToFt(int cm) {
    final totalInches = cm / 2.54;
    final ft = totalInches ~/ 12;
    final inches = (totalInches % 12).round();
    return "$ft'$inches\"";
  }
}

class _GenderChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _GenderChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.primaryContainer : AppTheme.surfaceVariant,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: isSelected ? 2 : 1.5,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
