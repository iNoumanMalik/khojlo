import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/location_service.dart';
import '../../core/maps/geo_repository.dart';
import '../../core/maps/map_types.dart';
import '../../core/models/business.dart';
import '../../core/models/search.dart';
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

/// Asks the Map tab to frame an area once. A new request is a new object, so the same
/// area can be asked for twice.
class MapFitRequest {
  MapFitRequest(this.bounds);
  final GeoBounds bounds;
}

class MapResultsState {
  const MapResultsState({
    this.bounds,
    this.items = const [],
    this.total = 0,
    this.status = MapStatus.idle,
    this.error,
    this.selectedId,
    this.fit,
    this.showingNearest = false,
    this.searchedEverywhere = false,
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

  /// Where the map should move to show the results (a search with nothing in view).
  final MapFitRequest? fit;

  /// Nothing matched in the area the user was looking at, so the map moved to the
  /// nearest matches.
  final bool showingNearest;

  /// The search matched nothing anywhere, not just in this area.
  final bool searchedEverywhere;

  BusinessCard? get selected => items.where((b) => b.id == selectedId).firstOrNull;
  bool get capped => total > items.length;

  MapResultsState copyWith({
    GeoBounds? bounds,
    List<BusinessCard>? items,
    int? total,
    MapStatus? status,
    String? Function()? error,
    int? Function()? selectedId,
    MapFitRequest? fit,
    bool? showingNearest,
    bool? searchedEverywhere,
  }) => MapResultsState(
    bounds: bounds ?? this.bounds,
    items: items ?? this.items,
    total: total ?? this.total,
    status: status ?? this.status,
    error: error != null ? error() : this.error,
    selectedId: selectedId != null ? selectedId() : this.selectedId,
    fit: fit ?? this.fit,
    showingNearest: showingNearest ?? this.showingNearest,
    searchedEverywhere: searchedEverywhere ?? this.searchedEverywhere,
  );
}

/// Module 6 (FR-12, UC-9): the businesses inside the visible map area, using the same
/// keyword and filters as Explore, so switching between list and map keeps the search.
/// Results refresh when the map stops moving; stale responses are dropped. A new search
/// with no match in view looks everywhere and moves the map to the nearest matches.
class MapResultsNotifier extends StateNotifier<MapResultsState> {
  MapResultsNotifier(this._ref) : super(const MapResultsState());

  final Ref _ref;
  Timer? _debounce;
  int _requestId = 0;

  /// The map is moving to the nearest matches; its next idle is that move, not the user's.
  bool _fitPending = false;

  /// Most pins drawn at once (the backend's page limit).
  static const maxPins = 100;
  static const debounce = Duration(milliseconds: 300);

  /// The nearest matches framed together: the closest one, plus others within this
  /// distance or 1.5× the closest one's, whichever is larger (at most [nearestShown]).
  static const nearbyMeters = 3000.0;
  static const nearestShown = 10;

  /// The map settled on a new area.
  void onCameraIdle(GeoBounds bounds) {
    final area = bounds.rounded();
    if (area == state.bounds && state.status != MapStatus.error) return;
    final arrived = _fitPending;
    _fitPending = false;
    // The note stays for the move to the nearest matches, and goes once the user moves on.
    state = state.copyWith(bounds: area, showingNearest: arrived && state.showingNearest);
    _debounce?.cancel();
    _debounce = Timer(debounce, refresh);
  }

  void select(int? id) {
    if (id != state.selectedId) state = state.copyWith(selectedId: () => id);
  }

  /// Loads the visible area. [newSearch] (a new keyword or filters) also looks beyond it
  /// when nothing in view matches.
  Future<void> refresh({bool newSearch = false}) async {
    final bounds = state.bounds;
    if (bounds == null) return;
    final id = ++_requestId;
    state = state.copyWith(
      status: MapStatus.loading,
      error: () => null,
      showingNearest: newSearch ? false : null,
      searchedEverywhere: false,
    );
    try {
      final filters = _ref.read(searchControllerProvider).filters;
      final fix = _ref.read(locationControllerProvider).fix;
      final page = await _ref
          .read(searchRepositoryProvider)
          .search(filters, lat: fix?.latitude, lng: fix?.longitude, limit: maxPins, bounds: bounds);
      if (id != _requestId || !mounted) return;
      final items = page.items.where((b) => b.location != null).toList();
      if (items.isEmpty && newSearch && (filters.hasQuery || filters.hasFilters)) {
        await _showNearest(id, filters, bounds, fix?.point);
        return;
      }
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

  /// Nothing matched in view: finds the nearest matches anywhere and asks the map to
  /// frame them. The area search that follows the move then shows everything there.
  Future<void> _showNearest(int id, SearchFilters filters, GeoBounds area, GeoPoint? fix) async {
    // Distance from what the user is looking at, except that a distance filter is
    // measured from the user.
    final origin = filters.radiusKm != null && fix != null ? fix : area.center;
    final page = await _ref
        .read(searchRepositoryProvider)
        .search(
          filters.copyWith(sort: SearchSort.distance),
          lat: origin.latitude,
          lng: origin.longitude,
          limit: 20,
        );
    if (id != _requestId || !mounted) return;
    final found = [
      for (final b in page.items)
        if (b.location != null) (business: b, meters: distanceMeters(origin, b.location!)),
    ]..sort((a, b) => a.meters.compareTo(b.meters));
    if (found.isEmpty) {
      state = state.copyWith(
        items: const [],
        total: 0,
        status: MapStatus.ready,
        selectedId: () => null,
        searchedEverywhere: true,
      );
      return;
    }
    final reach = math.max(nearbyMeters, found.first.meters * 1.5);
    final nearest = [
      for (final f in found)
        if (f.meters <= reach) f.business,
    ].take(nearestShown).toList();
    _fitPending = true;
    state = state.copyWith(
      items: nearest,
      total: nearest.length,
      status: MapStatus.ready,
      selectedId: () => null,
      showingNearest: true,
      fit: MapFitRequest(GeoBounds.around([for (final b in nearest) b.location!])!),
    );
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
  ref.listen(
    searchControllerProvider.select((s) => s.filters),
    (_, __) => notifier.refresh(newSearch: true),
  );
  return notifier;
});
