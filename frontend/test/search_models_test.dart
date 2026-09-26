import 'package:flutter_test/flutter_test.dart';
import 'package:khojlo/core/models/business.dart';
import 'package:khojlo/core/models/search.dart';
import 'package:khojlo/features/search/compare_controller.dart';

BusinessCard card(int id, {String tone = 'gold'}) => BusinessCard(
      id: id,
      name: 'Place $id',
      tagline: '',
      tone: tone,
      address: '',
      priceLevel: '\$\$',
      rating: 4.5,
      reviewCount: 10,
      saveCount: 3,
      isVerified: true,
    );

void main() {
  group('rupee formatting', () {
    test('adds thousands separators', () {
      expect(formatRupees(650), 'Rs 650');
      expect(formatRupees(2500), 'Rs 2,500');
      expect(formatRupees(1250000), 'Rs 1,250,000');
    });

    test('describes full, open-ended and missing ranges', () {
      expect(priceRangeLabel(800, 2500), 'Rs 800–2,500');
      expect(priceRangeLabel(800, 800), 'Rs 800');
      expect(priceRangeLabel(800, null), 'From Rs 800');
      expect(priceRangeLabel(null, 2500), 'Up to Rs 2,500');
      expect(priceRangeLabel(null, null), '');
    });
  });

  group('SearchFilters.toQuery', () {
    test('sends only what is set, lists as repeated keys', () {
      const filters = SearchFilters(
        query: '  unstitched fabric ',
        categories: {'shopping', 'beauty'},
        priceLevels: {'\$\$', '\$'},
        maxPrice: 2500,
        openNow: true,
      );
      expect(filters.toQuery(), {
        'q': 'unstitched fabric',
        'category': ['beauty', 'shopping'],
        'price': ['\$', '\$\$'],
        'max_price': 2500,
        'open_now': true,
        'sort': 'relevance',
      });
    });

    test('drops distance options without a location', () {
      const filters = SearchFilters(radiusKm: 2, sort: SearchSort.distance);
      final withoutLocation = filters.toQuery();
      expect(withoutLocation.containsKey('radius_km'), isFalse);
      expect(withoutLocation['sort'], 'relevance');

      final located = filters.toQuery(lat: 33.72, lng: 73.05);
      expect(located['radius_km'], 2);
      expect(located['sort'], 'distance');
      expect(located['lat'], 33.72);
    });
  });

  group('active filter chips', () {
    const filters = SearchFilters(
      categories: {'cafes'},
      priceLevels: {'\$\$'},
      minPrice: 500,
      maxPrice: 2000,
      minRating: 4.5,
      radiusKm: 1,
      openNow: true,
      hasOffer: true,
      verifiedOnly: true,
    );

    test('one chip per active filter, with readable labels', () {
      final labels = filters.chips({'cafes': 'Cafés'}).map((c) => c.label).toList();
      expect(labels, [
        'Cafés', '\$\$', 'Rs 500–2,000', '★ 4.5+', '0–1 km', 'Open now', 'Has offer',
        'Verified',
      ]);
      expect(filters.activeCount, 8);
    });

    test('removing a chip clears just that filter', () {
      final chips = filters.chips();
      final withoutBudget =
          filters.without(chips.firstWhere((c) => c.kind == FilterKind.budget));
      expect(withoutBudget.hasBudget, isFalse);
      expect(withoutBudget.openNow, isTrue);

      final withoutCafes =
          filters.without(chips.firstWhere((c) => c.kind == FilterKind.category));
      expect(withoutCafes.categories, isEmpty);
      expect(withoutCafes.activeCount, 7);
    });

    test('withoutFilters keeps the keyword and sort order', () {
      final cleared =
          filters.copyWith(query: 'coffee', sort: SearchSort.rating).withoutFilters();
      expect(cleared.hasFilters, isFalse);
      expect(cleared.query, 'coffee');
      expect(cleared.sort, SearchSort.rating);
    });
  });

  test('filters compare by value, ignoring set order', () {
    const a = SearchFilters(categories: {'cafes', 'gym'}, openNow: true);
    const b = SearchFilters(categories: {'gym', 'cafes'}, openNow: true);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
    expect(a == a.copyWith(openNow: false), isFalse);
  });

  test('comparison winners are parsed per row', () {
    final result = CompareResult.fromJson({
      'items': [
        {'id': 1, 'name': 'A', 'services': [], 'active_offers': ['10% off']},
        {'id': 2, 'name': 'B', 'services': [], 'active_offers': []},
      ],
      'highlights': {'price': [2], 'rating': [], 'offers': [1]},
    });
    expect(result.items.first.activeOffers, ['10% off']);
    expect(result.isBest(CompareRow.price, 2), isTrue);
    expect(result.isBest(CompareRow.price, 1), isFalse);
    expect(result.isBest(CompareRow.offers, 1), isTrue);
    expect(result.isBest(CompareRow.distance, 1), isFalse);
  });

  group('CompareController', () {
    test('holds at most three places and toggles off on a second tap', () {
      final c = CompareController();
      expect(c.toggle(card(1)), CompareToggle.added);
      expect(c.isReady, isFalse);
      expect(c.toggle(card(2)), CompareToggle.added);
      expect(c.isReady, isTrue);
      expect(c.toggle(card(3)), CompareToggle.added);
      expect(c.toggle(card(4)), CompareToggle.full);
      expect(c.state.map((b) => b.id), [1, 2, 3]);

      expect(c.toggle(card(2)), CompareToggle.removed);
      expect(c.state.map((b) => b.id), [1, 3]);
      c.clear();
      expect(c.state, isEmpty);
    });
  });
}
