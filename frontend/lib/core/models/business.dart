// Domain models mirroring the backend Pydantic schemas.

import '../maps/map_types.dart';
import 'photo.dart';

class Category {
  const Category({
    required this.id,
    required this.slug,
    required this.name,
    required this.tone,
    this.emoji = '',
    this.groupName = '',
    this.sortOrder = 0,
    this.isOther = false,
    this.businessCount = 0,
  });

  final int id;
  final String slug;
  final String name;
  final String tone;
  final String emoji;

  /// Heading the category is listed under ("Food & Drink", "Services", ...).
  final String groupName;
  final int sortOrder;

  /// The catch-all "Other": the owner describes their business in their own words.
  final bool isOther;

  /// Published businesses in this category (from `GET /categories`).
  final int businessCount;

  /// "🧵 Tailors & Fabric".
  String get label => emoji.isEmpty ? name : '$emoji $name';

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as int,
        slug: j['slug'] as String,
        name: j['name'] as String,
        tone: j['tone'] as String? ?? 'gold',
        emoji: j['emoji'] as String? ?? '',
        groupName: j['group_name'] as String? ?? '',
        sortOrder: j['sort_order'] as int? ?? 0,
        isOther: j['is_other'] as bool? ?? false,
        businessCount: j['business_count'] as int? ?? 0,
      );
}

/// Categories bucketed by group, keeping the server's order within and across groups.
List<(String, List<Category>)> groupCategories(Iterable<Category> categories) {
  final groups = <String, List<Category>>{};
  for (final c in categories) {
    groups.putIfAbsent(c.groupName, () => []).add(c);
  }
  return [for (final e in groups.entries) (e.key, e.value)];
}

/// Formats a rupee amount with thousands separators: 2500 → "Rs 2,500".
String formatRupees(int amount) {
  final digits = amount.toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(',');
    buf.write(digits[i]);
  }
  return 'Rs $buf';
}

/// "Rs 800–2,500", "From Rs 800", "Up to Rs 2,500", or '' when unknown.
String priceRangeLabel(int? min, int? max) {
  if (min != null && max != null) {
    if (min == max) return formatRupees(min);
    return '${formatRupees(min)}–${formatRupees(max).substring(3)}';
  }
  if (min != null) return 'From ${formatRupees(min)}';
  if (max != null) return 'Up to ${formatRupees(max)}';
  return '';
}

class BusinessCard {
  const BusinessCard({
    required this.id,
    required this.name,
    required this.tagline,
    required this.tone,
    required this.address,
    required this.priceLevel,
    required this.rating,
    required this.reviewCount,
    required this.saveCount,
    required this.isVerified,
    this.categoryName,
    this.distanceKm,
    this.categorySlug,
    this.priceMin,
    this.priceMax,
    this.isOpenNow,
    this.todayHours,
    this.hasOffer = false,
    this.isNew = false,
    this.cover,
    this.categoryLabel,
    this.latitude,
    this.longitude,
    this.activeCampaign,
    this.isSuspended = false,
  });

  final int id;
  final String name;
  final String tagline;
  final String tone;
  final String address;
  final String priceLevel;
  final double rating;
  final int reviewCount;
  final int saveCount;
  final bool isVerified;
  final String? categoryName;
  final double? distanceKm;

  // ── Module 4 ──
  final String? categorySlug;

  /// Optional price range in PKR.
  final int? priceMin;
  final int? priceMax;

  /// null when the business hasn't published opening hours.
  final bool? isOpenNow;

  /// "09:00–22:00", "Open 24 hours", "Closed today", or null.
  final String? todayHours;
  final bool hasOffer;

  /// Joined Khojlo recently (backend `NEW_BUSINESS_DAYS`).
  final bool isNew;

  /// The main photo, shown on every card. null → the tone gradient.
  final Photo? cover;

  /// What kind of business it is: the category, or the owner's own words for "Other".
  final String? categoryLabel;

  /// A live promotional campaign ("Active promotion" badge); null when there's none.
  final CampaignRef? activeCampaign;

  // ── Module 6 ──
  final double? latitude;
  final double? longitude;

  // ── Module 8: taken down by a moderator (only the owner still sees it) ──
  final bool isSuspended;

  /// Where to put the map pin; null without valid coordinates (SRS BR-7).
  GeoPoint? get location {
    if (latitude == null || longitude == null) return null;
    final p = GeoPoint(latitude!, longitude!);
    return p.isValid ? p : null;
  }

  String? get typeLabel => categoryLabel ?? categoryName;

  bool get hasReviews => reviewCount > 0;

  /// "★ 4.6", or "No reviews" before anyone has reviewed it (Module 5: real ratings only).
  String get ratingLabel => hasReviews ? '★ ${rating.toStringAsFixed(1)}' : 'No reviews';

  String get distanceLabel =>
      distanceKm == null ? '' : '${distanceKm!.toStringAsFixed(1)} km';

  String get priceRange => priceRangeLabel(priceMin, priceMax);

  /// Price shown on cards: the rupee range when known, otherwise the tier.
  String get priceLabel => priceRange.isNotEmpty ? priceRange : priceLevel;

  /// "open" / "closed" / '' (unknown).
  String get openLabel => switch (isOpenNow) {
        true => 'open',
        false => 'closed',
        null => '',
      };

  factory BusinessCard.fromJson(Map<String, dynamic> j) =>
      RecentCards.remember(_cardFromJson(j));

  static BusinessCard _cardFromJson(Map<String, dynamic> j) => BusinessCard(
        id: j['id'] as int,
        name: j['name'] as String,
        tagline: j['tagline'] as String? ?? '',
        tone: j['tone'] as String? ?? 'gold',
        address: j['address'] as String? ?? '',
        priceLevel: j['price_level'] as String? ?? '\$\$',
        rating: (j['rating'] as num?)?.toDouble() ?? 0,
        reviewCount: j['review_count'] as int? ?? 0,
        saveCount: j['save_count'] as int? ?? 0,
        isVerified: j['is_verified'] as bool? ?? false,
        categoryName: j['category_name'] as String?,
        distanceKm: (j['distance_km'] as num?)?.toDouble(),
        categorySlug: j['category_slug'] as String?,
        priceMin: j['price_min'] as int?,
        priceMax: j['price_max'] as int?,
        isOpenNow: j['is_open_now'] as bool?,
        todayHours: j['today_hours'] as String?,
        hasOffer: j['has_offer'] as bool? ?? false,
        isNew: j['is_new'] as bool? ?? false,
        cover: Photo.maybe(j['cover']),
        categoryLabel: j['category_label'] as String?,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        activeCampaign: CampaignRef.maybe(j['active_campaign']),
        isSuspended: j['is_suspended'] as bool? ?? false,
      );
}

class Service {
  const Service({
    required this.id,
    required this.name,
    required this.price,
    this.priceAmount,
  });
  final int id;
  final String name;

  /// Display text, e.g. "Rs 650".
  final String price;

  /// The same price in PKR, when the owner entered one.
  final int? priceAmount;

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String,
        price: j['price'] as String? ?? '',
        priceAmount: j['price_amount'] as int?,
      );
}

/// One weekday's opening hours. `dayOfWeek` 0 = Monday … 6 = Sunday.
class OpeningHours {
  const OpeningHours({
    required this.dayOfWeek,
    required this.opens,
    required this.closes,
    this.isClosed = false,
  });

  final int dayOfWeek;
  final String opens;
  final String closes;
  final bool isClosed;

  static const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  String get dayName => dayNames[dayOfWeek];

  factory OpeningHours.fromJson(Map<String, dynamic> j) => OpeningHours(
        dayOfWeek: j['day_of_week'] as int,
        opens: j['opens'] as String? ?? '09:00',
        closes: j['closes'] as String? ?? '17:00',
        isClosed: j['is_closed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'day_of_week': dayOfWeek,
        'opens': opens,
        'closes': closes,
        'is_closed': isClosed,
      };

  OpeningHours copyWith({String? opens, String? closes, bool? isClosed}) =>
      OpeningHours(
        dayOfWeek: dayOfWeek,
        opens: opens ?? this.opens,
        closes: closes ?? this.closes,
        isClosed: isClosed ?? this.isClosed,
      );
}

/// What kind of deal an offer is (backend `DealType`).
enum DealType {
  percentOff('percent_off', '% off'),
  amountOff('amount_off', 'Rs off'),
  bogo('bogo', 'Buy 1 Get 1'),
  freeItem('free_item', 'Free item'),
  other('other', 'Other');

  const DealType(this.api, this.label);
  final String api;
  final String label;

  static DealType parse(String? v) =>
      DealType.values.firstWhere((t) => t.api == v, orElse: () => DealType.other);
}

/// Draft / Scheduled / Active / Expired: from the on/off switch and the dates.
enum PromoStatus {
  draft('draft', 'Draft'),
  scheduled('scheduled', 'Scheduled'),
  active('active', 'Active'),
  expired('expired', 'Expired');

  const PromoStatus(this.api, this.label);
  final String api;
  final String label;

  static PromoStatus parse(String? v) =>
      PromoStatus.values.firstWhere((s) => s.api == v, orElse: () => PromoStatus.draft);
}

/// A special offer: the deal itself (SRS FR-10, UC-11).
class Offer {
  const Offer({
    required this.id,
    required this.title,
    required this.dealType,
    required this.dealLabel,
    required this.startDate,
    required this.status,
    this.description = '',
    this.dealValue,
    this.dealText = '',
    this.endDate,
    this.terms = '',
    this.isActive = false,
    this.tone = 'emerald',
    this.views = 0,
    this.redemptions = 0,
  });

  final int id;
  final String title;
  final String description;
  final DealType dealType;

  /// Percent for % off, rupees for Rs off.
  final double? dealValue;

  /// What's free, or the owner's own label.
  final String dealText;

  /// Badge text from the server: "20% OFF", "BUY 1 GET 1".
  final String dealLabel;
  final DateTime startDate;

  /// null: open-ended.
  final DateTime? endDate;
  final String terms;
  final bool isActive;
  final PromoStatus status;
  final String tone;
  final int views;
  final int redemptions;

  /// "Until 20 Oct", "From 3 Oct", "1 – 20 Oct", "Ongoing".
  String get rangeLabel => dateRangeLabel(startDate, endDate);

  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        id: j['id'] as int? ?? 0,
        title: j['title'] as String,
        description: j['description'] as String? ?? '',
        dealType: DealType.parse(j['deal_type'] as String?),
        dealValue: (j['deal_value'] as num?)?.toDouble(),
        dealText: j['deal_text'] as String? ?? '',
        dealLabel: j['deal_label'] as String? ?? 'SPECIAL OFFER',
        startDate: DateTime.parse(j['start_date'] as String),
        endDate: j['end_date'] == null ? null : DateTime.parse(j['end_date'] as String),
        terms: j['terms'] as String? ?? '',
        isActive: j['is_active'] as bool? ?? false,
        status: PromoStatus.parse(j['status'] as String?),
        tone: j['tone'] as String? ?? 'emerald',
        views: j['views'] as int? ?? 0,
        redemptions: j['redemptions'] as int? ?? 0,
      );
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov',
    'Dec'];

String shortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// Human dates for offers and campaigns, relative to today where it helps.
String dateRangeLabel(DateTime start, DateTime? end, {DateTime? today}) {
  final now = today ?? DateTime.now();
  final t = DateTime(now.year, now.month, now.day);
  if (start.isAfter(t)) {
    return end == null ? 'From ${shortDate(start)}' : '${shortDate(start)} – ${shortDate(end)}';
  }
  if (end == null) return 'Ongoing';
  final left = end.difference(t).inDays;
  if (left == 0) return 'Ends today';
  if (left == 1) return 'Ends tomorrow';
  return 'Until ${shortDate(end)}';
}

/// The business's live campaign, behind the "Active promotion" badge on cards.
class CampaignRef {
  const CampaignRef({required this.id, required this.name});
  final int id;
  final String name;

  static CampaignRef? maybe(Object? j) => j is Map<String, dynamic>
      ? CampaignRef(id: j['id'] as int, name: j['name'] as String? ?? '')
      : null;
}

class BusinessDetail extends BusinessCard {
  const BusinessDetail({
    required super.id,
    required super.name,
    required super.tagline,
    required super.tone,
    required super.address,
    required super.priceLevel,
    required super.rating,
    required super.reviewCount,
    required super.saveCount,
    required super.isVerified,
    super.categoryName,
    super.distanceKm,
    super.categorySlug,
    super.priceMin,
    super.priceMax,
    super.isOpenNow,
    super.todayHours,
    super.hasOffer,
    super.isNew,
    super.cover,
    super.categoryLabel,
    super.latitude,
    super.longitude,
    super.activeCampaign,
    required this.description,
    this.photos = const [],
    this.phone,
    this.categoryId,
    this.customCategory,
    required this.viewCount,
    required this.services,
    required this.offers,
    required this.isSaved,
    this.hours = const [],
    this.isOwner = false,
  });

  final String description;

  /// Cover first, then the rest of the gallery.
  final List<Photo> photos;
  final String? phone;
  final int? categoryId;

  /// The owner's description when the category is "Other".
  final String? customCategory;
  final int viewCount;
  final List<Service> services;
  final List<Offer> offers;
  final bool isSaved;
  final List<OpeningHours> hours;

  /// The viewer owns this business (Message becomes "View messages").
  final bool isOwner;

  factory BusinessDetail.fromJson(Map<String, dynamic> j) {
    final card = BusinessCard.fromJson(j);
    return BusinessDetail(
      id: card.id,
      name: card.name,
      tagline: card.tagline,
      tone: card.tone,
      address: card.address,
      priceLevel: card.priceLevel,
      rating: card.rating,
      reviewCount: card.reviewCount,
      saveCount: card.saveCount,
      isVerified: card.isVerified,
      categoryName: card.categoryName,
      distanceKm: card.distanceKm,
      categorySlug: card.categorySlug,
      priceMin: card.priceMin,
      priceMax: card.priceMax,
      isOpenNow: card.isOpenNow,
      todayHours: card.todayHours,
      hasOffer: card.hasOffer,
      isNew: card.isNew,
      cover: card.cover,
      categoryLabel: card.categoryLabel,
      latitude: card.latitude,
      longitude: card.longitude,
      activeCampaign: card.activeCampaign,
      description: j['description'] as String? ?? '',
      photos: (j['photos'] as List?)
              ?.map((e) => Photo.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      phone: j['phone'] as String?,
      categoryId: j['category_id'] as int?,
      customCategory: j['custom_category'] as String?,
      viewCount: j['view_count'] as int? ?? 0,
      services: (j['services'] as List?)
              ?.map((e) => Service.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      offers: (j['offers'] as List?)
              ?.map((e) => Offer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      isSaved: j['is_saved'] as bool? ?? false,
      isOwner: j['is_owner'] as bool? ?? false,
      hours: (j['hours'] as List?)
              ?.map((e) => OpeningHours.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}


/// The last cards the app received (feed, search, map…), by id. A business page
/// shows the tapped card's photo and name immediately while its full profile loads.
class RecentCards {
  RecentCards._();
  static const _max = 300;
  static final _cards = <int, BusinessCard>{};

  static BusinessCard remember(BusinessCard card) {
    _cards.remove(card.id);
    _cards[card.id] = card;
    if (_cards.length > _max) _cards.remove(_cards.keys.first);
    return card;
  }

  static BusinessCard? get(int id) => _cards[id];
}
