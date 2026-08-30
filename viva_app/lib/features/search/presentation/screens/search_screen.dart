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

  // Filters
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
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _search({bool reset = true}) async {
    if (_loading) return;
    if (reset) { setState(() { _page = 1; _results = []; _hasMore = true; }); }

    setState(() { _loading = true; _error = null; });

    try {
      final client = ref.read(apiClientProvider);
      final params = <String, dynamic>{
        'page': _page,
        'page_size': AppConstants.defaultPageSize,
        if (_minAge != null) 'min_age': _minAge,
        if (_maxAge != null) 'max_age': _maxAge,
        if (_state != null) 'state': _state,
        if (_religion != null) 'religion': _religion,
        if (_diet != null) 'diet': _diet,
        if (_verifiedOnly) 'verified_only': true,
        if (_hasPhoto) 'has_photo': true,
      };

      final response = await client.get('/search', queryParameters: params);
      final data = response.data as Map<String, dynamic>;
      final newResults = (data['results'] as List)
          .map((e) => ProfileSummary.fromJson(e as Map<String, dynamic>))
          .toList();

      setState(() {
        _loading = false;
        _total = data['total'] as int? ?? 0;
        if (reset) _results = newResults; else _results.addAll(newResults);
        _hasMore = _results.length < _total;
      });
    } on DioException catch (e) {
      setState(() { _loading = false; _error = ApiException.fromDioError(e).message; });
    }
  }

  void _loadMore() { _page++; _search(reset: false); }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _FilterSheet(
        minAge: _minAge, maxAge: _maxAge,
        state: _state, religion: _religion, diet: _diet,
        verifiedOnly: _verifiedOnly, hasPhoto: _hasPhoto,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Search Matches'),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showFilters,
            tooltip: 'Filters',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Search by name, location...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.clear, size: 18), onPressed: () { _searchCtrl.clear(); _search(); })
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (_) { if (_searchCtrl.text.length != 1) _search(); },
              onSubmitted: (_) => _search(),
            ),
          ),

          // Active filters chips
          if (_minAge != null || _state != null || _religion != null || _verifiedOnly || _hasPhoto)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  if (_minAge != null) _FilterChip(label: '$_minAge–${_maxAge ?? 60} yrs', onRemove: () { setState(() { _minAge = null; _maxAge = null; }); _search(); }),
                  if (_state != null) _FilterChip(label: _state!, onRemove: () { setState(() => _state = null); _search(); }),
                  if (_religion != null) _FilterChip(label: _religion!, onRemove: () { setState(() => _religion = null); _search(); }),
                  if (_verifiedOnly) _FilterChip(label: 'Verified', onRemove: () { setState(() => _verifiedOnly = false); _search(); }),
                  if (_hasPhoto) _FilterChip(label: 'With Photo', onRemove: () { setState(() => _hasPhoto = false); _search(); }),
                ],
              ),
            ),

          // Results count
          if (!_loading && _results.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('$_total results found', style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, color: AppTheme.textSecondary)),
              ),
            ),

          Expanded(
            child: _error != null
                ? ErrorView(message: _error, onRetry: _search)
                : _results.isEmpty && !_loading
                    ? const EmptyStateView(
                        icon: Icons.search_off_rounded,
                        title: 'No matches found',
                        subtitle: 'Try adjusting your filters to see more results.',
                      )
                    : NotificationListener<ScrollNotification>(
                        onNotification: (n) {
                          if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200 && _hasMore && !_loading) {
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
                                child: Center(child: CircularProgressIndicator(color: AppTheme.primary, strokeWidth: 2)),
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
      margin: const EdgeInsets.only(right: 8, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppTheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontFamily: 'Poppins', fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.primary)),
          const SizedBox(width: 4),
          GestureDetector(onTap: onRemove, child: const Icon(Icons.close, size: 14, color: AppTheme.primary)),
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

  const _FilterSheet({this.minAge, this.maxAge, this.state, this.religion, this.diet, required this.verifiedOnly, required this.hasPhoto, required this.onApply});

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
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => Container(
        padding: const EdgeInsets.all(24),
        child: ListView(
          controller: controller,
          children: [
            Row(
              children: [
                const Text('Filters', style: TextStyle(fontFamily: 'Poppins', fontSize: 18, fontWeight: FontWeight.w700)),
                const Spacer(),
                TextButton(
                  onPressed: () { setState(() { _minAge = 18; _maxAge = 60; _state = null; _religion = null; _diet = null; _verifiedOnly = false; _hasPhoto = false; }); },
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text('Age: $_minAge – $_maxAge years', style: const TextStyle(fontFamily: 'Poppins', fontSize: 13, fontWeight: FontWeight.w600)),
            RangeSlider(
              values: RangeValues(_minAge.toDouble(), _maxAge.toDouble()),
              min: 18, max: 70,
              divisions: 52,
              activeColor: AppTheme.primary,
              onChanged: (v) => setState(() { _minAge = v.start.round(); _maxAge = v.end.round(); }),
            ),
            const SizedBox(height: 12),
            _sheetDropdown('State', _state, ['Any', 'Uttar Pradesh', 'Maharashtra', 'Delhi', 'Gujarat', 'Karnataka', 'Tamil Nadu', 'Rajasthan', 'Bihar', 'West Bengal'], (v) => setState(() => _state = v == 'Any' ? null : v)),
            const SizedBox(height: 12),
            _sheetDropdown('Religion', _religion, ['Any', 'Hindu', 'Muslim', 'Sikh', 'Christian', 'Jain', 'Buddhist', 'Other'], (v) => setState(() => _religion = v == 'Any' ? null : v)),
            const SizedBox(height: 12),
            _sheetDropdown('Diet', _diet, ['Any', 'vegetarian', 'non_vegetarian', 'eggetarian', 'vegan', 'jain'], (v) => setState(() => _diet = v == 'Any' ? null : v)),
            const SizedBox(height: 12),
            SwitchListTile(title: const Text('Verified profiles only', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)), value: _verifiedOnly, onChanged: (v) => setState(() => _verifiedOnly = v), activeColor: AppTheme.primary),
            SwitchListTile(title: const Text('Profiles with photo only', style: TextStyle(fontFamily: 'Poppins', fontSize: 13)), value: _hasPhoto, onChanged: (v) => setState(() => _hasPhoto = v), activeColor: AppTheme.primary),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onApply({'min_age': _minAge == 18 ? null : _minAge, 'max_age': _maxAge == 70 ? null : _maxAge, 'state': _state, 'religion': _religion, 'diet': _diet, 'verified_only': _verifiedOnly, 'has_photo': _hasPhoto});
              },
              child: const Text('Apply Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetDropdown(String label, String? value, List<String> options, void Function(String?) onChanged) {
    return DropdownButtonFormField<String>(
      value: value ?? options.first,
      decoration: InputDecoration(labelText: label),
      items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
      onChanged: onChanged,
    );
  }
}
