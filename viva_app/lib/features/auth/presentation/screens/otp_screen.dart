import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_button.dart';
import '../providers/auth_screen_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  final String phone;
  const OtpScreen({super.key, required this.phone});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  int _secondsLeft = AppConstants.otpResendCooldownSec;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _focusNodes[0].requestFocus());
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = AppConstants.otpResendCooldownSec);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 0) {
        t.cancel();
      } else {
        if (mounted) setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) { c.dispose(); }
    for (final f in _focusNodes) { f.dispose(); }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();
  bool get _otpComplete => _otp.length == AppConstants.otpLength;

  void _onOtpDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _focusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    // Clear any previous error so the user can re-attempt without
    // being blocked by a stale error state from an earlier bad OTP.
    if (ref.read(authScreenProvider).error != null) {
      ref.read(authScreenProvider.notifier).clearError();
    }
    final state = ref.read(authScreenProvider);
    if (_otpComplete && !state.isLoading) _verify();
  }

  Future<void> _verify() async {
    if (!_otpComplete) return;
    if (ref.read(authScreenProvider).isLoading) return;
    await ref.read(authScreenProvider.notifier).verifyOtp(
          phone: widget.phone,
          otp: _otp,
          onNewUser: () => context.go(AppRoutes.welcome),
          onExistingUser: () => context.go(AppRoutes.home),
        );
  }

  Future<void> _resend() async {
    _clearOtp();
    await ref.read(authScreenProvider.notifier).resendOtp(
          phone: widget.phone,
          onSuccess: _startTimer,
        );
  }

  void _clearOtp() {
    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authScreenProvider);
    final hasError = state.error != null;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: AppShadows.card,
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: AppTheme.textPrimary),
          ),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // ── Header ────────────────────────────────────────────────
              // WhatsApp icon circle
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.whatsAppGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.chat_bubble_outline_rounded,
                    size: 30, color: AppTheme.whatsAppGreen),
              ),
              const SizedBox(height: 20),

              const Text(
                'Enter verification code',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                        text: 'We sent a 6-digit code to your WhatsApp\n'),
                    TextSpan(
                      text: widget.phone,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // ── OTP boxes ─────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(
                  6,
                  (i) => _OtpBox(
                    controller: _controllers[i],
                    focusNode: _focusNodes[i],
                    onChanged: (v) => _onOtpDigitChanged(i, v),
                    hasError: hasError,
                  ),
                ),
              ),

              // Error message
              if (hasError) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(
                        color: AppTheme.error.withValues(alpha: 0.25), width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          size: 15, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.error!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.error),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 36),

              // ── Verify button ──────────────────────────────────────────
              VivaButton(
                label: 'Verify & Continue',
                isLoading: state.isLoading,
                onPressed: _otpComplete ? _verify : null,
              ),

              const SizedBox(height: 28),

              // ── Resend ────────────────────────────────────────────────
              Center(
                child: _secondsLeft > 0
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.timer_outlined,
                              size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 6),
                          Text(
                            'Resend code in ${_secondsLeft}s',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      )
                    : TextButton.icon(
                        icon: const Icon(Icons.refresh_rounded,
                            size: 16, color: AppTheme.primary),
                        label: const Text(
                          'Resend OTP',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: state.isLoading ? null : _resend,
                      ),
              ),

              const SizedBox(height: 12),
              Center(
                child: Text(
                  'OTP valid for ${AppConstants.otpValidityMin} minutes',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.textTertiary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String) onChanged;
  final bool hasError;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 58,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w800,
          color: hasError ? AppTheme.error : AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          filled: true,
          fillColor: hasError
              ? AppTheme.error.withValues(alpha: 0.06)
              : Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
              color: hasError
                  ? AppTheme.error.withValues(alpha: 0.6)
                  : AppTheme.border,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
            borderSide: BorderSide(
              color: hasError ? AppTheme.error : AppTheme.primary,
              width: 2,
            ),
          ),
        ),
        onChanged: onChanged,
      ),
    );
  }
}
