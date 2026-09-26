import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khojlo/core/media/media_repository.dart';
import 'package:khojlo/core/media/photo_source.dart';
import 'package:khojlo/core/models/business.dart';
import 'package:khojlo/core/models/photo.dart';
import 'package:khojlo/core/network/api_config.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/core/widgets/image_tile.dart';
import 'package:khojlo/features/business/presentation/widgets/business_form_fields.dart';
import 'package:khojlo/features/business/presentation/widgets/photo_manager.dart';

Photo photo(String key, {int w = 1600, int h = 1000}) => Photo(
      key: key,
      url: 'http://test/$key',
      thumbUrl: 'http://test/$key/thumb',
      width: w,
      height: h,
    );

class FakeSource implements PhotoSource {
  FakeSource(this.count);
  final int count;
  int? lastLimit;

  @override
  Future<List<PickedPhoto>> pickMany(int limit) async {
    lastLimit = limit;
    return [
      for (var i = 0; i < count && i < limit; i++)
        PickedPhoto(bytes: Uint8List(0), name: 'p$i.jpg'),
    ];
  }

  @override
  Future<PickedPhoto?> pickOne() async => PickedPhoto(bytes: Uint8List(0), name: 'one.jpg');
}

class FakeMedia extends MediaRepository {
  FakeMedia() : super(Dio());
  var uploads = 0;

  @override
  Future<Photo> upload(Uint8List bytes,
      {required String filename, void Function(double progress)? onProgress}) async {
    uploads++;
    return photo(filename.replaceAll('.jpg', ''));
  }
}

void main() {
  group('Photo', () {
    test('resolves API paths against the backend and anchors crops on the focal point', () {
      final p = Photo.fromJson({
        'key': 'abc',
        'url': '/api/v1/media/abc',
        'thumb_url': '/api/v1/media/abc/thumb',
        'width': 1600,
        'height': 1200,
        'focal_x': 0.75,
        'focal_y': 0.5,
      });
      final origin = Uri.parse(ApiConfig.baseUrl).origin;
      expect(p.url, '$origin/api/v1/media/abc');
      expect(p.thumbUrl, '$origin/api/v1/media/abc/thumb');
      expect(p.aspectRatio, closeTo(1.333, 0.001));
      expect(p.alignment, const Alignment(0.5, 0));
    });

    test('crops centre the focal point as far as the photo edges allow', () {
      const wide = Photo(key: 'w', url: '', thumbUrl: '', width: 1600, height: 1000,
          focalX: 0.6, focalY: 0.5);
      // Square frame shows 62.5% of the width; centring 0.6 starts the window at 28.75%.
      expect(wide.alignmentFor(1).x, closeTo(0.2875 / 0.375 * 2 - 1, 1e-9));
      expect(wide.alignmentFor(1).y, 0);
      // Subject near the right edge: the crop stops at the edge instead of overshooting.
      const edge = Photo(key: 'e', url: '', thumbUrl: '', width: 1600, height: 1000,
          focalX: 0.95, focalY: 0.5);
      expect(edge.alignmentFor(1), const Alignment(1, 0));
      // Same shape as the photo: nothing to crop.
      expect(wide.alignmentFor(1.6), Alignment.center);
      // A banner wider than the photo crops top/bottom instead.
      const tall = Photo(key: 't', url: '', thumbUrl: '', width: 1000, height: 1500,
          focalX: 0.5, focalY: 0.8);
      expect(tall.alignmentFor(2).x, 0);
      expect(tall.alignmentFor(2).y, greaterThan(0.5));
    });

    test('small tiles use the thumbnail, full-width surfaces the large photo', () {
      final landscape = photo('a');
      // 64 px list-row thumbnail at 3x: thumbnail is plenty.
      expect(needsLargeVariant(landscape, BoxConstraints.tight(const Size(64, 64)), 3), isFalse);
      // 150 x 100 carousel card at 2x.
      expect(needsLargeVariant(landscape, BoxConstraints.tight(const Size(150, 100)), 2), isFalse);
      // Full-width hero card at 2x.
      expect(needsLargeVariant(landscape, BoxConstraints.tight(const Size(390, 230)), 2), isTrue);
      // A tall frame crops a landscape photo hard, so even a narrow tile needs more pixels.
      expect(needsLargeVariant(landscape, BoxConstraints.tight(const Size(120, 400)), 2), isTrue);
    });
  });

  group('categories', () {
    const cats = [
      Category(id: 1, slug: 'restaurants', name: 'Restaurants', tone: 'gold', emoji: '🍽️',
          groupName: 'Food & Drink'),
      Category(id: 2, slug: 'cafes', name: 'Cafés', tone: 'emerald', emoji: '☕',
          groupName: 'Food & Drink'),
      Category(id: 3, slug: 'tailors', name: 'Tailors & Fabric', tone: 'emerald',
          emoji: '🧵', groupName: 'Shopping'),
      Category(id: 4, slug: 'other', name: 'Other', tone: 'ink', groupName: 'Other',
          isOther: true),
    ];

    test('group in server order, with emoji labels', () {
      final groups = groupCategories(cats);
      expect(groups.map((g) => g.$1), ['Food & Drink', 'Shopping', 'Other']);
      expect(groups.first.$2.map((c) => c.slug), ['restaurants', 'cafes']);
      expect(cats[2].label, '🧵 Tailors & Fabric');
      expect(cats[3].label, 'Other');
    });

    test('"Other" needs a description; specific categories don\'t', () {
      expect(CategoryPicker.customError(cats[3], ''), isNotNull);
      expect(CategoryPicker.customError(cats[3], 'Calligraphy studio'), isNull);
      expect(CategoryPicker.customError(cats[0], ''), isNull);
    });

    test('cards show the owner\'s own words for "Other"', () {
      const card = BusinessCard(
        id: 1, name: 'Qalam', tagline: '', tone: 'gold', address: '', priceLevel: '\$\$',
        rating: 0, reviewCount: 0, saveCount: 0, isVerified: false,
        categoryName: 'Other', categoryLabel: 'Calligraphy studio',
      );
      expect(card.typeLabel, 'Calligraphy studio');
    });
  });

  test('phone numbers are checked like the backend does', () {
    for (final ok in ['', '0300 1234567', '+92 300 1234567', '(051) 2345678']) {
      expect(PhoneField.validate(ok), isNull, reason: ok);
    }
    for (final bad in ['call me', '123', '+92 300 1234567 8901 2345']) {
      expect(PhoneField.validate(bad), isNotNull, reason: bad);
    }
  });

  testWidgets('photo manager: add photos, first becomes the cover, reorder and remove',
      (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final source = FakeSource(3);
    final media = FakeMedia();
    List<Photo> latest = const [];
    var uploading = false;

    await tester.pumpWidget(ProviderScope(
      overrides: [
        photoSourceProvider.overrideWithValue(source),
        mediaRepositoryProvider.overrideWithValue(media),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: PhotoManager(
              onChanged: (photos, busy) {
                latest = photos;
                uploading = busy;
              },
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Add photos'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(source.lastLimit, maxBusinessPhotos);
    expect(media.uploads, 3);
    expect(latest.map((p) => p.key), ['p0', 'p1', 'p2']);
    expect(uploading, isFalse);
    expect(find.text('Cover'), findsOneWidget);
    expect(find.text('HOW YOUR COVER FITS'), findsOneWidget);
    expect(find.text('3 of 10 photos · tap one to make it the cover or remove it'), findsOneWidget);

    // Make the third photo the cover.
    await tester.tap(find.bySemanticsLabel('Photo 3'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Make this the cover'));
    await tester.pumpAndSettle();
    expect(latest.map((p) => p.key), ['p2', 'p0', 'p1']);

    // Remove the cover: the next photo takes its place.
    await tester.tap(find.bySemanticsLabel(RegExp(r'^Cover photo')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove photo'));
    await tester.pumpAndSettle();
    expect(latest.map((p) => p.key), ['p0', 'p1']);
  });
}
