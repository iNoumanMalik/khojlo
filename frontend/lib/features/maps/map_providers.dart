import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/location_service.dart';
import '../../core/maps/map_types.dart';
import '../../core/models/business.dart';
import '../../core/network/api_client.dart';
import '../search/data/search_repository.dart';
import '../search/search_providers.dart';

/// Asks the Map tab to show a place, e.g. "View on map" on a business page.
class MapFocus {
  const MapFocus(this.point, {this.businessId});
  final GeoPoint point;
  final int? businessId;
}

final mapFocusProvider = StateProvider<MapFocus?>((ref) => null);

enum MapStatus { idle, loading, ready, error }

class MapResultsState {
  const MapResultsState({
    this.bounds,
    this.items = const [],
    this.total = 0,
    this.status = MapStatus.idle,
    this.error,
    this.selectedId,
  });

  /// The visible map area the results are for.
  final GeoBounds? bounds;

  /// Places in the area that have a map location.
  final List<BusinessCard> items;

  /// How many places match in the area (can exceed [items] when capped).
  final int total;
  final MapStatus status;
  final String? error;
  final int? selectedId;

  BusinessCard? get selected => items.where((b) => b.id == selectedId).firstOrNull;
  bool get capped => total > items.length;

  MapResultsState copyWith({
    GeoBounds? bounds,
    List<BusinessCard>? items,
    int? total,
    MapStatus? status,
    String? Function()? error,
    int? Function()? selectedId,
  }) => MapResultsState(
    bounds: bounds ?? this.bounds,
    items: items ?? this.items,
    total: total ?? this.total,
    status: status ?? this.status,
    error: error != null ? error() : this.error,
    selectedId: selectedId != null ? selectedId() : this.selectedId,
  );
}

/// Module 6 (FR-12, UC-9): the businesses inside the visible map area, using the same
/// keyword and filters as Explore, so switching between list and map keeps the search.
/// Results refresh when the map stops moving; stale responses are dropped.
class MapResultsNotifier extends StateNotifier<MapResultsState> {
  MapResultsNotifier(this._ref) : super(const MapResultsState());

  final Ref _ref;
  Timer? _debounce;
  int _requestId = 0;

  /// Most pins drawn at once (the backend's page limit).
  static const maxPins = 100;
  static const debounce = Duration(milliseconds: 300);

  /// The map settled on a new area.
  void onCameraIdle(GeoBounds bounds) {
    final area = bounds.rounded();
    if (area == state.bounds && state.status != MapStatus.error) return;
    state = state.copyWith(bounds: area);
    _debounce?.cancel();
    _debounce = Timer(debounce, refresh);
  }

  void select(int? id) {
    if (id != state.selectedId) state = state.copyWith(selectedId: () => id);
  }

  Future<void> refresh() async {
    final bounds = state.bounds;
    if (bounds == null) return;
    final id = ++_requestId;
    state = state.copyWith(status: MapStatus.loading, error: () => null);
    try {
      final filters = _ref.read(searchControllerProvider).filters;
      final fix = _ref.read(locationControllerProvider).fix;
      final page = await _ref
          .read(searchRepositoryProvider)
          .search(filters, lat: fix?.latitude, lng: fix?.longitude, limit: maxPins, bounds: bounds);
      if (id != _requestId || !mounted) return;
      final items = page.items.where((b) => b.location != null).toList();
      final keep = items.any((b) => b.id == state.selectedId);
      state = state.copyWith(
        items: items,
        total: page.total,
        status: MapStatus.ready,
        selectedId: keep ? null : () => null,
      );
    } catch (e) {
      if (id != _requestId || !mounted) return;
      state = state.copyWith(status: MapStatus.error, error: () => describeApiError(e));
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}

final mapResultsProvider = StateNotifierProvider<MapResultsNotifier, MapResultsState>((ref) {
  final notifier = MapResultsNotifier(ref);
  // New keyword or filters (typed here or on Explore) → reload the same area.
  ref.listen(searchControllerProvider.select((s) => s.filters), (_, __) => notifier.refresh());
  return notifier;
});
