import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';

class OnboardingState {
  final bool isLoading;
  final String? error;

  const OnboardingState({
    this.isLoading = false,
    this.error,
  });

  OnboardingState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      OnboardingState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class OnboardingNotifier extends Notifier<OnboardingState> {
  @override
  OnboardingState build() => const OnboardingState();

  Future<bool> saveBasicInfo(Map<String, dynamic> data) =>
      _save(() async {
        final client = ref.read(apiClientProvider);
        await client.post('/profile', data: data);

        // Save location separately
        if (data['current_city'] != null || data['current_state'] != null) {
          await client.put('/profile/location', data: {
            'country': data['current_country'] ?? 'India',
            'state': data['current_state'],
            'district': data['current_district'],
            'city': data['current_city'],
          });
        }
      });

  Future<bool> saveBio(String aboutMe) => _save(() async {
        final client = ref.read(apiClientProvider);
        await client.put('/profile', data: {'about_me': aboutMe});
      });

  Future<bool> saveEducation(Map<String, dynamic> data) => _save(() async {
        final client = ref.read(apiClientProvider);
        await client.put('/profile/education', data: data);
      });

  Future<bool> saveEmployment(Map<String, dynamic> data) => _save(() async {
        final client = ref.read(apiClientProvider);
        await client.put('/profile/employment', data: data);
      });

  Future<bool> saveFamily(Map<String, dynamic> data) => _save(() async {
        final client = ref.read(apiClientProvider);
        await client.put('/profile/family', data: data);
      });

  Future<bool> saveLifestyle(Map<String, dynamic> data) => _save(() async {
        final client = ref.read(apiClientProvider);
        await client.put('/profile/lifestyle', data: data);
      });

  Future<bool> saveNativePlace(Map<String, dynamic> data) => _save(() async {
        final client = ref.read(apiClientProvider);
        await client.put('/profile/native-place', data: data);
      });

  Future<bool> savePreferences(Map<String, dynamic> data) => _save(() async {
        final client = ref.read(apiClientProvider);
        await client.put('/preferences', data: data);
      });

  Future<bool> completeOnboarding() => _save(() async {
        await ref.read(authProvider.notifier).onOnboardingCompleted();
      });

  Future<bool> _save(Future<void> Function() action) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await action();
      state = state.copyWith(isLoading: false);
      return true;
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiException.fromDioError(e).message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to save. Please try again.',
      );
      return false;
    }
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingState>(
  OnboardingNotifier.new,
);
