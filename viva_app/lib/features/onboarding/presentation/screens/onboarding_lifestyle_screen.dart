import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingLifestyleScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  const OnboardingLifestyleScreen({super.key, this.isEditing = false});
  @override
  ConsumerState<OnboardingLifestyleScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingLifestyleScreen> {
  String? _diet;
  String? _smoking;
  String? _drinking;
  final Set<String> _hobbies = {};
  final Set<String> _interests = {};

  static const _allHobbies = ['Reading', 'Cooking', 'Travelling', 'Music', 'Sports', 'Yoga', 'Dancing', 'Painting', 'Gardening', 'Photography', 'Fitness', 'Gaming'];
  static const _allInterests = ['Family Time', 'Culture', 'Technology', 'Food', 'Movies', 'Spirituality', 'Nature', 'Fashion', 'Social Work', 'Meditation'];

  Future<void> _next() async {
    final ok = await ref.read(onboardingProvider.notifier).saveLifestyle({
      'diet': _diet,
      'smoking': _smoking ?? 'never',
      'drinking': _drinking ?? 'never',
      'hobbies': _hobbies.toList(),
      'interests': _interests.toList(),
    });
    if (ok && mounted) {
      if (widget.isEditing) {
        context.pop();
      } else {
        context.go(AppRoutes.onboardingNativePlace);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    return OnboardingScaffold(
      currentStep: 5,
      title: 'Lifestyle',
      subtitle: 'Share your lifestyle preferences to find better compatible matches.',
      isLoading: state.isLoading,
      error: state.error,
      onNext: _next,
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VivaDropdownField<String>(
            label: 'Diet',
            value: _diet,
            items: const [
              DropdownMenuItem(value: 'vegetarian', child: Text('Vegetarian')),
              DropdownMenuItem(value: 'non_vegetarian', child: Text('Non-Vegetarian')),
              DropdownMenuItem(value: 'eggetarian', child: Text('Eggetarian')),
              DropdownMenuItem(value: 'vegan', child: Text('Vegan')),
              DropdownMenuItem(value: 'jain', child: Text('Jain')),
              DropdownMenuItem(value: 'other', child: Text('Other')),
            ],
            onChanged: (v) => setState(() => _diet = v),
          ),
          const SizedBox(height: 16),
          VivaDropdownField<String>(
            label: 'Smoking',
            value: _smoking ?? 'never',
            items: const [
              DropdownMenuItem(value: 'never', child: Text('Never')),
              DropdownMenuItem(value: 'occasionally', child: Text('Occasionally')),
              DropdownMenuItem(value: 'regularly', child: Text('Regularly')),
            ],
            onChanged: (v) => setState(() => _smoking = v),
          ),
          const SizedBox(height: 16),
          VivaDropdownField<String>(
            label: 'Drinking',
            value: _drinking ?? 'never',
            items: const [
              DropdownMenuItem(value: 'never', child: Text('Never')),
              DropdownMenuItem(value: 'occasionally', child: Text('Occasionally')),
              DropdownMenuItem(value: 'socially', child: Text('Socially')),
              DropdownMenuItem(value: 'regularly', child: Text('Regularly')),
            ],
            onChanged: (v) => setState(() => _drinking = v),
          ),
          const SizedBox(height: 20),
          const Text('Hobbies', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _allHobbies.map((h) => _SelectChip(
              label: h,
              isSelected: _hobbies.contains(h),
              onTap: () => setState(() => _hobbies.contains(h) ? _hobbies.remove(h) : _hobbies.add(h)),
            )).toList(),
          ),
          const SizedBox(height: 20),
          const Text('Interests', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8, runSpacing: 8,
            children: _allInterests.map((i) => _SelectChip(
              label: i,
              isSelected: _interests.contains(i),
              onTap: () => setState(() => _interests.contains(i) ? _interests.remove(i) : _interests.add(i)),
            )).toList(),
          ),
        ],
      ),
    );
  }
}

class _SelectChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _SelectChip({required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryContainer : AppTheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Text(label, style: TextStyle(
          fontSize: 12, fontWeight: FontWeight.w500,
          color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
        )),
      ),
    );
  }
}
