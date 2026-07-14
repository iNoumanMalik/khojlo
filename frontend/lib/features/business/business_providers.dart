import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/analytics.dart';
import '../../core/models/business.dart';
import 'data/business_repository.dart';

/// Businesses owned by the current user (drives CTA-vs-dashboard on the Business tab).
final myBusinessesProvider =
    FutureProvider.autoDispose<List<BusinessCard>>((ref) async {
  return ref.watch(businessRepositoryProvider).mine();
});

/// Category list (shared by registration + search).
final categoriesProvider =
    FutureProvider<List<Category>>((ref) async {
  return ref.watch(businessRepositoryProvider).categories();
});

/// Analytics for a specific owned business.
final analyticsProvider =
    FutureProvider.autoDispose.family<BusinessAnalytics, int>((ref, id) async {
  return ref.watch(businessRepositoryProvider).analytics(id);
});

/// Offers for a specific business.
final offersProvider =
    FutureProvider.autoDispose.family<List<Offer>, int>((ref, id) async {
  return ref.watch(businessRepositoryProvider).offers(id);
});
