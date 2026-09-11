import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/profile_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  // Filters
  int? _minAge, _maxAge;
  String? _state, _religion, _diet, _caste, _subCaste, _gotra;
  bool _verifiedOnly = false, _hasPhoto = false;

  List<ProfileSummary> _results = [];
  int _total = 0;
  bool _loading = false;
  String? _error;
  int _page = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasActiveFilters =>
      _minAge != null || _maxAge != null || _state != null ||
      _religion != null || _diet != null || _caste != null ||
      _subCaste != null || _gotra != null || _verifiedOnly || _hasPhoto;

  Future<void> _search({bool reset = true}) async {
    if (_loading) return;
    if (reset) setState(() { _page = 1; _results = []; _hasMore = true; });
    setState(() { _loading = true; _error = null; });

    try {
      final client = ref.read(apiClientProvider);
      final params = <String, dynamic>{
        'page': _page,
        'page_size': AppConstants.defaultPageSize,
      };
      final query = _searchCtrl.text.trim();
      if (query.toUpperCase().startsWith('VIVA')) {
        params['member_id'] = query.toUpperCase();
      } else {
        if (query.isNotEmpty) params['q'] = query;
        if (_minAge != null) params['min_age'] = _minAge;
        if (_maxAge != null) params['max_age'] = _maxAge;
        if (_state != null) params['state'] = _state;
        if (_religion != null) params['religion'] = _religion;
        if (_diet != null) params['diet'] = _diet;
        if (_caste != null) params['caste'] = _caste;
        if (_subCaste != null) params['sub_caste'] = _subCaste;
        if (_gotra != null) params['gotra'] = _gotra;
        if (_verifiedOnly) params['verified_only'] = true;
        if (_hasPhoto) params['has_photo'] = true;
      }

      final response = await client.get('/search', queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      final newResults = (data['results'] as List)
          .map((e) => ProfileSummary.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _loading = false;
        _total = data['total'] as int? ?? 0;
        if (reset) {
          _results = newResults;
        } else {
          _results.addAll(newResults);
        }
        _hasMore = _results.length < _total;
      });
    } on DioException catch (e) {
      setState(() { _loading = false; _error = ApiException.fromDioError(e).message; });
    } catch (_) {
      setState(() { _loading = false; _error = 'Could not load results. Please try again.'; });
    }
  }

  void _loadMore() { _page++; _search(reset: false); }

  void _clearFilter(String key) {
    setState(() {
      switch (key) {
        case 'age': _minAge = null; _maxAge = null;
        case 'state': _state = null;
        case 'religion': _religion = null;
        case 'diet': _diet = null;
        case 'caste': _caste = null;
        case 'sub_caste': _subCaste = null;
        case 'gotra': _gotra = null;
        case 'verified': _verifiedOnly = false;
        case 'photo': _hasPhoto = false;
      }
    });
    _search();
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FilterSheet(
        minAge: _minAge, maxAge: _maxAge,
        state: _state, religion: _religion, diet: _diet,
        caste: _caste, subCaste: _subCaste, gotra: _gotra,
        verifiedOnly: _verifiedOnly, hasPhoto: _hasPhoto,
        onApply: (f) {
          setState(() {
            _minAge = f['min_age'] as int?;
            _maxAge = f['max_age'] as int?;
            _state = f['state'] as String?;
            _religion = f['religion'] as String?;
            _diet = f['diet'] as String?;
            _caste = f['caste'] as String?;
            _subCaste = f['sub_caste'] as String?;
            _gotra = f['gotra'] as String?;
            _verifiedOnly = f['verified_only'] as bool? ?? false;
            _hasPhoto = f['has_photo'] as bool? ?? false;
          });
          _search();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          Stack(children: [
            IconButton(
              icon: const Icon(Icons.tune_rounded),
              onPressed: _showFilters,
              tooltip: 'Filters',
            ),
            if (_hasActiveFilters)
              Positioned(
                right: 8, top: 8,
                child: Container(
                  width: 8, height: 8,
                  decoration: const BoxDecoration(
                      color: AppTheme.primary, shape: BoxShape.circle),
                ),
              ),
          ]),
        ],
      ),
      body: Column(children: [
        // Search bar
        Container(
          margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppShadows.card,
          ),
          child: Row(children: [
            const Padding(
              padding: EdgeInsets.only(left: 14),
              child: Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 20),
            ),
            Expanded(
              child: ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchCtrl,
                builder: (context, value, _) => TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: l.searchHint,
                    hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textTertiary),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    suffixIcon: value.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.close_rounded, size: 18, color: AppTheme.textSecondary),
                            onPressed: () { _searchCtrl.clear(); _search(); })
                        : null,
                  ),
                  onChanged: (_) {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 400), _search);
                  },
                  onSubmitted: (_) => _search(),
                ),
              ),
            ),
          ]),
        ),

        // Member ID hint
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: _searchCtrl,
          builder: (context, value, _) {
            final t = value.text.trim();
            if (!t.toUpperCase().startsWith('VIVA') || t.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Row(children: [
                const Icon(Icons.badge_outlined, size: 13, color: AppTheme.primary),
                const SizedBox(width: 5),
                Text(AppLocalizations.of(context).searchByMemberId,
                    style: const TextStyle(fontSize: 11, color: AppTheme.primary, fontWeight: FontWeight.w600)),
              ]),
            );
          },
        ),

        // Active filter chips
        if (_hasActiveFilters)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Row(children: [
              if (_minAge != null)
                _FilterChip(label: '$_minAge–${_maxAge ?? 70} yrs', onRemove: () => _clearFilter('age')),
              if (_state != null)
                _FilterChip(label: _state!, onRemove: () => _clearFilter('state')),
              if (_religion != null)
                _FilterChip(label: _religion!, onRemove: () => _clearFilter('religion')),
              if (_diet != null)
                _FilterChip(label: _diet!.replaceAll('_', ' '), onRemove: () => _clearFilter('diet')),
              if (_caste != null)
                _FilterChip(label: _caste!, onRemove: () => _clearFilter('caste')),
              if (_subCaste != null)
                _FilterChip(label: _subCaste!, onRemove: () => _clearFilter('sub_caste')),
              if (_gotra != null)
                _FilterChip(label: _gotra!, onRemove: () => _clearFilter('gotra')),
              if (_verifiedOnly)
                _FilterChip(label: '✓ Verified', onRemove: () => _clearFilter('verified')),
              if (_hasPhoto)
                _FilterChip(label: '📸 With Photo', onRemove: () => _clearFilter('photo')),
            ]),
          ),

        // Results count
        if (!_loading && _results.isNotEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(l.profilesFound(_total),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            ),
          ),

        // Results list
        Expanded(
          child: _error != null
              ? ErrorView(message: _error, onRetry: _search)
              : _results.isEmpty && !_loading
                  ? EmptyStateView(
                      icon: Icons.search_off_rounded,
                      title: l.noProfilesFound,
                      subtitle: l.tryAdjustingFilters,
                    )
                  : NotificationListener<ScrollNotification>(
                      onNotification: (n) {
                        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 &&
                            _hasMore && !_loading) {
                          _loadMore();
                        }
                        return false;
                      },
                      child: ListView.builder(
                        itemCount: _results.length + (_loading ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _results.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(child: CircularProgressIndicator(
                                  color: AppTheme.primary, strokeWidth: 2)),
                            );
                          }
                          final m = _results[index];
                          return ProfileCard(
                            userId: m.userId,
                            name: m.fullName,
                            age: m.age,
                            location: m.location ?? '',
                            photoUrl: m.photoUrl,
                            qualification: m.qualification,
                            profession: m.profession,
                            isVerified: m.isVerified,
                            compatibilityScore: m.compatibilityScore,
                            onTap: () => context.push('/profile/${m.userId}'),
                            onInterest: () => context.push('/profile/${m.userId}'),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  const _FilterChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(label, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close_rounded, size: 14, color: AppTheme.primary),
        ),
      ]),
    );
  }
}

// ── Filter sheet ──────────────────────────────────────────────────────────────

class _FilterSheet extends StatefulWidget {
  final int? minAge, maxAge;
  final String? state, religion, diet, caste, subCaste, gotra;
  final bool verifiedOnly, hasPhoto;
  final void Function(Map<String, dynamic>) onApply;

  const _FilterSheet({
    this.minAge, this.maxAge,
    this.state, this.religion, this.diet,
    this.caste, this.subCaste, this.gotra,
    required this.verifiedOnly,
    required this.hasPhoto,
    required this.onApply,
  });

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late int _minAge, _maxAge;
  String? _state, _religion, _diet;
  late bool _verifiedOnly, _hasPhoto;
  final _casteCtrl    = TextEditingController();
  final _subCasteCtrl = TextEditingController();
  final _gotraCtrl    = TextEditingController();

  @override
  void initState() {
    super.initState();
    _minAge = widget.minAge ?? 18;
    _maxAge = widget.maxAge ?? 70;
    _state = widget.state;
    _religion = widget.religion;
    _diet = widget.diet;
    _verifiedOnly = widget.verifiedOnly;
    _hasPhoto = widget.hasPhoto;
    _casteCtrl.text    = widget.caste    ?? '';
    _subCasteCtrl.text = widget.subCaste ?? '';
    _gotraCtrl.text    = widget.gotra    ?? '';
  }

  @override
  void dispose() {
    _casteCtrl.dispose();
    _subCasteCtrl.dispose();
    _gotraCtrl.dispose();
    super.dispose();
  }

  void _resetAll() => setState(() {
    _minAge = 18; _maxAge = 70;
    _state = null; _religion = null; _diet = null;
    _verifiedOnly = false; _hasPhoto = false;
    _casteCtrl.clear(); _subCasteCtrl.clear(); _gotraCtrl.clear();
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.80,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(children: [
        Center(
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 14, bottom: 4),
            decoration: BoxDecoration(
                color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
          child: Row(children: [
            Text(l.filters,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const Spacer(),
            TextButton(onPressed: _resetAll, child: Text(l.resetAll)),
          ]),
        ),
        const Divider(height: 1),
        Expanded(
          child: ListView(
            controller: controller,
            padding: const EdgeInsets.all(24),
            children: [
              // Age
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l.ageRange,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius: BorderRadius.circular(AppRadius.full)),
                    child: Text('$_minAge – $_maxAge yrs',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary)),
                  ),
                ],
              ),
              RangeSlider(
                values: RangeValues(_minAge.toDouble(), _maxAge.toDouble()),
                min: 18, max: 70, divisions: 52,
                activeColor: AppTheme.primary, inactiveColor: AppTheme.border,
                onChanged: (v) => setState(() {
                  _minAge = v.start.round(); _maxAge = v.end.round();
                }),
              ),
              const SizedBox(height: 16),
              _dropdown('State', _state, [
                'Any','Uttar Pradesh','Maharashtra','Delhi','Gujarat','Karnataka',
                'Tamil Nadu','Rajasthan','Bihar','West Bengal','Madhya Pradesh',
                'Telangana','Andhra Pradesh','Haryana','Punjab',
              ], (v) => setState(() => _state = v == 'Any' ? null : v)),
              const SizedBox(height: 12),
              _dropdown('Religion', _religion, [
                'Any','Hindu','Muslim','Sikh','Christian','Jain','Buddhist','Other',
              ], (v) => setState(() => _religion = v == 'Any' ? null : v)),
              const SizedBox(height: 12),
              _dropdown('Diet', _diet, [
                'Any','vegetarian','non_vegetarian','eggetarian','vegan','jain',
              ], (v) => setState(() => _diet = v == 'Any' ? null : v)),
              const SizedBox(height: 20),

              // Community
              Text(l.community,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              TextField(controller: _casteCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Caste', hintText: 'e.g. Brahmin, Rajput…')),
              const SizedBox(height: 10),
              TextField(controller: _subCasteCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Sub-caste', hintText: 'e.g. Kanyakubj…')),
              const SizedBox(height: 10),
              TextField(controller: _gotraCtrl,
                  decoration: const InputDecoration(labelText: 'Gotra')),
              const SizedBox(height: 16),

              _switchTile('Verified profiles only', Icons.verified_rounded,
                  _verifiedOnly, (v) => setState(() => _verifiedOnly = v)),
              _switchTile('With profile photo', Icons.photo_camera_outlined,
                  _hasPhoto, (v) => setState(() => _hasPhoto = v)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
          decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.divider))),
          child: SizedBox(
            width: double.infinity, height: 50,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onApply({
                  'min_age': (_minAge == 18 && _maxAge == 70) ? null : _minAge,
                  'max_age': (_minAge == 18 && _maxAge == 70) ? null : _maxAge,
                  'state': _state,
                  'religion': _religion,
                  'diet': _diet,
                  'caste': _casteCtrl.text.trim().isEmpty ? null : _casteCtrl.text.trim(),
                  'sub_caste': _subCasteCtrl.text.trim().isEmpty ? null : _subCasteCtrl.text.trim(),
                  'gotra': _gotraCtrl.text.trim().isEmpty ? null : _gotraCtrl.text.trim(),
                  'verified_only': _verifiedOnly,
                  'has_photo': _hasPhoto,
                });
              },
              child: Text(l.applyFilters),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _dropdown(String label, String? value, List<String> options,
      void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value ?? options.first,
      decoration: InputDecoration(labelText: label),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: onChanged,
    );
  }

  Widget _switchTile(String label, IconData icon, bool value,
      void Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: value ? AppTheme.primaryContainer : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(children: [
        Icon(icon, size: 18, color: value ? AppTheme.primary : AppTheme.textSecondary),
        const SizedBox(width: 10),
        Expanded(
          child: Text(label, style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: value ? AppTheme.primary : AppTheme.textPrimary)),
        ),
        Switch(value: value, onChanged: onChanged, activeThumbColor: AppTheme.primary),
      ]),
    );
  }
}
