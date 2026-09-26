import 'business.dart';

/// Result orders offered by `GET /search` (`sort` parameter).
enum SearchSort {
  relevance('relevance', 'Best match'),
  distance('distance', 'Nearest'),
  rating('rating', 'Top rated'),
  priceLow('price_low', 'Price: low to high'),
  priceHigh('price_high', 'Price: high to low'),
  newest('newest', 'Newest'),
  popular('popular', 'Most saved');

  const SearchSort(this.api, this.label);
  final String api;
  final String label;
}

/// Bounds of the budget slider (PKR). The top stop means "no upper limit".
class BudgetRange {
  BudgetRange._();
  static const int max = 10000;
  static const int step = 250;
}

enum FilterKind { category, price, budget, rating, distance, openNow, offer, verified }

/// One removable chip shown above the results ("Open now ×", "\$\$ ×").
class ActiveFilter {
  const ActiveFilter(this.kind, this.label, [this.value]);
  final FilterKind kind;
  final String label;

  /// The category slug or price tier this chip removes.
  final String? value;
}

/// Everything the user asked for, sent to `GET /search` via [toQuery].
class SearchFilters {
  const SearchFilters({
    this.query = '',
    this.categories = const {},
    this.priceLevels = const {},
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.openNow = false,
    this.hasOffer = false,
    this.verifiedOnly = false,
    this.radiusKm,
    this.sort = SearchSort.relevance,
  });

  final String query;
  final Set<String> categories;
  final Set<String> priceLevels;
  final int? minPrice;
  final int? maxPrice;
  final double? minRating;
  final bool openNow;
  final bool hasOffer;
  final bool verifiedOnly;
  final double? radiusKm;
  final SearchSort sort;

  bool get hasQuery => query.trim().isNotEmpty;
  bool get hasBudget => minPrice != null || maxPrice != null;

  /// Number of active filters (the keyword and sort order aren't filters).
  int get activeCount =>
      categories.length +
      priceLevels.length +
      (hasBudget ? 1 : 0) +
      (minRating != null ? 1 : 0) +
      (radiusKm != null ? 1 : 0) +
      (openNow ? 1 : 0) +
      (hasOffer ? 1 : 0) +
      (verifiedOnly ? 1 : 0);

  bool get hasFilters => activeCount > 0;

  SearchFilters copyWith({
    String? query,
    Set<String>? categories,
    Set<String>? priceLevels,
    int? Function()? minPrice,
    int? Function()? maxPrice,
    double? Function()? minRating,
    bool? openNow,
    bool? hasOffer,
    bool? verifiedOnly,
    double? Function()? radiusKm,
    SearchSort? sort,
  }) =>
      SearchFilters(
        query: query ?? this.query,
        categories: categories ?? this.categories,
        priceLevels: priceLevels ?? this.priceLevels,
        minPrice: minPrice != null ? minPrice() : this.minPrice,
        maxPrice: maxPrice != null ? maxPrice() : this.maxPrice,
        minRating: minRating != null ? minRating() : this.minRating,
        openNow: openNow ?? this.openNow,
        hasOffer: hasOffer ?? this.hasOffer,
        verifiedOnly: verifiedOnly ?? this.verifiedOnly,
        radiusKm: radiusKm != null ? radiusKm() : this.radiusKm,
        sort: sort ?? this.sort,
      );

  /// Same keyword and order, no filters.
  SearchFilters withoutFilters() => SearchFilters(query: query, sort: sort);

  /// Query parameters for `GET /search`. Location-only options are dropped when the
  /// device location isn't known, so a request never fails for lack of it.
  Map<String, dynamic> toQuery({double? lat, double? lng}) {
    final located = lat != null && lng != null;
    final effectiveSort =
        sort == SearchSort.distance && !located ? SearchSort.relevance : sort;
    return {
      if (hasQuery) 'q': query.trim(),
      if (categories.isNotEmpty) 'category': categories.toList()..sort(),
      if (priceLevels.isNotEmpty) 'price': priceLevels.toList()..sort(),
      if (minPrice != null) 'min_price': minPrice,
      if (maxPrice != null) 'max_price': maxPrice,
      if (minRating != null) 'min_rating': minRating,
      if (openNow) 'open_now': true,
      if (hasOffer) 'has_offer': true,
      if (verifiedOnly) 'verified_only': true,
      if (located) 'lat': lat,
      if (located) 'lng': lng,
      if (located && radiusKm != null) 'radius_km': radiusKm,
      'sort': effectiveSort.api,
    };
  }

  /// Chips for the active filters. [categoryNames] maps slugs to display names.
  List<ActiveFilter> chips([Map<String, String> categoryNames = const {}]) => [
        for (final slug in categories)
          ActiveFilter(FilterKind.category, categoryNames[slug] ?? slug, slug),
        for (final tier in (priceLevels.toList()..sort()))
          ActiveFilter(FilterKind.price, tier, tier),
        if (hasBudget) ActiveFilter(FilterKind.budget, budgetLabel(minPrice, maxPrice)),
        if (minRating != null)
          ActiveFilter(FilterKind.rating, '★ ${minRating!.toStringAsFixed(1)}+'),
        if (radiusKm != null)
          ActiveFilter(FilterKind.distance, '0–${_km(radiusKm!)} km'),
        if (openNow) const ActiveFilter(FilterKind.openNow, 'Open now'),
        if (hasOffer) const ActiveFilter(FilterKind.offer, 'Has offer'),
        if (verifiedOnly) const ActiveFilter(FilterKind.verified, 'Verified'),
      ];

  /// These filters with one chip removed.
  SearchFilters without(ActiveFilter chip) => switch (chip.kind) {
        FilterKind.category =>
          copyWith(categories: {...categories}..remove(chip.value)),
        FilterKind.price =>
          copyWith(priceLevels: {...priceLevels}..remove(chip.value)),
        FilterKind.budget => copyWith(minPrice: () => null, maxPrice: () => null),
        FilterKind.rating => copyWith(minRating: () => null),
        FilterKind.distance => copyWith(radiusKm: () => null),
        FilterKind.openNow => copyWith(openNow: false),
        FilterKind.offer => copyWith(hasOffer: false),
        FilterKind.verified => copyWith(verifiedOnly: false),
      };

  static String budgetLabel(int? min, int? max) {
    if (min != null && max != null) return priceRangeLabel(min, max);
    if (min != null) return '${formatRupees(min)}+';
    if (max != null) return 'Up to ${formatRupees(max)}';
    return 'Any budget';
  }

  static String _km(double km) =>
      km == km.roundToDouble() ? km.toStringAsFixed(0) : km.toStringAsFixed(1);

  @override
  bool operator ==(Object other) =>
      other is SearchFilters &&
      other.query == query &&
      _sameSet(other.categories, categories) &&
      _sameSet(other.priceLevels, priceLevels) &&
      other.minPrice == minPrice &&
      other.maxPrice == maxPrice &&
      other.minRating == minRating &&
      other.openNow == openNow &&
      other.hasOffer == hasOffer &&
      other.verifiedOnly == verifiedOnly &&
      other.radiusKm == radiusKm &&
      other.sort == sort;

  @override
  int get hashCode => Object.hash(
        query,
        Object.hashAllUnordered(categories),
        Object.hashAllUnordered(priceLevels),
        minPrice,
        maxPrice,
        minRating,
        openNow,
        hasOffer,
        verifiedOnly,
        radiusKm,
        sort,
      );

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

/// One page of `GET /search`.
class SearchPage {
  const SearchPage({
    required this.items,
    required this.total,
    required this.summary,
    this.relaxed = false,
  });

  final List<BusinessCard> items;
  final int total;
  final String summary;

  /// True when no place matched every word, so places matching any word are shown.
  final bool relaxed;

  factory SearchPage.fromJson(Map<String, dynamic> j) => SearchPage(
        items: (j['items'] as List)
            .map((e) => BusinessCard.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: j['total'] as int? ?? 0,
        summary: j['summary'] as String? ?? '',
        relaxed: j['relaxed'] as bool? ?? false,
      );
}

enum SuggestionType { business, category, service }

class SearchSuggestion {
  const SearchSuggestion({
    required this.type,
    required this.label,
    this.sublabel,
    this.businessId,
    this.categorySlug,
  });

  final SuggestionType type;
  final String label;
  final String? sublabel;
  final int? businessId;
  final String? categorySlug;

  factory SearchSuggestion.fromJson(Map<String, dynamic> j) => SearchSuggestion(
        type: SuggestionType.values.firstWhere(
          (t) => t.name == j['type'],
          orElse: () => SuggestionType.service,
        ),
        label: j['label'] as String,
        sublabel: j['sublabel'] as String?,
        businessId: j['business_id'] as int?,
        categorySlug: j['category_slug'] as String?,
      );
}

/// One column of the comparison.
class CompareItem {
  const CompareItem({
    required this.card,
    required this.services,
    required this.activeOffers,
  });

  final BusinessCard card;
  final List<Service> services;
  final List<String> activeOffers;

  factory CompareItem.fromJson(Map<String, dynamic> j) => CompareItem(
        card: BusinessCard.fromJson(j),
        services: (j['services'] as List? ?? const [])
            .map((e) => Service.fromJson(e as Map<String, dynamic>))
            .toList(),
        activeOffers: (j['active_offers'] as List? ?? const []).cast<String>(),
      );
}

/// Comparison rows the backend can declare a winner for.
enum CompareRow { price, rating, distance, openNow, services, offers, saves }

class CompareResult {
  const CompareResult({required this.items, required this.winners});

  final List<CompareItem> items;

  /// Business ids that hold the best value on each row (empty when all tie).
  final Map<CompareRow, Set<int>> winners;

  bool isBest(CompareRow row, int businessId) =>
      winners[row]?.contains(businessId) ?? false;

  static const _keys = {
    CompareRow.price: 'price',
    CompareRow.rating: 'rating',
    CompareRow.distance: 'distance',
    CompareRow.openNow: 'open_now',
    CompareRow.services: 'services',
    CompareRow.offers: 'offers',
    CompareRow.saves: 'saves',
  };

  factory CompareResult.fromJson(Map<String, dynamic> j) {
    final highlights = j['highlights'] as Map<String, dynamic>? ?? const {};
    return CompareResult(
      items: (j['items'] as List)
          .map((e) => CompareItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      winners: {
        for (final entry in _keys.entries)
          entry.key: {...((highlights[entry.value] as List?) ?? const []).cast<int>()},
      },
    );
  }
}
