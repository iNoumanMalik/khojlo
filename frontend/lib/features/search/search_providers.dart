import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/location_service.dart';
import '../../core/models/business.dart';
import '../../core/models/search.dart';
import '../../core/network/api_client.dart';
import 'data/search_repository.dart';

enum SearchStatus { idle, loading, ready, error }

class SearchState {
  const SearchState({
    this.filters = const SearchFilters(),
    this.input = '',
    this.suggestQuery = '',
    this.items = const [],
    this.total = 0,
    this.summary = '',
    this.relaxed = false,
    this.status = SearchStatus.idle,
    this.loadingMore = false,
    this.error,
  });

  /// Filters (and keyword) behind the current results.
  final SearchFilters filters;

  /// What's in the search field right now.
  final String input;

  /// Debounced field text that typeahead suggestions are fetched for.
  final String suggestQuery;
  final List<BusinessCard> items;
  final int total;
  final String summary;
  final bool relaxed;
  final SearchStatus status;
  final bool loadingMore;
  final String? error;

  /// Results mode (vs. the idle recent/popular/categories view).
  bool get showResults => filters.hasQuery || filters.hasFilters;
  bool get hasMore => items.length < total;

  SearchState copyWith({
    SearchFilters? filters,
    String? input,
    String? suggestQuery,
    List<BusinessCard>? items,
    int? total,
    String? summary,
    bool? relaxed,
    SearchStatus? status,
    bool? loadingMore,
    String? Function()? error,
  }) =>
      SearchState(
        filters: filters ?? this.filters,
        input: input ?? this.input,
        suggestQuery: suggestQuery ?? this.suggestQuery,
        items: items ?? this.items,
        total: total ?? this.total,
        summary: summary ?? this.summary,
        relaxed: relaxed ?? this.relaxed,
        status: status ?? this.status,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error != null ? error() : this.error,
      );
}

/// Drives the Explore tab: live (debounced) search while typing, submitted searches
/// (recorded in history), filters, sorting and paging. Stale responses are dropped, so
/// fast typing never shows results for an older query.
class SearchNotifier extends StateNotifier<SearchState> {
  SearchNotifier(this._ref) : super(const SearchState());

  final Ref _ref;
  Timer? _debounce;
  int _requestId = 0;

  static const pageSize = 20;
  static const debounce = Duration(milliseconds: 350);

  SearchRepository get _repo => _ref.read(searchRepositoryProvider);

  void onInputChanged(String text) {
    state = state.copyWith(input: text);
    _debounce?.cancel();
    _debounce = Timer(debounce, () {
      state = state.copyWith(suggestQuery: text.trim());
      _run(state.filters.copyWith(query: text.trim()));
    });
  }

  /// Search for [text] (or the field's text) and save it to history.
  Future<void> submit([String? text]) async {
    _debounce?.cancel();
    final q = (text ?? state.input).trim();
    state = state.copyWith(input: q, suggestQuery: '');
    await _run(state.filters.copyWith(query: q), record: q.isNotEmpty);
    if (q.isNotEmpty) _ref.invalidate(searchHistoryProvider);
  }

  void clearQuery() {
    _debounce?.cancel();
    state = state.copyWith(input: '', suggestQuery: '');
    _run(state.filters.copyWith(query: ''));
  }

  /// Show one category with no keyword (Home's category chips, idle category chips).
  Future<void> browseCategory(String slug) {
    _debounce?.cancel();
    state = state.copyWith(input: '', suggestQuery: '');
    return _run(SearchFilters(categories: {slug}, sort: state.filters.sort));
  }

  Future<void> applyFilters(SearchFilters filters) =>
      _run(filters.copyWith(query: state.filters.query));

  Future<void> removeFilter(ActiveFilter chip) => _run(state.filters.without(chip));

  Future<void> clearFilters() => _run(state.filters.withoutFilters());

  Future<void> setSort(SearchSort sort) => _run(state.filters.copyWith(sort: sort));

  Future<void> retry() => _run(state.filters);

  /// Back to the idle view.
  void reset() {
    _debounce?.cancel();
    _requestId++;
    state = const SearchState();
  }

  /// Re-run the current search, e.g. once the device location becomes available.
  Future<void> refresh() async {
    if (state.showResults) await _run(state.filters);
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.status != SearchStatus.ready) {
      return;
    }
    final id = _requestId;
    state = state.copyWith(loadingMore: true);
    try {
      final fix = _ref.read(locationControllerProvider).fix;
      final page = await _repo.search(
        state.filters,
        lat: fix?.latitude,
        lng: fix?.longitude,
        limit: pageSize,
        offset: state.items.length,
      );
      if (id != _requestId || !mounted) return;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        total: page.total,
        loadingMore: false,
      );
    } catch (_) {
      if (id == _requestId && mounted) state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> _run(SearchFilters filters, {bool record = false}) async {
    final id = ++_requestId;
    if (!filters.hasQuery && !filters.hasFilters) {
      state = state.copyWith(
        filters: filters,
        items: const [],
        total: 0,
        summary: '',
        relaxed: false,
        status: SearchStatus.idle,
        error: () => null,
      );
      return;
    }
    state = state.copyWith(filters: filters, status: SearchStatus.loading, error: () => null);
    try {
      final fix = _ref.read(locationControllerProvider).fix;
      final page = await _repo.search(
        filters,
        lat: fix?.latitude,
        lng: fix?.longitude,
        limit: pageSize,
        record: record,
      );
      if (id != _requestId || !mounted) return;
      state = state.copyWith(
        items: page.items,
        total: page.total,
        summary: page.summary,
        relaxed: page.relaxed,
        status: SearchStatus.ready,
      );
    } catch (e) {
      if (id != _requestId || !mounted) return;
      state = state.copyWith(status: SearchStatus.error, error: () => describeApiError(e));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final searchControllerProvider =
    StateNotifierProvider<SearchNotifier, SearchState>((ref) => SearchNotifier(ref));

/// Bumped by other screens (e.g. Home's search pill) to focus the Explore search field.
final searchFocusRequestProvider = StateProvider<int>((ref) => 0);

/// The user's recent searches (empty when signed out or on error).
final searchHistoryProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    return await ref.watch(searchRepositoryProvider).history();
  } catch (_) {
    return const [];
  }
});

final popularSearchesProvider = FutureProvider.autoDispose<List<String>>((ref) async {
  try {
    return await ref.watch(searchRepositoryProvider).popular();
  } catch (_) {
    return const [];
  }
});

final suggestionsProvider =
    FutureProvider.autoDispose.family<List<SearchSuggestion>, String>((ref, q) async {
  if (q.trim().isEmpty) return const [];
  try {
    return await ref.watch(searchRepositoryProvider).suggestions(q.trim());
  } catch (_) {
    return const [];
  }
});

/// How many places a draft set of filters would return ("Show N results").
final filterPreviewCountProvider =
    FutureProvider.autoDispose.family<int, SearchFilters>((ref, filters) async {
  final fix = ref.read(locationControllerProvider).fix;
  final page = await ref
      .watch(searchRepositoryProvider)
      .search(filters, lat: fix?.latitude, lng: fix?.longitude, limit: 1);
  return page.total;
});
