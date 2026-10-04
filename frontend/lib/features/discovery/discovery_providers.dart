import 'dart:async';

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

/// Business detail (records a view server-side on each fetch). Kept for a minute
/// after the page closes, so reopening it is instant.
final businessDetailProvider =
    FutureProvider.autoDispose.family<BusinessDetail, int>((ref, id) async {
  final detail = await ref.watch(discoveryRepositoryProvider).detail(id);
  final link = ref.keepAlive();
  final timer = Timer(const Duration(minutes: 1), link.close);
  ref.onDispose(timer.cancel);
  return detail;
});

/// Shuffle stack for "Surprise Me".
final surpriseProvider =
    FutureProvider.autoDispose<List<BusinessCard>>((ref) async {
  return ref.watch(discoveryRepositoryProvider).surprise();
});
