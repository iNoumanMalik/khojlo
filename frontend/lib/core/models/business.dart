/// Domain models mirroring the backend Pydantic schemas.

class Category {
  const Category({
    required this.id,
    required this.slug,
    required this.name,
    required this.tone,
  });

  final int id;
  final String slug;
  final String name;
  final String tone;

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as int,
        slug: j['slug'] as String,
        name: j['name'] as String,
        tone: j['tone'] as String? ?? 'gold',
      );
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

  String get distanceLabel =>
      distanceKm == null ? '' : '${distanceKm!.toStringAsFixed(1)} km';

  factory BusinessCard.fromJson(Map<String, dynamic> j) => BusinessCard(
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
      );
}

class Service {
  const Service({required this.id, required this.name, required this.price});
  final int id;
  final String name;
  final String price;

  factory Service.fromJson(Map<String, dynamic> j) => Service(
        id: j['id'] as int? ?? 0,
        name: j['name'] as String,
        price: j['price'] as String? ?? '',
      );
}

class Offer {
  const Offer({
    required this.id,
    required this.title,
    required this.startsOn,
    required this.endsOn,
    required this.status,
    required this.tone,
    required this.views,
    required this.redemptions,
  });

  final int id;
  final String title;
  final String startsOn;
  final String endsOn;
  final String status;
  final String tone;
  final int views;
  final int redemptions;

  String get rangeLabel =>
      [startsOn, endsOn].where((s) => s.isNotEmpty).join(' – ');

  factory Offer.fromJson(Map<String, dynamic> j) => Offer(
        id: j['id'] as int? ?? 0,
        title: j['title'] as String,
        startsOn: j['starts_on'] as String? ?? '',
        endsOn: j['ends_on'] as String? ?? '',
        status: j['status'] as String? ?? 'Active',
        tone: j['tone'] as String? ?? 'emerald',
        views: j['views'] as int? ?? 0,
        redemptions: j['redemptions'] as int? ?? 0,
      );
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
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.images,
    required this.viewCount,
    required this.services,
    required this.offers,
    required this.isSaved,
  });

  final String description;
  final double? latitude;
  final double? longitude;
  final List<String> images;
  final int viewCount;
  final List<Service> services;
  final List<Offer> offers;
  final bool isSaved;

  factory BusinessDetail.fromJson(Map<String, dynamic> j) => BusinessDetail(
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
        description: j['description'] as String? ?? '',
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        images: (j['images'] as List?)?.cast<String>() ?? const [],
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
      );
}
