import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khojlo/core/location/location_service.dart';
import 'package:khojlo/core/models/business.dart';
import 'package:khojlo/core/models/search.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/core/widgets/widgets.dart';
import 'package:khojlo/features/business/business_providers.dart';
import 'package:khojlo/features/search/compare_controller.dart';
import 'package:khojlo/features/search/presentation/filter_sheet.dart';
import 'package:khojlo/features/search/presentation/widgets/compare_bar.dart';
import 'package:khojlo/features/search/presentation/widgets/search_result_row.dart';
import 'package:khojlo/features/search/search_providers.dart';

const zilli = BusinessCard(
  id: 7,
  name: 'Zilli Tailors',
  tagline: 'Unstitched fabric',
  tone: 'emerald',
  address: 'Jinnah Road',
  priceLevel: '\$',
  rating: 4.7,
  reviewCount: 58,
  saveCount: 31,
  isVerified: true,
  distanceKm: 0.4,
  priceMin: 800,
  priceMax: 2500,
  isOpenNow: true,
  isNew: true,
  hasOffer: true,
);

/// A location service that never touches the platform plugin.
class FakeLocationService extends LocationService {
  @override
  Future<LocationResult> locate({bool prompt = false, bool fresh = false}) async =>
      const LocationResult(LocationStatus.denied);
}

Widget harness(Widget child, {List<Override> overrides = const []}) => ProviderScope(
      overrides: [
        locationServiceProvider.overrideWithValue(FakeLocationService()),
        ...overrides,
      ],
      child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: child)),
    );

void main() {
  testWidgets('result row shows distance, rupee range, rating, open status and badges',
      (tester) async {
    var toggled = 0;
    await tester.pumpWidget(harness(SearchResultRow(
      business: zilli,
      selected: false,
      onTap: () {},
      onToggleCompare: () => toggled++,
    )));
    await tester.pumpAndSettle();

    expect(find.text('Zilli Tailors'), findsOneWidget);
    // units are glued to their values with non-breaking spaces
    expect(find.textContaining('0.4 km · Rs 800–2,500 · ★ 4.7'), findsOneWidget);
    expect(find.textContaining('open'), findsOneWidget);
    for (final badge in ['New', 'Offer', 'Verified']) {
      expect(find.text(badge), findsOneWidget);
    }
    await tester.tap(find.bySemanticsLabel('Add to compare'));
    expect(toggled, 1);
  });

  testWidgets('compare bar waits for a second place before enabling', (tester) async {
    final container = ProviderContainer(overrides: [
      locationServiceProvider.overrideWithValue(FakeLocationService()),
    ]);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(body: Align(alignment: Alignment.bottomCenter, child: CompareBar())),
      ),
    ));

    final notifier = container.read(compareSelectionProvider.notifier);
    notifier.toggle(zilli);
    await tester.pumpAndSettle();
    expect(find.text('Pick 1 more to compare'), findsOneWidget);

    notifier.toggle(const BusinessCard(
      id: 8,
      name: 'Heritage Textiles',
      tagline: '',
      tone: 'gold',
      address: '',
      priceLevel: '\$\$',
      rating: 4.4,
      reviewCount: 33,
      saveCount: 11,
      isVerified: true,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Compare 2 businesses'), findsOneWidget);
  });

  testWidgets('filter sheet shows the live result count and applies the draft',
      (tester) async {
    // phone-sized viewport (360 x 800 logical pixels)
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    SearchFilters? applied;
    await tester.pumpWidget(harness(
      Builder(
        builder: (context) => Center(
          child: ElevatedButton(
            onPressed: () async =>
                applied = await showFilterSheet(context, const SearchFilters()),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [
        categoriesProvider.overrideWith((ref) async => const [
              Category(id: 1, slug: 'cafes', name: 'Cafés', tone: 'emerald'),
              Category(id: 2, slug: 'shopping', name: 'Shopping', tone: 'plum'),
            ]),
        filterPreviewCountProvider.overrideWith((ref, filters) async =>
            filters.openNow ? 3 : 12),
      ],
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Show 12 results'), findsOneWidget);
    // Without a location the distance filter asks for it instead of showing a slider.
    expect(find.text('Use location'), findsOneWidget);

    await tester.ensureVisible(find.text('Shopping'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shopping'));
    // toggles, in order: Open now, Has an offer, Verified only
    final openNow = find.byType(KhojloToggle).first;
    await tester.ensureVisible(openNow);
    await tester.pumpAndSettle();
    await tester.tap(openNow);
    await tester.pumpAndSettle();
    expect(find.text('Show 3 results'), findsOneWidget);

    await tester.tap(find.text('Show 3 results'));
    await tester.pumpAndSettle();
    expect(applied?.categories, {'shopping'});
    expect(applied?.openNow, isTrue);
  });
}
