import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_text_field.dart';
import '../providers/onboarding_provider.dart';
import '../widgets/onboarding_scaffold.dart';

class OnboardingNativePlaceScreen extends ConsumerStatefulWidget {
  const OnboardingNativePlaceScreen({super.key});
  @override
  ConsumerState<OnboardingNativePlaceScreen> createState() => _State();
}

class _State extends ConsumerState<OnboardingNativePlaceScreen> {
  // Current location
  final _currCityCtrl = TextEditingController();
  final _currDistrictCtrl = TextEditingController();
  String? _currState;

  // Native place
  final _nativeCityCtrl = TextEditingController();
  final _nativeDistrictCtrl = TextEditingController();
  String? _nativeState;
  bool _nativeVisible = true;

  static const _states = [
    'Andhra Pradesh', 'Arunachal Pradesh', 'Assam', 'Bihar', 'Chhattisgarh',
    'Goa', 'Gujarat', 'Haryana', 'Himachal Pradesh', 'Jharkhand', 'Karnataka',
    'Kerala', 'Madhya Pradesh', 'Maharashtra', 'Manipur', 'Meghalaya', 'Mizoram',
    'Nagaland', 'Odisha', 'Punjab', 'Rajasthan', 'Sikkim', 'Tamil Nadu',
    'Telangana', 'Tripura', 'Uttar Pradesh', 'Uttarakhand', 'West Bengal',
    'Delhi', 'Jammu and Kashmir', 'Ladakh', 'Puducherry', 'Other',
  ];

  @override
  void dispose() {
    _currCityCtrl.dispose(); _currDistrictCtrl.dispose();
    _nativeCityCtrl.dispose(); _nativeDistrictCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    // Save current location
    final client = ref.read(onboardingProvider.notifier);
    await client.saveNativePlace({
      'state': _nativeState,
      'district': _nativeDistrictCtrl.text.trim().isEmpty ? null : _nativeDistrictCtrl.text.trim(),
      'city': _nativeCityCtrl.text.trim().isEmpty ? null : _nativeCityCtrl.text.trim(),
      'is_visible': _nativeVisible,
    });

    // Current location handled separately
    final apiClient = ref.read(onboardingProvider.notifier);
    // We call profile/location via the profile endpoint
    if (mounted) context.push(AppRoutes.onboardingPreferences);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(onboardingProvider);
    return OnboardingScaffold(
      currentStep: 6,
      title: 'Location',
      subtitle: 'Your current city and native place are important for families to know.',
      isLoading: state.isLoading,
      error: state.error,
      onNext: _next,
      onBack: () => context.pop(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader('📍 Current Location'),
          const SizedBox(height: 12),
          VivaDropdownField<String>(
            label: 'Current State',
            value: _currState,
            items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _currState = v),
          ),
          const SizedBox(height: 12),
          VivaTextField(label: 'Current District', controller: _currDistrictCtrl),
          const SizedBox(height: 12),
          VivaTextField(label: 'Current City / Town', controller: _currCityCtrl),
          const SizedBox(height: 24),
          _sectionHeader('🏡 Native Place'),
          const SizedBox(height: 12),
          VivaDropdownField<String>(
            label: 'Native State',
            value: _nativeState,
            items: _states.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: (v) => setState(() => _nativeState = v),
          ),
          const SizedBox(height: 12),
          VivaTextField(label: 'Native District', controller: _nativeDistrictCtrl),
          const SizedBox(height: 12),
          VivaTextField(label: 'Native City / Village / Town', controller: _nativeCityCtrl),
          const SizedBox(height: 16),
          Row(
            children: [
              Switch(
                value: _nativeVisible,
                onChanged: (v) => setState(() => _nativeVisible = v),
                activeColor: AppTheme.primary,
              ),
              const SizedBox(width: 8),
              const Text('Show native place on profile', style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary,
              )),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(text, style: const TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600, color: AppTheme.textPrimary,
    ));
  }
}
