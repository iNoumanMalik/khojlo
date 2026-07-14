import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/business.dart';
import '../../core/models/feed.dart';
import 'data/discovery_repository.dart';

/// Discovery feed for the Home tab.
final feedProvider = FutureProvider.autoDispose<Feed>((ref) async {
  return ref.watch(discoveryRepositoryProvider).feed();
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
