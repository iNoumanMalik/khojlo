import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khojlo/core/location/location_service.dart';
import 'package:khojlo/core/maps/geo_repository.dart';
import 'package:khojlo/core/maps/map_service.dart';
import 'package:khojlo/core/maps/map_types.dart';
import 'package:khojlo/core/models/business.dart';
import 'package:khojlo/core/models/review.dart';
import 'package:khojlo/core/models/search.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/features/discovery/discovery_providers.dart';
import 'package:khojlo/features/discovery/presentation/business_detail_screen.dart';
import 'package:khojlo/features/maps/map_providers.dart';
import 'package:khojlo/features/maps/presentation/location_picker_screen.dart';
import 'package:khojlo/features/maps/presentation/map_screen.dart';
import 'package:khojlo/features/reviews/data/reviews_repository.dart';
import 'package:khojlo/features/search/data/search_repository.dart';
import 'package:khojlo/features/search/search_providers.dart';

BusinessCard place(int id, String name, {double? lat, double? lng}) => BusinessCard(
      id: id,
      name: name,
      tagline: '',
      tone: 'gold',
      address: 'F-7 Markaz, Islamabad',
      priceLevel: '\$\$',
      rating: 4.6,
      reviewCount: 10,
      saveCount: 3,
      isVerified: true,
      categoryName: 'Cafés',
      isOpenNow: true,
      latitude: lat,
      longitude: lng,
    );

final brew = place(1, 'Brew & Bloom', lat: 33.7206, lng: 73.0551);
final reading = place(2, 'The Reading Room', lat: 33.7095, lng: 73.0561);
final unpinned = place(3, 'Night Owl Ramen');

class FakeSearch extends SearchRepository {
  FakeSearch() : super(Dio());

  final calls = <({SearchFilters filters, GeoBounds? bounds, int limit})>[];
  List<BusinessCard> items = [brew, reading, unpinned];
  int? total;

  @override
  Future<SearchPage> search(SearchFilters filters,
      {double? lat,
      double? lng,
      int limit = 20,
      int offset = 0,
      bool record = false,
      GeoBounds? bounds}) async {
    calls.add((filters: filters, bounds: bounds, limit: limit));
    return SearchPage(items: items, total: total ?? items.length, summary: '');
  }

  @override
  Future<List<SearchSuggestion>> suggestions(String q) async => const [];
}

class FakeGeo extends GeoRepository {
  FakeGeo({this.available = true}) : super(Dio());
  final bool available;
  int reverseCalls = 0;

  @override
  Future<GeoPlace> reverse(GeoPoint p) async {
    reverseCalls++;
    if (!available) throw const GeoLookupException(GeoLookupFailure.unavailable);
    return GeoPlace(
      address: 'Jinnah Super Market, F-7 Markaz, Islamabad',
      label: 'F-7 Markaz, Islamabad',
      point: p,
    );
  }

  @override
  Future<List<GeoPlace>> search(String query, {GeoPoint? near}) async => const [];
}

/// The business page now shows reviews (Module 5); these tests don't need any.
class NoReviews extends ReviewsRepository {
  NoReviews() : super(Dio());

  @override
  Future<ReviewPage> list(int businessId,
          {ReviewSort sort = ReviewSort.relevant,
          Set<int> stars = const {},
          bool photosOnly = false,
          int limit = 10,
          int offset = 0}) async =>
      const ReviewPage(summary: ReviewSummary.empty, items: [], total: 0);
}

class FixedLocation extends LocationService {
  FixedLocation([this.fix]);
  final LocationFix? fix;

  @override
  Future<LocationResult> locate({bool prompt = false, bool fresh = false}) async =>
      fix == null
          ? const LocationResult(LocationStatus.denied)
          : LocationResult(LocationStatus.available, fix);
}

ProviderContainer container({
  required FakeSearch search,
  LocationFix? fix,
  FakeGeo? geo,
  List<Override> extra = const [],
}) {
  final c = ProviderContainer(overrides: [
    searchRepositoryProvider.overrideWithValue(search),
    locationServiceProvider.overrideWithValue(FixedLocation(fix)),
    geoRepositoryProvider.overrideWithValue(geo ?? FakeGeo()),
    mapServiceProvider.overrideWithValue(const SketchMapService()),
    reviewsRepositoryProvider.overrideWithValue(NoReviews()),
    ...extra,
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> pump(WidgetTester tester, ProviderContainer c, Widget screen,
    {Size size = const Size(1080, 2340)}) async {
  // 360 x 780 logical by default. The test font draws every glyph as a full square, so
  // screens with long labels (the business page's buttons) get a wider surface.
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(theme: AppTheme.light(), home: screen),
  ));
  // The search field's rotating placeholder never lets the tree settle.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 400));
  }
}

/// Waits for the map's debounced load. Polls rather than sleeping a fixed time, so a
/// busy machine running the whole suite can't make the tests flaky.
Future<void> mapLoaded(ProviderContainer c) async {
  for (var i = 0; i < 150; i++) {
    if (c.read(mapResultsProvider).status == MapStatus.ready) return;
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  fail('map results never loaded');
}

void main() {
  group('geometry and BR-7', () {
    test('(0, 0) and out-of-range points are not valid locations', () {
      expect(const GeoPoint(33.72, 73.05).isValid, isTrue);
      expect(const GeoPoint(0, 0).isValid, isFalse);
      expect(const GeoPoint(91, 73).isValid, isFalse);
      expect(const GeoPoint(33, 181).isValid, isFalse);
    });

    test('cards only have a map location with valid coordinates', () {
      Map<String, dynamic> json(Object? lat, Object? lng) => {
            'id': 1,
            'name': 'X',
            'latitude': lat,
            'longitude': lng,
          };
      expect(BusinessCard.fromJson(json(33.72, 73.05)).location, const GeoPoint(33.72, 73.05));
      expect(BusinessCard.fromJson(json(0, 0)).location, isNull);
      expect(BusinessCard.fromJson(json(null, null)).location, isNull);
    });

    test('web-mercator projection round-trips', () {
      const p = GeoPoint(33.7206, 73.0551);
      final px = Mercator.project(p, 14);
      final back = Mercator.unproject(px.x, px.y, 14);
      expect(back.latitude, closeTo(p.latitude, 1e-9));
      expect(back.longitude, closeTo(p.longitude, 1e-9));
    });

    test('camera bounds surround the centre, and zoomToFit inverts them', () {
      const centre = GeoPoint(33.7, 73.05);
      final b = GeoBounds.fromCamera(centre, 14, 360, 400);
      expect(b.contains(centre), isTrue);
      expect(b.center.longitude, closeTo(centre.longitude, 1e-9));
      expect(b.north - centre.latitude, closeTo(centre.latitude - b.south, 1e-3));
      expect(b.zoomToFit(360, 400), closeTo(14, 0.01));
    });

    test('an area around points includes them all, even a single point', () {
      final b = GeoBounds.around(const [GeoPoint(33.70, 73.00), GeoPoint(33.75, 73.10)])!;
      expect(b.contains(const GeoPoint(33.70, 73.00)), isTrue);
      expect(b.contains(const GeoPoint(33.75, 73.10)), isTrue);
      final one = GeoBounds.around(const [GeoPoint(33.7, 73.0)])!;
      expect(one.north, greaterThan(one.south));
      expect(GeoBounds.around(const []), isNull);
    });

    test('directions open Google Maps navigation to the place (UC-9)', () {
      final uri = const SketchMapService().directionsUri(const GeoPoint(33.7206, 73.0551));
      expect(uri.host, 'www.google.com');
      expect(uri.path, '/maps/dir/');
      expect(uri.queryParameters, {'api': '1', 'destination': '33.7206,73.0551'});
    });
  });

  group('map results', () {
    const area = GeoBounds(south: 33.70, west: 73.04, north: 33.735, east: 73.085);

    test('load the visible area with Explore’s filters, keeping only pinned places', () async {
      final search = FakeSearch();
      final c = container(search: search);
      c.read(searchControllerProvider.notifier).browseCategory('cafes');
      await Future<void>.delayed(Duration.zero);

      c.read(mapResultsProvider.notifier).onCameraIdle(area);
      await mapLoaded(c);

      final call = search.calls.last;
      expect(call.bounds, area);
      expect(call.limit, MapResultsNotifier.maxPins);
      expect(call.filters.categories, {'cafes'});
      final state = c.read(mapResultsProvider);
      expect(state.status, MapStatus.ready);
      expect(state.items.map((b) => b.name), ['Brew & Bloom', 'The Reading Room']);
    });

    test('new filters reload the same area; the selection survives if still shown', () async {
      final search = FakeSearch();
      final c = container(search: search);
      final notifier = c.read(mapResultsProvider.notifier);
      notifier.onCameraIdle(area);
      await mapLoaded(c);
      notifier.select(2);

      search.items = [reading];
      await c.read(searchControllerProvider.notifier).submit('quiet');
      await Future<void>.delayed(Duration.zero);
      final mapCall = search.calls.lastWhere((call) => call.bounds != null);
      expect(mapCall.filters.query, 'quiet');
      expect(mapCall.bounds, area);
      expect(c.read(mapResultsProvider).selectedId, 2);

      search.items = [brew];
      await c.read(searchControllerProvider.notifier).submit('pour over');
      await Future<void>.delayed(Duration.zero);
      expect(c.read(mapResultsProvider).selectedId, isNull);
    });

    test('a tiny camera jitter doesn’t refetch', () async {
      final search = FakeSearch();
      final c = container(search: search);
      final notifier = c.read(mapResultsProvider.notifier);
      notifier.onCameraIdle(area);
      await mapLoaded(c);
      notifier.onCameraIdle(const GeoBounds(
          south: 33.70001, west: 73.04001, north: 33.73501, east: 73.08501));
      await Future<void>.delayed(MapResultsNotifier.debounce + const Duration(milliseconds: 50));
      expect(search.calls, hasLength(1));
    });
  });

  group('Map tab', () {
    testWidgets('pins, preview card above the map and nearby carousel', (tester) async {
      final search = FakeSearch()..total = 140;
      final c = container(search: search, fix: const LocationFix(33.7150, 73.0540));
      await pump(tester, c, const MapScreen());

      expect(find.text('Map'), findsNWidgets(2)); // title + list/map toggle
      expect(find.text('Near F-7 Markaz, Islamabad'), findsOneWidget); // location indicator
      expect(search.calls.where((call) => call.bounds != null), isNotEmpty);
      // pins for pinned places, plus the "you are here" dot
      expect(find.byKey(const ValueKey('pin-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('pin-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('pin-3')), findsNothing);
      expect(find.byKey(const ValueKey('pin-me')), findsOneWidget);
      expect(find.text('Showing 2 of 140 · zoom in for more'), findsOneWidget);
      // carousel
      expect(find.text('Brew & Bloom'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('pin-2')));
      await tester.pump(const Duration(milliseconds: 400));
      expect(c.read(mapResultsProvider).selectedId, 2);
      expect(find.byTooltip('Directions'), findsOneWidget); // floating preview card
      expect(find.text('The Reading Room'), findsNWidgets(2)); // preview + carousel
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('location unavailable: says so and falls back to Islamabad (UC-9)',
        (tester) async {
      final c = container(search: FakeSearch());
      await pump(tester, c, const MapScreen());
      expect(find.text('Location off · showing Islamabad'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.my_location_rounded));
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Location permission was denied'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('“View on map” from a business page centres the map on it', (tester) async {
      final search = FakeSearch();
      final c = container(search: search);
      c.read(mapFocusProvider.notifier).state =
          const MapFocus(GeoPoint(33.7206, 73.0551), businessId: 1);
      await pump(tester, c, const MapScreen());
      expect(c.read(mapFocusProvider), isNull); // consumed
      expect(c.read(mapResultsProvider).selectedId, 1);
      final mapCall = search.calls.lastWhere((call) => call.bounds != null);
      expect(mapCall.bounds!.contains(const GeoPoint(33.7206, 73.0551)), isTrue);
      await tester.pump(const Duration(seconds: 1));
    });
  });

  group('business page', () {
    Map<String, dynamic> detail({double? lat, double? lng}) => {
          'id': 7,
          'name': 'Brew & Bloom',
          'address': 'F-7 Markaz, Islamabad',
          'latitude': lat,
          'longitude': lng,
          'services': const [],
          'offers': const [],
          'hours': const [],
          'photos': const [],
        };

    Future<void> open(WidgetTester tester, Map<String, dynamic> json) async {
      final c = container(search: FakeSearch(), extra: [
        businessDetailProvider.overrideWith((ref, id) async => BusinessDetail.fromJson(json)),
      ]);
      await pump(tester, c, const BusinessDetailScreen(id: 7), size: const Size(1440, 2340));
      await tester.scrollUntilVisible(find.text('WHERE', skipOffstage: false), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pump(const Duration(milliseconds: 400));
    }

    testWidgets('shows the location on a map with Directions', (tester) async {
      await open(tester, detail(lat: 33.7206, lng: 73.0551));
      expect(find.byKey(const ValueKey('pin-here'), skipOffstage: false), findsOneWidget);
      expect(find.text('Location unavailable'), findsNothing);
      expect(find.text('Directions'), findsWidgets);
    });

    testWidgets('without a pin says “Location unavailable” (UC-9)', (tester) async {
      await open(tester, detail());
      expect(find.text('Location unavailable', skipOffstage: false), findsOneWidget);
      expect(find.byKey(const ValueKey('pin-here'), skipOffstage: false), findsNothing);
    });
  });

  group('pin picker', () {
    testWidgets('looks up the address at the pin and returns it on confirm', (tester) async {
      final geo = FakeGeo();
      final c = container(search: FakeSearch(), geo: geo);
      PickedLocation? picked;
      await pump(
        tester,
        c,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => picked =
                await showLocationPicker(context, initial: const GeoPoint(33.7206, 73.0551)),
            child: const Text('Pick'),
          ),
        ),
      );
      await tester.tap(find.text('Pick'));
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 400));
      }
      expect(find.text('Pin your business'), findsOneWidget);
      expect(find.text('Jinnah Super Market, F-7 Markaz, Islamabad'), findsOneWidget);

      await tester.tap(find.text('Confirm pin'));
      await tester.pump(const Duration(milliseconds: 600));
      expect(picked!.point.latitude, closeTo(33.7206, 1e-6));
      expect(picked!.address, 'Jinnah Super Market, F-7 Markaz, Islamabad');
    });

    testWidgets('without server geocoding it still works, minus the address search',
        (tester) async {
      final c = container(search: FakeSearch(), geo: FakeGeo(available: false));
      await pump(tester, c, const LocationPickerScreen(initial: GeoPoint(33.7, 73.05)));
      await tester.pump(const Duration(milliseconds: 800));
      expect(find.text('Drag the map to put the pin on your business'), findsOneWidget);
      expect(find.text('Search an address or area'), findsNothing);
      expect(find.text('Confirm pin'), findsOneWidget);
    });
  });
}
