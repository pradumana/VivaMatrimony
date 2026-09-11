import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingPreferencesScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  const OnboardingPreferencesScreen({super.key, this.isEditing = false});
  @override
  ConsumerState<OnboardingPreferencesScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingPreferencesScreen> {
  // ── Basic ────────────────────────────────────────────────────
  int _minAge = 22, _maxAge = 35;
  int? _minHeightCm;
  String? _maritalStatus; // null = no preference

  // ── Location ─────────────────────────────────────────────────
  String? _preferredState;
  bool? _openToRelocation;           // null = no preference

  // ── Education ────────────────────────────────────────────────
  String? _minEducation;
  String? _educationImportance = 'preferred';

  // ── Career ───────────────────────────────────────────────────
  String? _incomeImportance = 'doesnt_matter';
  String? _careerPreference;         // may_work | should_work | no_preference

  // ── Family ───────────────────────────────────────────────────
  String? _preferredFamilyType;      // null = no preference

  // ── Lifestyle ────────────────────────────────────────────────
  String? _preferredDiet;
  String? _smokingPreference;
  String? _drinkingPreference;

  // ── Community ────────────────────────────────────────────────
  final _casteCtrl   = TextEditingController();
  final _subcasteCtrl = TextEditingController();
  final _gotraCtrl   = TextEditingController();

  // ── Children ─────────────────────────────────────────────────
  bool? _wantChildren;               // null = no preference
  String? _childrenTimeline;

  @override
  void dispose() {
    _casteCtrl.dispose();
    _subcasteCtrl.dispose();
    _gotraCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    // Build preference map — only send non-null, non-empty values
    final data = <String, dynamic>{
      'min_age': _minAge,
      'max_age': _maxAge,
      'age_importance': 'preferred',
      if (_minHeightCm != null) 'min_height_cm': _minHeightCm,
      if (_maritalStatus != null)
        'preferred_marital_status': [_maritalStatus],
      if (_preferredState != null) 'preferred_states': [_preferredState],
      if (_openToRelocation != null) 'open_to_relocation': _openToRelocation,
      if (_minEducation != null) 'min_education': _minEducation,
      if (_educationImportance != null)
        'education_importance': _educationImportance,
      if (_incomeImportance != null) 'income_importance': _incomeImportance,
      if (_careerPreference != null) 'career_preference': _careerPreference,
      if (_preferredFamilyType != null)
        'preferred_family_types': [_preferredFamilyType],
      if (_preferredDiet != null) 'preferred_diet': [_preferredDiet],
      if (_smokingPreference != null) 'smoking_preference': _smokingPreference,
      if (_drinkingPreference != null)
        'drinking_preference': _drinkingPreference,
      // Community — only send non-blank entries
      if (_casteCtrl.text.trim().isNotEmpty)
        'preferred_castes': [_casteCtrl.text.trim()],
      if (_subcasteCtrl.text.trim().isNotEmpty)
        'preferred_subcastes': [_subcasteCtrl.text.trim()],
      if (_gotraCtrl.text.trim().isNotEmpty)
        'preferred_gotras': [_gotraCtrl.text.trim()],
      if (_wantChildren != null) 'want_children': _wantChildren,
      if (_childrenTimeline != null)
        'want_children_timeline': _childrenTimeline,
    };

    final ok = await ref.read(onboardingProvider.notifier).savePreferences(data);
    if (ok && mounted) {
      if (widget.isEditing) {
        context.pop();
      } else {
        context.push(AppRoutes.onboardingPhotos);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    return OnboardingScaffold(
      currentStep: 7,
      title: 'Partner Preferences',
      subtitle: 'Tell us what you\'re looking for. All fields are optional — '
          'skip anything you have no preference about.',
      isLoading: state.isLoading,
      error: state.error,
      onNext: _next,
      nextLabel: 'Save & Continue',
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── BASIC ──────────────────────────────────────────────────
          const _SectionHeader(
              icon: Icons.person_outline_rounded, title: 'Basic'),
          _AgeRow(
            minAge: _minAge,
            maxAge: _maxAge,
            onMinChanged: (v) => setState(() => _minAge = v.clamp(18, _maxAge)),
            onMaxChanged: (v) => setState(() => _maxAge = v.clamp(_minAge, 70)),
          ),
          const SizedBox(height: 14),
          VivaDropdownField<String>(
            label: 'Marital Status',
            value: _maritalStatus,
            hint: 'No preference',
            items: const [
              DropdownMenuItem(value: null, child: Text('No preference')),
              DropdownMenuItem(
                  value: 'never_married', child: Text('Never married')),
              DropdownMenuItem(
                  value: 'divorced', child: Text('Divorced')),
              DropdownMenuItem(
                  value: 'widowed', child: Text('Widowed')),
            ],
            onChanged: (v) => setState(() => _maritalStatus = v),
          ),
          const SizedBox(height: 14),
          _HeightRow(
            value: _minHeightCm,
            onChanged: (v) => setState(() => _minHeightCm = v),
          ),

          // ── LOCATION ───────────────────────────────────────────────
          const SizedBox(height: 20),
          const _SectionHeader(
              icon: Icons.location_on_outlined, title: 'Location'),
          VivaDropdownField<String>(
            label: 'Preferred State',
            value: _preferredState,
            hint: 'Any State',
            items: const [
              DropdownMenuItem(value: null, child: Text('Any State')),
              DropdownMenuItem(
                  value: 'Uttar Pradesh', child: Text('Uttar Pradesh')),
              DropdownMenuItem(
                  value: 'Maharashtra', child: Text('Maharashtra')),
              DropdownMenuItem(value: 'Delhi', child: Text('Delhi')),
              DropdownMenuItem(value: 'Gujarat', child: Text('Gujarat')),
              DropdownMenuItem(value: 'Rajasthan', child: Text('Rajasthan')),
              DropdownMenuItem(value: 'Bihar', child: Text('Bihar')),
              DropdownMenuItem(
                  value: 'Karnataka', child: Text('Karnataka')),
              DropdownMenuItem(
                  value: 'Tamil Nadu', child: Text('Tamil Nadu')),
              DropdownMenuItem(
                  value: 'West Bengal', child: Text('West Bengal')),
              DropdownMenuItem(
                  value: 'Madhya Pradesh', child: Text('Madhya Pradesh')),
              DropdownMenuItem(
                  value: 'Telangana', child: Text('Telangana')),
              DropdownMenuItem(
                  value: 'Andhra Pradesh', child: Text('Andhra Pradesh')),
              DropdownMenuItem(
                  value: 'Haryana', child: Text('Haryana')),
              DropdownMenuItem(value: 'Punjab', child: Text('Punjab')),
            ],
            onChanged: (v) => setState(() => _preferredState = v),
          ),
          const SizedBox(height: 12),
          _TriStateRow(
            label: 'Partner can relocate',
            value: _openToRelocation,
            onChanged: (v) => setState(() => _openToRelocation = v),
          ),

          // ── EDUCATION ──────────────────────────────────────────────
          const SizedBox(height: 20),
          const _SectionHeader(
              icon: Icons.school_outlined, title: 'Education'),
          VivaDropdownField<String>(
            label: 'Minimum Qualification',
            value: _minEducation,
            hint: 'No preference',
            items: const [
              DropdownMenuItem(value: null, child: Text('No preference')),
              DropdownMenuItem(
                  value: 'high_school', child: Text('High School')),
              DropdownMenuItem(value: 'diploma', child: Text('Diploma')),
              DropdownMenuItem(
                  value: 'bachelor', child: Text('Bachelor\'s degree')),
              DropdownMenuItem(
                  value: 'master', child: Text('Master\'s degree')),
              DropdownMenuItem(value: 'phd', child: Text('PhD / Doctorate')),
              DropdownMenuItem(
                  value: 'professional',
                  child: Text('Professional (CA/CS/MBBS/etc.)')),
            ],
            onChanged: (v) => setState(() => _minEducation = v),
          ),
          const SizedBox(height: 8),
          _ImportanceRow(
            label: 'Education matters:',
            value: _educationImportance ?? 'preferred',
            onChanged: (v) => setState(() => _educationImportance = v),
          ),

          // ── CAREER ─────────────────────────────────────────────────
          const SizedBox(height: 20),
          const _SectionHeader(icon: Icons.work_outline_rounded, title: 'Career'),
          VivaDropdownField<String>(
            label: 'Career Preference',
            value: _careerPreference,
            hint: 'No preference',
            items: const [
              DropdownMenuItem(value: null, child: Text('No preference')),
              DropdownMenuItem(
                  value: 'may_work', child: Text('Partner may work')),
              DropdownMenuItem(
                  value: 'should_work', child: Text('Partner should work')),
              DropdownMenuItem(
                  value: 'no_preference',
                  child: Text('No preference')),
            ],
            onChanged: (v) => setState(() => _careerPreference = v),
          ),
          const SizedBox(height: 8),
          _ImportanceRow(
            label: 'Income matters:',
            value: _incomeImportance ?? 'doesnt_matter',
            onChanged: (v) => setState(() => _incomeImportance = v),
          ),

          // ── FAMILY ─────────────────────────────────────────────────
          const SizedBox(height: 20),
          const _SectionHeader(
              icon: Icons.family_restroom_outlined, title: 'Family'),
          VivaDropdownField<String>(
            label: 'Preferred Family Type',
            value: _preferredFamilyType,
            hint: 'No preference',
            items: const [
              DropdownMenuItem(value: null, child: Text('No preference')),
              DropdownMenuItem(
                  value: 'nuclear', child: Text('Nuclear family')),
              DropdownMenuItem(
                  value: 'joint', child: Text('Joint family')),
              DropdownMenuItem(
                  value: 'extended', child: Text('Extended family')),
            ],
            onChanged: (v) =>
                setState(() => _preferredFamilyType = v),
          ),

          // ── LIFESTYLE ──────────────────────────────────────────────
          const SizedBox(height: 20),
          const _SectionHeader(
              icon: Icons.restaurant_menu_outlined, title: 'Lifestyle'),
          VivaDropdownField<String>(
            label: 'Diet',
            value: _preferredDiet,
            hint: 'No preference',
            items: const [
              DropdownMenuItem(value: null, child: Text('No preference')),
              DropdownMenuItem(
                  value: 'vegetarian', child: Text('Vegetarian')),
              DropdownMenuItem(
                  value: 'non_vegetarian', child: Text('Non-Vegetarian')),
              DropdownMenuItem(
                  value: 'eggetarian', child: Text('Eggetarian')),
              DropdownMenuItem(value: 'vegan', child: Text('Vegan')),
              DropdownMenuItem(value: 'jain', child: Text('Jain')),
            ],
            onChanged: (v) => setState(() => _preferredDiet = v),
          ),
          const SizedBox(height: 12),
          VivaDropdownField<String>(
            label: 'Smoking',
            value: _smokingPreference,
            hint: 'No preference',
            items: const [
              DropdownMenuItem(value: null, child: Text('No preference')),
              DropdownMenuItem(
                  value: 'never', child: Text('Non-smoker preferred')),
              DropdownMenuItem(
                  value: 'occasionally',
                  child: Text('Occasional OK')),
            ],
            onChanged: (v) => setState(() => _smokingPreference = v),
          ),
          const SizedBox(height: 12),
          VivaDropdownField<String>(
            label: 'Alcohol',
            value: _drinkingPreference,
            hint: 'No preference',
            items: const [
              DropdownMenuItem(value: null, child: Text('No preference')),
              DropdownMenuItem(
                  value: 'never', child: Text('Non-drinker preferred')),
              DropdownMenuItem(
                  value: 'socially', child: Text('Socially OK')),
            ],
            onChanged: (v) => setState(() => _drinkingPreference = v),
          ),

          // ── COMMUNITY ──────────────────────────────────────────────
          const SizedBox(height: 20),
          const _SectionHeader(
              icon: Icons.diversity_3_outlined, title: 'Community'),
          const _InfoNote(
              'Leave blank for "any". These are soft preferences, '
              'not hard filters.'),
          const SizedBox(height: 10),
          VivaTextField(
            controller: _casteCtrl,
            label: 'Preferred Caste (optional)',
            hint: 'e.g. Brahmin, Rajput, Jat, Patel…',
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 12),
          VivaTextField(
            controller: _subcasteCtrl,
            label: 'Preferred Sub-caste (optional)',
            hint: 'e.g. Kanyakubj, Anavil…',
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: 12),
          VivaTextField(
            controller: _gotraCtrl,
            label: 'Preferred Gotra (optional)',
            hint: 'Leave blank for no preference',
            keyboardType: TextInputType.text,
          ),

          // ── CHILDREN ───────────────────────────────────────────────
          const SizedBox(height: 20),
          const _SectionHeader(
              icon: Icons.child_care_outlined,
              title: 'Children & Future'),
          VivaDropdownField<bool?>(
            label: 'Want children',
            value: _wantChildren,
            hint: 'No preference',
            items: const [
              DropdownMenuItem<bool?>(
                  value: null, child: Text('No preference')),
              DropdownMenuItem<bool?>(value: true, child: Text('Yes')),
              DropdownMenuItem<bool?>(
                  value: false, child: Text('No / Already have')),
            ],
            onChanged: (v) => setState(() {
              _wantChildren = v;
              if (v != true) _childrenTimeline = null;
            }),
          ),
          if (_wantChildren == true) ...[
            const SizedBox(height: 12),
            VivaDropdownField<String>(
              label: 'Timeline',
              value: _childrenTimeline,
              hint: 'Not decided',
              items: const [
                DropdownMenuItem(
                    value: null, child: Text('Not decided')),
                DropdownMenuItem(
                    value: 'soon', child: Text('Soon (within 1 year)')),
                DropdownMenuItem(
                    value: '1_3_years', child: Text('1–3 years')),
                DropdownMenuItem(value: 'later', child: Text('Later')),
              ],
              onChanged: (v) => setState(() => _childrenTimeline = v),
            ),
          ],

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Supporting widgets ────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppTheme.primaryContainer,
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          child: Icon(icon, size: 14, color: AppTheme.primary),
        ),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppTheme.primary,
            letterSpacing: 1.2,
          ),
        ),
      ]),
    );
  }
}

class _InfoNote extends StatelessWidget {
  final String text;
  const _InfoNote(this.text);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.secondaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded,
            size: 13, color: AppTheme.secondary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(text,
              style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.textSecondary,
                  height: 1.4)),
        ),
      ]),
    );
  }
}

class _TriStateRow extends StatelessWidget {
  final String label;
  final bool? value;
  final void Function(bool?) onChanged;
  const _TriStateRow(
      {required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary))),
      DropdownButton<bool?>(
        value: value,
        underline: const SizedBox.shrink(),
        style: const TextStyle(fontSize: 12, color: AppTheme.primary),
        items: const [
          DropdownMenuItem<bool?>(
              value: null, child: Text('No preference')),
          DropdownMenuItem<bool?>(value: true, child: Text('Yes')),
          DropdownMenuItem<bool?>(value: false, child: Text('No')),
        ],
        onChanged: onChanged,
      ),
    ]);
  }
}

class _HeightRow extends StatelessWidget {
  final int? value;
  final void Function(int?) onChanged;
  const _HeightRow({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // Display as feet/inches
    String display(int cm) {
      final ft = cm ~/ 30.48;
      final inch = ((cm % 30.48) / 2.54).round();
      return '$ft\'$inch"  ($cm cm)';
    }

    return Row(children: [
      const Expanded(
          child: Text('Min Height',
              style: TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary))),
      DropdownButton<int?>(
        value: value,
        underline: const SizedBox.shrink(),
        hint: const Text('No preference',
            style: TextStyle(fontSize: 12, color: AppTheme.primary)),
        style: const TextStyle(fontSize: 12, color: AppTheme.primary),
        items: [
          const DropdownMenuItem<int?>(
              value: null, child: Text('No preference')),
          ...List.generate(
            (AppConstants.maxHeightCm - AppConstants.minHeightCm) ~/ 2 + 1,
            (i) {
              final cm = AppConstants.minHeightCm + i * 2;
              return DropdownMenuItem<int?>(
                  value: cm, child: Text(display(cm)));
            },
          ),
        ],
        onChanged: onChanged,
      ),
    ]);
  }
}

class _AgeRow extends StatelessWidget {
  final int minAge, maxAge;
  final void Function(int) onMinChanged;
  final void Function(int) onMaxChanged;
  const _AgeRow({
    required this.minAge,
    required this.maxAge,
    required this.onMinChanged,
    required this.onMaxChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Age Range',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              child: Text('$minAge – $maxAge yrs',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primary,
                  )),
            ),
          ],
        ),
        RangeSlider(
          values: RangeValues(minAge.toDouble(), maxAge.toDouble()),
          min: 18,
          max: 70,
          divisions: 52,
          activeColor: AppTheme.primary,
          inactiveColor: AppTheme.border,
          onChanged: (v) {
            onMinChanged(v.start.round());
            onMaxChanged(v.end.round());
          },
        ),
      ],
    );
  }
}

class _ImportanceRow extends StatelessWidget {
  final String label;
  final String value;
  final void Function(String?) onChanged;
  const _ImportanceRow(
      {required this.label,
      required this.value,
      required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppTheme.textSecondary))),
      DropdownButton<String>(
        value: value,
        underline: const SizedBox.shrink(),
        style: const TextStyle(fontSize: 12, color: AppTheme.primary),
        items: const [
          DropdownMenuItem(
              value: 'must_have', child: Text('Must Have')),
          DropdownMenuItem(
              value: 'preferred', child: Text('Preferred')),
          DropdownMenuItem(
              value: 'doesnt_matter',
              child: Text("Doesn't Matter")),
        ],
        onChanged: onChanged,
      ),
    ]);
  }
}
