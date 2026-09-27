import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khojlo/core/location/location_service.dart';
import 'package:khojlo/core/maps/map_types.dart';
import 'package:khojlo/core/models/business.dart';
import 'package:khojlo/core/models/search.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/features/business/business_providers.dart';
import 'package:khojlo/features/search/compare_controller.dart';
import 'package:khojlo/features/search/data/search_repository.dart';
import 'package:khojlo/features/search/presentation/compare_screen.dart';
import 'package:khojlo/features/search/presentation/search_screen.dart';

BusinessCard place(int id, String name,
        {double rating = 4.5,
        int? min,
        int? max,
        bool? open,
        String tier = '\$\$',
        double? km}) =>
    BusinessCard(
      id: id,
      name: name,
      tagline: '',
      tone: 'emerald',
      address: 'Islamabad',
      priceLevel: tier,
      rating: rating,
      reviewCount: 20,
      saveCount: 5,
      isVerified: true,
      categoryName: 'Cafés',
      priceMin: min,
      priceMax: max,
      isOpenNow: open,
      todayHours: open == null ? null : '08:00–23:00',
      distanceKm: km,
    );

final brew = place(1, 'Brew & Bloom', rating: 4.8, min: 450, max: 1500, open: true, km: 0.2);
final reading = place(2, 'The Reading Room', rating: 4.7, min: 350, max: 1100, open: false);

class FakeSearchRepository extends SearchRepository {
  FakeSearchRepository() : super(Dio());

  final searches = <SearchFilters>[];

  @override
  Future<SearchPage> search(SearchFilters filters,
      {double? lat,
      double? lng,
      int limit = 20,
      int offset = 0,
      bool record = false,
      GeoBounds? bounds}) async {
    searches.add(filters);
    return SearchPage(
      items: [brew, reading],
      total: 2,
      summary: '2 places · mostly \$\$ · 1 open now · avg ★ 4.8',
    );
  }

  @override
  Future<List<SearchSuggestion>> suggestions(String q) async => const [
        SearchSuggestion(type: SuggestionType.business, label: 'Coffee Lab', businessId: 9),
      ];

  @override
  Future<List<String>> popular() async => const ['coffee', 'pizza'];

  @override
  Future<List<String>> history() async => const ['quiet cafés'];

  @override
  Future<void> clearHistory() async {}

  @override
  Future<CompareResult> compare(List<int> ids, {double? lat, double? lng}) async =>
      CompareResult(
        items: [
          CompareItem(
            card: brew,
            services: const [Service(id: 1, name: 'Pour over', price: 'Rs 650')],
            activeOffers: const ['Free seedling'],
          ),
          CompareItem(card: reading, services: const [], activeOffers: const []),
        ],
        winners: const {
          CompareRow.price: {2},
          CompareRow.rating: {1},
          CompareRow.openNow: {1},
          CompareRow.services: {1},
          CompareRow.offers: {1},
        },
      );
}

class DeniedLocation extends LocationService {
  @override
  Future<LocationResult> locate({bool prompt = false, bool fresh = false}) async =>
      const LocationResult(LocationStatus.denied);
}

ProviderContainer makeContainer(FakeSearchRepository repo) => ProviderContainer(overrides: [
      searchRepositoryProvider.overrideWithValue(repo),
      locationServiceProvider.overrideWithValue(DeniedLocation()),
      categoriesProvider.overrideWith((ref) async => const [
            Category(id: 1, slug: 'cafes', name: 'Cafés', tone: 'emerald', businessCount: 4),
            Category(id: 2, slug: 'shopping', name: 'Shopping', tone: 'plum', businessCount: 3),
          ]),
    ]);

/// The selection circle on a result row (matched on the widget, not the semantics tree).
final addToCompare = find.byWidgetPredicate(
    (w) => w is Semantics && w.properties.label == 'Add to compare');

Future<void> pumpScreen(WidgetTester tester, ProviderContainer container, Widget screen) async {
  tester.view.physicalSize = const Size(1080, 2340); // 360 x 780 logical
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light(), home: screen),
  ));
  // explicit pumps: the search field's rotating placeholder never lets the tree "settle"
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

void main() {
  testWidgets('Explore: idle view, live search, results and compare selection',
      (tester) async {
    final repo = FakeSearchRepository();
    final container = makeContainer(repo);
    addTearDown(container.dispose);
    await pumpScreen(tester, container, const SearchScreen());

    // idle
    expect(find.text('Explore'), findsOneWidget);
    expect(find.text('RECENT'), findsOneWidget);
    expect(find.text('quiet cafés'), findsOneWidget);
    expect(find.text('POPULAR NOW'), findsOneWidget);
    expect(find.text('coffee'), findsOneWidget);
    expect(find.text('BROWSE BY CATEGORY'), findsOneWidget);
    expect(find.text('Use location'), findsOneWidget); // location not granted yet

    // typing runs a debounced live search and shows suggestions
    await tester.enterText(find.byType(TextField), 'coffee');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 600));
    expect(repo.searches.last.query, 'coffee');
    expect(find.text('Coffee Lab'), findsOneWidget);
    expect(find.text('2 places match'), findsOneWidget);
    expect(find.textContaining('mostly \$\$'), findsOneWidget);
    expect(find.text('Brew & Bloom'), findsOneWidget);

    // pick both for comparison → sticky bar
    await tester.tap(addToCompare.first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Pick 1 more to compare'), findsOneWidget);
    await tester.tap(addToCompare.first);
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Compare 2 businesses'), findsOneWidget);
    expect(container.read(compareSelectionProvider).map((b) => b.id), [1, 2]);
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Explore: category browsing shows a removable filter chip', (tester) async {
    final repo = FakeSearchRepository();
    final container = makeContainer(repo);
    addTearDown(container.dispose);
    await pumpScreen(tester, container, const SearchScreen());

    await tester.ensureVisible(find.text('Shopping'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Shopping'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(repo.searches.last.categories, {'shopping'});
    expect(find.text('2 places match'), findsOneWidget);

    await tester.tap(find.text('Shopping')); // the active chip removes the filter
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('BROWSE BY CATEGORY'), findsOneWidget); // back to idle
    await tester.pump(const Duration(seconds: 1));
  });

  testWidgets('Compare: VS cards, attribute rows and best-in-row highlights', (tester) async {
    final repo = FakeSearchRepository();
    final container = makeContainer(repo);
    addTearDown(container.dispose);
    container.read(compareSelectionProvider.notifier)
      ..toggle(brew)
      ..toggle(reading);

    await pumpScreen(tester, container, const CompareScreen());
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('2 of 3 places'), findsOneWidget);
    expect(find.text('Brew & Bloom'), findsOneWidget);
    expect(find.text('The Reading Room'), findsOneWidget);
    expect(find.text('VS'), findsNWidgets(2)); // between the cards, and before "Add a place"
    expect(find.text('Add a place'), findsOneWidget);
    for (final row in ['PRICE', 'RATING', 'DISTANCE', 'OPEN NOW', 'SERVICES', 'OFFERS']) {
      expect(find.text(row), findsOneWidget);
    }
    expect(find.text('Rs 350–1,100'), findsOneWidget);
    expect(find.text('★ 4.8'), findsOneWidget);
    // five winners → five check marks
    expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(5));

    // removing one drops back to "pick one more"
    await tester.tap(find.byIcon(Icons.close_rounded).first);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Pick one more place'), findsOneWidget);
    await tester.pump(const Duration(seconds: 1));
  });
}
