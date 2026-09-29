import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/business.dart';
import '../../core/models/campaign.dart';
import 'data/promotions_repository.dart';

/// Bumped after the owner changes an offer or campaign, so lists and the dashboard reload.
final promotionChangesProvider = StateProvider<int>((ref) => 0);

/// An owned business's offers (all of them, drafts included).
final ownerOffersProvider =
    FutureProvider.autoDispose.family<List<Offer>, int>((ref, businessId) async {
  ref.watch(promotionChangesProvider);
  return ref.watch(promotionsRepositoryProvider).offers(businessId);
});

final ownerCampaignsProvider =
    FutureProvider.autoDispose.family<List<Campaign>, int>((ref, businessId) async {
  ref.watch(promotionChangesProvider);
  return ref.watch(promotionsRepositoryProvider).campaigns(businessId);
});

/// One campaign's details (customers: only while it's live).
final campaignProvider = FutureProvider.autoDispose.family<Campaign, int>((ref, id) async {
  ref.watch(promotionChangesProvider);
  return ref.watch(promotionsRepositoryProvider).campaign(id);
});
