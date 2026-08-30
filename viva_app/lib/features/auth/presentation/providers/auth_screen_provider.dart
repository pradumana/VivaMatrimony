import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/providers/auth_provider.dart';

class AuthScreenState {
  final bool isLoading;
  final String? error;
  final String? maskedPhone;
  final int resendAfter;
  final bool otpSent;

  const AuthScreenState({
    this.isLoading = false,
    this.error,
    this.maskedPhone,
    this.resendAfter = 60,
    this.otpSent = false,
  });

  AuthScreenState copyWith({
    bool? isLoading,
    String? error,
    String? maskedPhone,
    int? resendAfter,
    bool? otpSent,
    bool clearError = false,
  }) =>
      AuthScreenState(
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
        maskedPhone: maskedPhone ?? this.maskedPhone,
        resendAfter: resendAfter ?? this.resendAfter,
        otpSent: otpSent ?? this.otpSent,
      );
}

class AuthScreenNotifier extends Notifier<AuthScreenState> {
  @override
  AuthScreenState build() => const AuthScreenState();

  Future<void> sendOtp({
    required BuildContext context,
    required String phone,
    required VoidCallback onSuccess,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post('/auth/send-otp', data: {'phone': phone});
      final data = response.data as Map<String, dynamic>;

      state = state.copyWith(
        isLoading: false,
        maskedPhone: data['masked_phone'] as String?,
        resendAfter: data['resend_after'] as int? ?? 60,
        otpSent: true,
      );
      onSuccess();
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiException.fromDioError(e).message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Something went wrong. Please try again.',
      );
    }
  }

  Future<void> verifyOtp({
    required String phone,
    required String otp,
    required VoidCallback onNewUser,
    required VoidCallback onExistingUser,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post('/auth/verify-otp', data: {
        'phone': phone,
        'otp': otp,
        'device_info': 'Flutter Android',
      });

      final data = response.data as Map<String, dynamic>;
      final isNewUser = data['is_new_user'] as bool? ?? true;

      await ref.read(authProvider.notifier).onLoginSuccess(
            userId: data['user_id'] as String,
            onboardingCompleted:
                data['onboarding_completed'] as bool? ?? false,
            accessToken: data['access_token'] as String,
            refreshToken: data['refresh_token'] as String,
          );

      state = state.copyWith(isLoading: false);
      if (isNewUser || !(data['onboarding_completed'] as bool? ?? false)) {
        onNewUser();
      } else {
        onExistingUser();
      }
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiException.fromDioError(e).message,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Verification failed. Please try again.',
      );
    }
  }

  Future<void> resendOtp({
    required String phone,
    required VoidCallback onSuccess,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final client = ref.read(apiClientProvider);
      await client.post('/auth/send-otp', data: {'phone': phone});
      state = state.copyWith(isLoading: false, otpSent: true);
      onSuccess();
    } on DioException catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: ApiException.fromDioError(e).message,
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final authScreenProvider =
    NotifierProvider<AuthScreenNotifier, AuthScreenState>(
  AuthScreenNotifier.new,
);
