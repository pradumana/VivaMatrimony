import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/constants/app_constants.dart';
import '../../../../shared/models/user_model.dart';
import '../../../../shared/widgets/error_view.dart';
import '../../../../shared/widgets/profile_card.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});
  @override
  ConsumerState<SearchScreen> createState() => _State();
}

class _State extends ConsumerState<SearchScreen> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  int? _minAge, _maxAge;
  String? _state;
  String? _religion;
  String? _diet;
  bool _verifiedOnly = false;
  bool _hasPhoto = false;

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
      _minAge != null ||
      _state != null ||
      _religion != null ||
      _verifiedOnly ||
      _hasPhoto;

  Future<void> _search({bool reset = true}) async {
    if (_loading) return;
    if (reset) {
      setState(() {
        _page = 1;
        _results = [];
        _hasMore = true;
      });
    }
    setState(() {
      _loading = true;
      _error = null;
    });

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
        if (_verifiedOnly) params['verified_only'] = true;
        if (_hasPhoto) params['has_photo'] = true;
      }

      final response =
          await client.get('/search', queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      final newResults = (data['results'] as List)
          .map((e) =>
              ProfileSummary.fromJson(e as Map<String, dynamic>))
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
      setState(() {
        _loading = false;
        _error = ApiException.fromDioError(e).message;
      });
    }
  }

  void _loadMore() {
    _page++;
    _search(reset: false);
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _FilterSheet(
        minAge: _minAge,
        maxAge: _maxAge,
        state: _state,
        religion: _religion,
        diet: _diet,
        verifiedOnly: _verifiedOnly,
        hasPhoto: _hasPhoto,
        onApply: (filters) {
          setState(() {
            _minAge = filters['min_age'] as int?;
            _maxAge = filters['max_age'] as int?;
            _state = filters['state'] as String?;
            _religion = filters['religion'] as String?;
            _diet = filters['diet'] as String?;
            _verifiedOnly = filters['verified_only'] as bool? ?? false;
            _hasPhoto = filters['has_photo'] as bool? ?? false;
          });
          _search();
        },
      ),
    );
  }

  void _clearFilter(String key) {
    setState(() {
      switch (key) {
        case 'age':
          _minAge = null;
          _maxAge = null;
        case 'state':
          _state = null;
        case 'religion':
          _religion = null;
        case 'verified':
          _verifiedOnly = false;
        case 'photo':
          _hasPhoto = false;
      }
    });
    _search();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Search'),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.tune_rounded),
                onPressed: _showFilters,
                tooltip: 'Filters',
              ),
              if (_hasActiveFilters)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Search bar ─────────────────────────────────────────────
          Container(
            margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppShadows.card,
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.only(left: 14),
                  child: Icon(Icons.search_rounded,
                      color: AppTheme.textSecondary, size: 20),
                ),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _searchCtrl,
                    builder: (context, value, _) => TextField(
                      controller: _searchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Name or Member ID (e.g. VIVA001234)',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textTertiary,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        suffixIcon: value.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    size: 18, color: AppTheme.textSecondary),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _search();
                                })
                            : null,
                      ),
                      onChanged: (_) {
                        _debounce?.cancel();
                        _debounce = Timer(
                            const Duration(milliseconds: 400), _search);
                      },
                      onSubmitted: (_) => _search(),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Member ID hint
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: _searchCtrl,
            builder: (context, value, _) {
              final trimmed = value.text.trim();
              if (!trimmed.toUpperCase().startsWith('VIVA') ||
                  trimmed.isEmpty) {
                return const SizedBox.shrink();
              }
              return const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Row(
                  children: [
                    Icon(Icons.badge_outlined,
                        size: 13, color: AppTheme.primary),
                    SizedBox(width: 5),
                    Text(
                      'Searching by Member ID',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          // Active filter chips
          if (_hasActiveFilters)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  if (_minAge != null)
                    _FilterChip(
                        label: '$_minAge–${_maxAge ?? 60} yrs',
                        onRemove: () => _clearFilter('age')),
                  if (_state != null)
                    _FilterChip(
                        label: _state!,
                        onRemove: () => _clearFilter('state')),
                  if (_religion != null)
                    _FilterChip(
                        label: _religion!,
                        onRemove: () => _clearFilter('religion')),
                  if (_verifiedOnly)
                    _FilterChip(
                        label: '✓ Verified',
                        onRemove: () => _clearFilter('verified')),
                  if (_hasPhoto)
                    _FilterChip(
                        label: '📸 With Photo',
                        onRemove: () => _clearFilter('photo')),
                ],
              ),
            ),

          // Results count
          if (!_loading && _results.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '$_total profiles found',
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.textSecondary),
                ),
              ),
            ),

          // Results
          Expanded(
            child: _error != null
                ? ErrorView(message: _error, onRetry: _search)
                : _results.isEmpty && !_loading
                    ? const EmptyStateView(
                        icon: Icons.search_off_rounded,
                        title: 'No profiles found',
                        subtitle:
                            'Try adjusting your filters to see more results.',
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >=
                                  n.metrics.maxScrollExtent - 200 &&
                              _hasMore &&
                              !_loading) {
                            _loadMore();
                          }
                          return false;
                        },
                        child: ListView.builder(
                          itemCount:
                              _results.length + (_loading ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _results.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: CircularProgressIndicator(
                                      color: AppTheme.primary,
                                      strokeWidth: 2),
                                ),
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
                              onTap: () => context
                                  .push('/profile/${m.userId}'),
                              onInterest: () => context
                                  .push('/profile/${m.userId}'),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

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
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primary)),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 14, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  final int? minAge, maxAge;
  final String? state, religion, diet;
  final bool verifiedOnly, hasPhoto;
  final void Function(Map<String, dynamic>) onApply;

  const _FilterSheet({
    this.minAge,
    this.maxAge,
    this.state,
    this.religion,
    this.diet,
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

  @override
  void initState() {
    super.initState();
    _minAge = widget.minAge ?? 18;
    _maxAge = widget.maxAge ?? 60;
    _state = widget.state;
    _religion = widget.religion;
    _diet = widget.diet;
    _verifiedOnly = widget.verifiedOnly;
    _hasPhoto = widget.hasPhoto;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Column(
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 14, bottom: 4),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
            child: Row(
              children: [
                const Text('Filters',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const Spacer(),
                TextButton(
                  onPressed: () => setState(() {
                    _minAge = 18;
                    _maxAge = 60;
                    _state = null;
                    _religion = null;
                    _diet = null;
                    _verifiedOnly = false;
                    _hasPhoto = false;
                  }),
                  child: const Text('Reset all'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              children: [
                // Age range
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Age Range',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryContainer,
                        borderRadius:
                            BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text('$_minAge – $_maxAge yrs',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.primary)),
                    ),
                  ],
                ),
                RangeSlider(
                  values: RangeValues(
                      _minAge.toDouble(), _maxAge.toDouble()),
                  min: 18,
                  max: 70,
                  divisions: 52,
                  activeColor: AppTheme.primary,
                  inactiveColor: AppTheme.border,
                  onChanged: (v) => setState(() {
                    _minAge = v.start.round();
                    _maxAge = v.end.round();
                  }),
                ),
                const SizedBox(height: 16),

                _dropdown('State', _state, [
                  'Any',
                  'Uttar Pradesh',
                  'Maharashtra',
                  'Delhi',
                  'Gujarat',
                  'Karnataka',
                  'Tamil Nadu',
                  'Rajasthan',
                  'Bihar',
                  'West Bengal'
                ], (v) => setState(() => _state = v == 'Any' ? null : v)),
                const SizedBox(height: 14),

                _dropdown('Religion', _religion, [
                  'Any',
                  'Hindu',
                  'Muslim',
                  'Sikh',
                  'Christian',
                  'Jain',
                  'Buddhist',
                  'Other'
                ],
                    (v) => setState(
                        () => _religion = v == 'Any' ? null : v)),
                const SizedBox(height: 14),

                _dropdown('Diet', _diet, [
                  'Any',
                  'vegetarian',
                  'non_vegetarian',
                  'eggetarian',
                  'vegan',
                  'jain'
                ], (v) => setState(() => _diet = v == 'Any' ? null : v)),
                const SizedBox(height: 8),

                _switchTile(
                  'Verified profiles only',
                  Icons.verified_rounded,
                  _verifiedOnly,
                  (v) => setState(() => _verifiedOnly = v),
                ),
                _switchTile(
                  'With profile photo',
                  Icons.photo_camera_outlined,
                  _hasPhoto,
                  (v) => setState(() => _hasPhoto = v),
                ),
              ],
            ),
          ),
          // Apply button
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            decoration: const BoxDecoration(
              color: Colors.white,
              border:
                  Border(top: BorderSide(color: AppTheme.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  widget.onApply({
                    // Pass null only when the slider is at the absolute range
                    // boundary AND was not deliberately set by the user.
                    // This ensures age-18 or age-70 are honoured when chosen.
                    'min_age': _minAge,
                    'max_age': _maxAge,
                    'state': _state,
                    'religion': _religion,
                    'diet': _diet,
                    'verified_only': _verifiedOnly,
                    'has_photo': _hasPhoto,
                  });
                },
                child: const Text('Apply Filters'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dropdown(String label, String? value, List<String> options,
      void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value ?? options.first,
      decoration: InputDecoration(labelText: label),
      items: options
          .map((o) => DropdownMenuItem(value: o, child: Text(o)))
          .toList(),
      onChanged: onChanged,
    );
  }

  Widget _switchTile(String label, IconData icon, bool value,
      void Function(bool) onChanged) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: value
            ? AppTheme.primaryContainer
            : AppTheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon,
              size: 18,
              color:
                  value ? AppTheme.primary : AppTheme.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: value
                      ? AppTheme.primary
                      : AppTheme.textPrimary,
                )),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppTheme.primary,
          ),
        ],
      ),
    );
  }
}
