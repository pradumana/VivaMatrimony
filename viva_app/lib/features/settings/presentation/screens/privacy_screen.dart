import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/viva_button.dart';

class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});
  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  String _profileVisibility = 'members_only';
  String _photoVisibility = 'members_only';
  bool _showIncome = false;
  bool _showCompany = true;
  bool _showNativePlace = true;
  bool _loading = false;
  bool _saved = false;
  // null = still loading; non-null message = load failed
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _loadError = null);
    try {
      final client = ref.read(apiClientProvider);
      final r = await client.get('/profile');
      final data = r.data as Map<String, dynamic>;
      final profile = data['profile'] as Map<String, dynamic>? ?? {};
      final employment = data['employment'] as Map<String, dynamic>? ?? {};
      // null key means native place was never set — treat as shown (server default)
      final native = data['native_place'] as Map<String, dynamic>?;
      if (!mounted) return;
      setState(() {
        _profileVisibility = profile['profile_visibility'] as String? ?? 'members_only';
        _photoVisibility = profile['photo_visibility'] as String? ?? 'members_only';
        _showIncome = employment['show_income'] as bool? ?? false;
        _showCompany = employment['show_company'] as bool? ?? true;
        // Key absent → native place never configured, default to showing it.
        // Key present but empty map → explicitly hidden.
        _showNativePlace = native == null || native.isNotEmpty;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _loadError = ApiException.fromDioError(e).message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = 'Could not load settings. Please try again.');
    }
  }

  Future<void> _save() async {
    setState(() { _loading = true; });
    try {
      final client = ref.read(apiClientProvider);
      await client.put('/profile', data: {
        'profile_visibility': _profileVisibility,
        'photo_visibility': _photoVisibility,
      });
      await client.put('/profile/employment', data: {
        'show_income': _showIncome,
        'show_company': _showCompany,
      });
      await client.put('/profile/native-place', data: {
        'show_native_place': _showNativePlace,
      });
      setState(() { _loading = false; _saved = true; });
      Future.delayed(const Duration(seconds: 2), () { if (mounted) setState(() => _saved = false); });
    } on DioException catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(ApiException.fromDioError(e).message), backgroundColor: AppTheme.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_loadError != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: AppTheme.error.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.warning_amber_rounded, size: 18, color: AppTheme.error),
                const SizedBox(width: 10),
                Expanded(child: Text(_loadError!, style: const TextStyle(fontSize: 13, color: AppTheme.error))),
                TextButton(onPressed: _loadSettings, child: const Text('Retry')),
              ]),
            ),
            const SizedBox(height: 14),
          ],
          _card('Profile Visibility', 'Who can see your profile', [
            _radio('Public (everyone)', 'public', _profileVisibility, (v) => setState(() => _profileVisibility = v!)),
            _radio('Members only (registered users)', 'members_only', _profileVisibility, (v) => setState(() => _profileVisibility = v!)),
            _radio('Hidden (no one — pause profile)', 'hidden', _profileVisibility, (v) => setState(() => _profileVisibility = v!)),
          ]),
          const SizedBox(height: 14),
          _card('Photo Visibility', 'Who can see your photos', [
            _radio('Public', 'public', _photoVisibility, (v) => setState(() => _photoVisibility = v!)),
            _radio('Members only', 'members_only', _photoVisibility, (v) => setState(() => _photoVisibility = v!)),
            _radio('On interest acceptance', 'on_interest', _photoVisibility, (v) => setState(() => _photoVisibility = v!)),
            _radio('Private (hidden)', 'private', _photoVisibility, (v) => setState(() => _photoVisibility = v!)),
          ]),
          const SizedBox(height: 14),
          _card('Career Privacy', 'Control sensitive career info', [
            _switch('Show company name on profile', _showCompany, (v) => setState(() => _showCompany = v)),
            _switch('Show income on profile', _showIncome, (v) => setState(() => _showIncome = v)),
          ]),
          const SizedBox(height: 14),
          _card('Location Privacy', 'Control location details', [
            _switch('Show native place on profile', _showNativePlace, (v) => setState(() => _showNativePlace = v)),
          ]),
          const SizedBox(height: 24),
          VivaButton(
            label: _saved ? '✓ Saved!' : 'Save Privacy Settings',
            isLoading: _loading,
            onPressed: _save,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _card(String title, String subtitle, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(AppRadius.lg), border: Border.all(color: AppTheme.border)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _radio(String label, String value, String groupValue, ValueChanged<String?> onChanged) {
    return RadioListTile<String>(
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: AppTheme.primary,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _switch(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      title: Text(label, style: const TextStyle(fontSize: 13)),
      value: value,
      onChanged: onChanged,
      activeThumbColor: AppTheme.primary,
      dense: true,
      contentPadding: EdgeInsets.zero,
    );
  }
}
