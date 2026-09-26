import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/location_service.dart';
import '../../core/models/business.dart';
import '../../core/models/search.dart';
import 'data/search_repository.dart';

enum CompareToggle { added, removed, full }

/// Places picked for comparison (2–3). App-wide, so search results and business
/// detail pages add to the same selection.
class CompareController extends StateNotifier<List<BusinessCard>> {
  CompareController() : super(const []);

  static const min = 2;
  static const max = 3;

  bool contains(int id) => state.any((b) => b.id == id);
  bool get isFull => state.length >= max;
  bool get isReady => state.length >= min;

  CompareToggle toggle(BusinessCard business) {
    if (contains(business.id)) {
      remove(business.id);
      return CompareToggle.removed;
    }
    if (isFull) return CompareToggle.full;
    state = [...state, business];
    return CompareToggle.added;
  }

  void remove(int id) => state = [
        for (final b in state)
          if (b.id != id) b,
      ];

  void clear() => state = const [];
}

final compareSelectionProvider =
    StateNotifierProvider<CompareController, List<BusinessCard>>(
        (ref) => CompareController());

/// Comparison for a comma-separated list of ids, e.g. "3,7". Distances are included
/// when the device location is known.
final compareResultProvider =
    FutureProvider.autoDispose.family<CompareResult, String>((ref, idsKey) async {
  final ids = idsKey.split(',').map(int.parse).toList();
  final fix = ref.watch(locationControllerProvider.select((s) => s.fix));
  return ref
      .watch(searchRepositoryProvider)
      .compare(ids, lat: fix?.latitude, lng: fix?.longitude);
});
