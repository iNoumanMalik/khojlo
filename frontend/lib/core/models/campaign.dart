// Promotional campaigns, mirroring backend/app/schemas/campaign.py.

import 'business.dart';
import 'photo.dart';

/// A live campaign as a Home banner.
class CampaignBanner {
  const CampaignBanner({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.businessId,
    required this.businessName,
    required this.offerCount,
    this.message = '',
    this.banner,
    this.tone = 'gold',
    this.topDeal,
  });

  final int id;
  final String name;
  final String message;
  final Photo? banner;
  final String tone;
  final DateTime startDate;
  final DateTime endDate;
  final int businessId;
  final String businessName;
  final int offerCount;

  /// The first offer's badge text, e.g. "20% OFF".
  final String? topDeal;

  String get rangeLabel => dateRangeLabel(startDate, endDate);

  factory CampaignBanner.fromJson(Map<String, dynamic> j) => CampaignBanner(
        id: j['id'] as int,
        name: j['name'] as String,
        message: j['message'] as String? ?? '',
        banner: Photo.maybe(j['banner']),
        tone: j['tone'] as String? ?? 'gold',
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: DateTime.parse(j['end_date'] as String),
        businessId: j['business_id'] as int,
        businessName: j['business_name'] as String? ?? '',
        offerCount: j['offer_count'] as int? ?? 0,
        topDeal: j['top_deal'] as String?,
      );
}

/// A campaign in full: customers get its live offers, the owner every linked offer.
class Campaign {
  const Campaign({
    required this.id,
    required this.name,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.business,
    this.description = '',
    this.message = '',
    this.banner,
    this.terms = '',
    this.isPublished = false,
    this.notifySavers = false,
    this.isVisible = false,
    this.offers = const [],
    this.services = const [],
  });

  final int id;
  final String name;
  final String description;
  final String message;
  final Photo? banner;
  final DateTime startDate;
  final DateTime endDate;
  final String terms;
  final bool isPublished;
  final bool notifySavers;
  final PromoStatus status;

  /// Customers can see it right now.
  final bool isVisible;
  final List<Offer> offers;
  final List<Service> services;
  final BusinessCard business;

  String get rangeLabel => dateRangeLabel(startDate, endDate);

  factory Campaign.fromJson(Map<String, dynamic> j) => Campaign(
        id: j['id'] as int,
        name: j['name'] as String,
        description: j['description'] as String? ?? '',
        message: j['message'] as String? ?? '',
        banner: Photo.maybe(j['banner']),
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: DateTime.parse(j['end_date'] as String),
        terms: j['terms'] as String? ?? '',
        isPublished: j['is_published'] as bool? ?? false,
        notifySavers: j['notify_savers'] as bool? ?? false,
        status: PromoStatus.parse(j['status'] as String?),
        isVisible: j['is_visible'] as bool? ?? false,
        offers: (j['offers'] as List? ?? const [])
            .map((e) => Offer.fromJson(e as Map<String, dynamic>))
            .toList(),
        services: (j['services'] as List? ?? const [])
            .map((e) => Service.fromJson(e as Map<String, dynamic>))
            .toList(),
        business: BusinessCard.fromJson(j['business'] as Map<String, dynamic>),
      );
}
