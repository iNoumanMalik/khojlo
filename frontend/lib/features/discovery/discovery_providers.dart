import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/location/location_service.dart';
import '../../core/models/business.dart';
import '../../core/models/feed.dart';
import 'data/discovery_repository.dart';

/// Home feed. With the device location it adds distances and a "Nearby" row (SDD
/// Screen 1: the location indicator drives nearby recommendations).
final feedProvider = FutureProvider.autoDispose<Feed>((ref) async {
  final fix = ref.watch(locationControllerProvider.select((s) => s.fix));
  final seed = ref.watch(feedSeedProvider);
  return ref
      .watch(discoveryRepositoryProvider)
      .feed(lat: fix?.latitude, lng: fix?.longitude, seed: seed);
});

/// Picks which businesses the feed's rotating rows show. It changes only on
/// pull-to-refresh, so returning to Home shows the same feed as before.
final feedSeedProvider = StateProvider<int>((ref) => _newSeed());

int _newSeed() => Random().nextInt(1 << 31);

/// Pull-to-refresh: a new seed, so the server picks a fresh mix of places.
Future<Feed> refreshFeed(WidgetRef ref) {
  ref.read(feedSeedProvider.notifier).state = _newSeed();
  return ref.read(feedProvider.future);
}

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
