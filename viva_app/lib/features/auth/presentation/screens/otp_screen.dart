import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_button.dart';
import '../../../../shared/widgets/viva_logo.dart';
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
    // Auto-focus first field
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focusNodes[0].requestFocus());
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
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
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
    // Only auto-submit when all digits are freshly filled; don't re-trigger
    // while a request is already in flight or an error is being corrected.
    final state = ref.read(authScreenProvider);
    if (_otpComplete && !state.isLoading && state.error == null) _verify();
  }

  Future<void> _verify() async {
    if (!_otpComplete) return;
    // Guard against concurrent taps / auto-submit race
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Verify Number'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Logo
              const VivaLogo(size: 64),
              const SizedBox(height: 20),

              const Text(
                'Enter verification code',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                        text: 'We sent a 6-digit code to your WhatsApp\n'),
                    TextSpan(
                      text: widget.phone,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // OTP boxes
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(6, (i) => _OtpBox(
                  controller: _controllers[i],
                  focusNode: _focusNodes[i],
                  onChanged: (v) => _onOtpDigitChanged(i, v),
                  hasError: state.error != null,
                )),
              ),

              // Error
              if (state.error != null) ...[
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 14, color: AppTheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        state.error!,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: AppTheme.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              VivaButton(
                label: 'Verify',
                isLoading: state.isLoading,
                onPressed: _otpComplete ? _verify : null,
              ),

              const SizedBox(height: 24),

              // Resend
              Center(
                child: _secondsLeft > 0
                    ? Text(
                        'Resend code in ${_secondsLeft}s',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      )
                    : VivaTextButton(
                        label: 'Resend OTP',
                        icon: Icons.refresh_rounded,
                        onPressed: state.isLoading ? null : _resend,
                      ),
              ),

              const SizedBox(height: 16),
              Center(
                child: Text(
                  'OTP valid for ${AppConstants.otpResendCooldownSec ~/ 60 == 0 ? '' : '${AppConstants.otpResendCooldownSec ~/ 60}m '}10 minutes',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
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
      width: 46,
      height: 56,
      child: TextFormField(
        controller: controller,
        focusNode: focusNode,
        keyboardType: TextInputType.number,
        textAlign: TextAlign.center,
        maxLength: 1,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: AppTheme.textPrimary,
        ),
        decoration: InputDecoration(
          counterText: '',
          contentPadding: EdgeInsets.zero,
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError ? AppTheme.error : AppTheme.border,
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: hasError ? AppTheme.error : AppTheme.primary,
              width: 2,
            ),
          ),
          fillColor: hasError
              ? AppTheme.error.withOpacity(0.05)
              : AppTheme.surfaceVariant,
          filled: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
