import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/widgets/viva_button.dart';

class VerificationReferenceScreen extends ConsumerStatefulWidget {
  const VerificationReferenceScreen({super.key});
  @override
  ConsumerState<VerificationReferenceScreen> createState() => _State();
}

class _State extends ConsumerState<VerificationReferenceScreen> {
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  String? _error;
  String? _successName;

  @override
  void dispose() { _phoneCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });

    try {
      final client = ref.read(apiClientProvider);
      final response = await client.post('/verification/reference', data: {
        'reference_phone': _phoneCtrl.text.trim(),
      });
      final data = response.data as Map<String, dynamic>;
      setState(() {
        _loading = false;
        _successName = data['reference_name'] as String? ?? 'Member';
      });
    } on DioException catch (e) {
      setState(() {
        _loading = false;
        _error = ApiException.fromDioError(e).message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Member Reference'), leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.pop())),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _successName != null ? _SuccessView(name: _successName!, onDone: () => context.go(AppRoutes.verificationStatus)) : Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Enter Reference\'s WhatsApp Number', style: TextStyle(fontFamily: 'Poppins', fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                const Text('The reference must be an existing registered Viva member.', style: TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
                const SizedBox(height: 28),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s]'))],
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w500, letterSpacing: 2),
                  decoration: const InputDecoration(labelText: 'Reference\'s Mobile Number', hintText: '+91 98765 43210', prefixIcon: Icon(Icons.phone_outlined)),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Please enter the mobile number';
                    if (v.replaceAll(RegExp(r'\D'), '').length < 7) return 'Enter a valid mobile number';
                    return null;
                  },
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: AppTheme.error.withOpacity(0.08), borderRadius: BorderRadius.circular(AppRadius.md)),
                    child: Row(children: [
                      const Icon(Icons.error_outline, size: 16, color: AppTheme.error),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.error))),
                    ]),
                  ),
                ],
                const Spacer(),
                VivaButton(label: 'Find & Add Reference', isLoading: _loading, onPressed: _submit),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final String name;
  final VoidCallback onDone;
  const _SuccessView({required this.name, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 80, height: 80,
          decoration: const BoxDecoration(color: Color(0xFFE8F8EF), shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_outline, size: 44, color: AppTheme.success),
        ),
        const SizedBox(height: 20),
        const Text('Reference Added!', style: TextStyle(fontFamily: 'Poppins', fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('$name has been added as your reference.\nYour profile is pending verification.', textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, color: AppTheme.textSecondary, height: 1.5)),
        const SizedBox(height: 32),
        VivaButton(label: 'Continue to Home', onPressed: onDone),
      ],
    );
  }
}
