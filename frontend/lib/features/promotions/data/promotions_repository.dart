import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/business.dart';
import '../../../core/models/campaign.dart';
import '../../../core/providers.dart';

final promotionsRepositoryProvider = Provider<PromotionsRepository>((ref) {
  return PromotionsRepository(ref.watch(dioProvider));
});

String apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// The fields an owner edits on an offer.
class OfferDraft {
  const OfferDraft({
    required this.title,
    required this.dealType,
    required this.startDate,
    this.description = '',
    this.dealValue,
    this.dealText = '',
    this.endDate,
    this.terms = '',
    this.isActive = false,
  });

  final String title;
  final String description;
  final DealType dealType;
  final double? dealValue;
  final String dealText;
  final DateTime startDate;
  final DateTime? endDate;
  final String terms;
  final bool isActive;

  Map<String, dynamic> toJson() => {
        'title': title,
        'description': description,
        'deal_type': dealType.api,
        'deal_value': dealValue,
        'deal_text': dealText,
        'start_date': apiDate(startDate),
        'end_date': endDate == null ? null : apiDate(endDate!),
        'terms': terms,
        'is_active': isActive,
      };
}

/// The fields an owner edits on a campaign.
class CampaignDraft {
  const CampaignDraft({
    required this.name,
    required this.startDate,
    required this.endDate,
    this.description = '',
    this.message = '',
    this.bannerKey,
    this.terms = '',
    this.offerIds = const [],
    this.serviceIds = const [],
    this.isPublished = false,
    this.notifySavers = false,
  });

  final String name;
  final String description;
  final String message;

  /// An uploaded photo's key; null for the colour gradient.
  final String? bannerKey;
  final DateTime startDate;
  final DateTime endDate;
  final String terms;
  final List<int> offerIds;
  final List<int> serviceIds;
  final bool isPublished;
  final bool notifySavers;

  Map<String, dynamic> toJson() => {
        'name': name,
        'description': description,
        'message': message,
        'banner': bannerKey,
        'start_date': apiDate(startDate),
        'end_date': apiDate(endDate),
        'terms': terms,
        'offer_ids': offerIds,
        'service_ids': serviceIds,
        'is_published': isPublished,
        'notify_savers': notifySavers,
      };
}

/// Special offers and promotional campaigns.
class PromotionsRepository {
  PromotionsRepository(this._dio);
  final Dio _dio;

  /// The owner gets every offer; everyone else only live ones.
  Future<List<Offer>> offers(int businessId) async {
    final res = await _dio.get('/businesses/$businessId/offers');
    return (res.data as List).map((e) => Offer.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Offer> saveOffer(int businessId, OfferDraft draft, {int? offerId}) async {
    final res = offerId == null
        ? await _dio.post('/businesses/$businessId/offers', data: draft.toJson())
        : await _dio.patch('/businesses/$businessId/offers/$offerId', data: draft.toJson());
    return Offer.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Offer> setOfferActive(int businessId, int offerId, bool active) async {
    final res = await _dio.patch('/businesses/$businessId/offers/$offerId',
        data: {'is_active': active});
    return Offer.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteOffer(int businessId, int offerId) =>
      _dio.delete('/businesses/$businessId/offers/$offerId');

  Future<List<Campaign>> campaigns(int businessId) async {
    final res = await _dio.get('/businesses/$businessId/campaigns');
    return (res.data as List).map((e) => Campaign.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<Campaign> saveCampaign(int businessId, CampaignDraft draft, {int? campaignId}) async {
    final res = campaignId == null
        ? await _dio.post('/businesses/$businessId/campaigns', data: draft.toJson())
        : await _dio.patch('/businesses/$businessId/campaigns/$campaignId',
            data: draft.toJson());
    return Campaign.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Campaign> setPublished(int businessId, int campaignId, bool published) async {
    final res = await _dio.patch('/businesses/$businessId/campaigns/$campaignId',
        data: {'is_published': published});
    return Campaign.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteCampaign(int businessId, int campaignId) =>
      _dio.delete('/businesses/$businessId/campaigns/$campaignId');

  Future<Campaign> campaign(int id) async {
    final res = await _dio.get('/campaigns/$id');
    return Campaign.fromJson(res.data as Map<String, dynamic>);
  }
}
