import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_button.dart';
import '../providers/auth_screen_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authScreenProvider.notifier).sendPasswordReset(
          email: _emailCtrl.text,
          onSuccess: () => setState(() => _sent = true),
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authScreenProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            width: 38, height: 38,
            decoration: const BoxDecoration(
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
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding, vertical: 8),
          child: _sent ? _SuccessView(_emailCtrl.text) : _FormView(
            formKey: _formKey,
            emailCtrl: _emailCtrl,
            isLoading: state.isLoading,
            error: state.error,
            onSend: _send,
            onClearError: () =>
                ref.read(authScreenProvider.notifier).clearError(),
          ),
        ),
      ),
    );
  }
}

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final bool isLoading;
  final String? error;
  final VoidCallback onSend;
  final VoidCallback onClearError;

  const _FormView({
    required this.formKey,
    required this.emailCtrl,
    required this.isLoading,
    required this.error,
    required this.onSend,
    required this.onClearError,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64, height: 64,
            decoration: const BoxDecoration(
              color: AppTheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.lock_reset_rounded,
                size: 30, color: AppTheme.primary),
          ),
          const SizedBox(height: 20),
          const Text(
            'Reset your password',
            style: TextStyle(
              fontSize: 24, fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary, letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your email and we\'ll send you a link to reset your password.',
            style: TextStyle(
                fontSize: 13, color: AppTheme.textSecondary, height: 1.5),
          ),
          const SizedBox(height: 32),

          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofocus: true,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                  .hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
            onChanged: (_) => onClearError(),
            onFieldSubmitted: (_) => isLoading ? null : onSend(),
          ),

          if (error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border:
                    Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline,
                      size: 16, color: AppTheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                      child: Text(error!,
                          style: const TextStyle(
                              fontSize: 12, color: AppTheme.error))),
                ],
              ),
            ),
          ],

          const SizedBox(height: 28),
          VivaButton(
            label: 'Send Reset Link',
            icon: Icons.send_rounded,
            isLoading: isLoading,
            onPressed: isLoading ? null : onSend,
          ),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String email;
  const _SuccessView(this.email);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64, height: 64,
          decoration: const BoxDecoration(
            color: AppTheme.successSurface,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.mark_email_read_outlined,
              size: 30, color: AppTheme.success),
        ),
        const SizedBox(height: 20),
        const Text(
          'Check your email',
          style: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'We\'ve sent a password reset link to\n${email.trim().toLowerCase()}',
          style: const TextStyle(
              fontSize: 14, color: AppTheme.textSecondary, height: 1.6),
        ),
        const SizedBox(height: 8),
        const Text(
          'Check your inbox (and spam folder). The link expires after 1 hour.',
          style: TextStyle(
              fontSize: 12, color: AppTheme.textTertiary, height: 1.5),
        ),
        const SizedBox(height: 32),
        VivaButton(
          label: 'Back to Sign In',
          onPressed: () => context.go(AppRoutes.login),
        ),
      ],
    );
  }
}
