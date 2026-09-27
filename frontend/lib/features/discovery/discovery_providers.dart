import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/location_service.dart';
import '../../core/models/business.dart';
import '../../core/models/feed.dart';
import 'data/discovery_repository.dart';

/// Home feed. With the device location it adds distances and a "Nearby" row (SDD
/// Screen 1: the location indicator drives nearby recommendations).
final feedProvider = FutureProvider.autoDispose<Feed>((ref) async {
  final fix = ref.watch(locationControllerProvider.select((s) => s.fix));
  return ref
      .watch(discoveryRepositoryProvider)
      .feed(lat: fix?.latitude, lng: fix?.longitude);
});

/// Business detail (records a view server-side on each fetch).
final businessDetailProvider =
    FutureProvider.autoDispose.family<BusinessDetail, int>((ref, id) async {
  return ref.watch(discoveryRepositoryProvider).detail(id);
});

/// Shuffle stack for "Surprise Me".
final surpriseProvider =
    FutureProvider.autoDispose<List<BusinessCard>>((ref) async {
  return ref.watch(discoveryRepositoryProvider).surprise();
});
