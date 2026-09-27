import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khojlo/core/models/business.dart';
import 'package:khojlo/core/models/review.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/features/reviews/data/reviews_repository.dart';
import 'package:khojlo/features/reviews/presentation/business_reviews_section.dart';
import 'package:khojlo/features/reviews/presentation/my_reviews_screen.dart';
import 'package:khojlo/features/reviews/presentation/reviews_screen.dart';
import 'package:khojlo/features/reviews/reviews_providers.dart';

final _now = DateTime.now();

Review review(int id, {int rating = 5, String comment = 'Lovely place', bool verified = false,
        String name = 'Hassan R.', bool mine = false, int helpful = 0, String? reply}) =>
    Review(
      id: id,
      businessId: 7,
      rating: rating,
      comment: comment,
      author: ReviewAuthor(id: id, name: name, initials: name[0], tone: 'gold', isVerified: verified),
      createdAt: _now.subtract(Duration(days: id)),
      helpfulCount: helpful,
      isMine: mine,
      ownerReply: reply == null ? null : OwnerReply(text: reply, createdAt: _now),
    );

const summary = ReviewSummary(
  average: 4.5,
  count: 4,
  distribution: {5: 2, 4: 2, 3: 0, 2: 0, 1: 0},
  withPhotos: 1,
);

class FakeReviews extends ReviewsRepository {
  FakeReviews({this.canReview = true, this.isOwner = false, this.myReview, List<Review>? items,
      this.pageSummary = summary})
      : items = items ??
            [
              review(1, verified: true, name: 'Ayesha K.', comment: 'Best chai in F-7'),
              review(2, rating: 4, name: 'Bilal R.', comment: 'Good, a bit slow', helpful: 3),
            ],
        super(Dio());

  final bool canReview;
  final bool isOwner;
  Review? myReview;
  List<Review> items;
  ReviewSummary pageSummary;

  final listCalls = <({ReviewSort sort, Set<int> stars, bool photos})>[];
  final created = <({int rating, String comment})>[];
  final reports = <(int, ReportReason)>[];
  final replies = <(int, String)>[];
  bool failHelpful = false;

  @override
  Future<ReviewPage> list(int businessId,
      {ReviewSort sort = ReviewSort.relevant,
      Set<int> stars = const {},
      bool photosOnly = false,
      int limit = 10,
      int offset = 0}) async {
    listCalls.add((sort: sort, stars: stars, photos: photosOnly));
    final shown = stars.isEmpty ? items : items.where((r) => stars.contains(r.rating)).toList();
    return ReviewPage(
      summary: pageSummary,
      items: shown.skip(offset).take(limit).toList(),
      total: shown.length,
      mine: myReview,
      canReview: canReview && myReview == null,
      isOwner: isOwner,
    );
  }

  @override
  Future<Review> create(int businessId,
      {required int rating, String comment = '', List<String> photos = const []}) async {
    created.add((rating: rating, comment: comment));
    myReview = review(99, rating: rating, comment: comment, mine: true, name: 'Ali C.');
    return myReview!;
  }

  @override
  Future<(int, bool)> setHelpful(int reviewId, bool helpful) async {
    if (failHelpful) throw DioException(requestOptions: RequestOptions(path: '/helpful'));
    return (helpful ? 4 : 3, helpful);
  }

  @override
  Future<void> report(int reviewId, ReportReason reason, {String note = ''}) async =>
      reports.add((reviewId, reason));

  @override
  Future<Review> reply(int reviewId, String text) async {
    replies.add((reviewId, text));
    final updated = items
        .firstWhere((r) => r.id == reviewId)
        .copyWith(ownerReply: () => OwnerReply(text: text, createdAt: _now));
    items = [for (final r in items) r.id == reviewId ? updated : r];
    return updated;
  }

  @override
  Future<List<MyReview>> mine() async => [
        if (myReview != null)
          MyReview(review: myReview!, businessName: 'Brew & Bloom', tone: 'emerald'),
      ];
}

ProviderContainer container(FakeReviews repo) {
  final c = ProviderContainer(overrides: [reviewsRepositoryProvider.overrideWithValue(repo)]);
  addTearDown(c.dispose);
  return c;
}

Future<void> pump(WidgetTester tester, ProviderContainer c, Widget screen) async {
  // Wide surface: the test font draws every glyph as a full square.
  tester.view.physicalSize = const Size(1440, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(theme: AppTheme.light(), home: screen),
  ));
  await settle(tester);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('models', () {
    test('a review page parses, including the 1–5★ distribution', () {
      final page = ReviewPage.fromJson({
        'summary': {
          'average': 4.33,
          'count': 3,
          'distribution': {'1': 0, '2': 0, '3': 0, '4': 2, '5': 1},
          'with_photos': 1,
          'unreplied': 2,
        },
        'items': [
          {
            'id': 1,
            'business_id': 7,
            'rating': 4,
            'comment': 'Nice',
            'photos': [],
            'author': {'id': 3, 'name': 'Ayesha K.', 'initials': 'AK', 'tone': 'plum',
                'is_verified': true},
            'created_at': '2026-09-20T10:00:00Z',
            'updated_at': '2026-09-21T10:00:00Z',
            'helpful_count': 2,
            'owner_reply': {'text': 'Thanks!', 'created_at': '2026-09-22T10:00:00Z'},
          }
        ],
        'total': 1,
        'mine': null,
        'can_review': true,
        'is_owner': false,
      });
      expect(page.summary.countFor(4), 2);
      expect(page.summary.shareOf(5), closeTo(1 / 3, 1e-9));
      expect(page.summary.unreplied, 2);
      final r = page.items.single;
      expect(r.author.isVerified, isTrue);
      expect(r.isEdited, isTrue);
      expect(r.ownerReply!.text, 'Thanks!');
      expect(page.canReview, isTrue);
    });

    test('ages read naturally', () {
      final now = DateTime(2026, 9, 27, 12);
      expect(reviewAge(now.subtract(const Duration(minutes: 5)), now: now), '5 min ago');
      expect(reviewAge(now.subtract(const Duration(days: 1)), now: now), 'yesterday');
      expect(reviewAge(now.subtract(const Duration(days: 15)), now: now), '2 weeks ago');
      expect(reviewAge(now.subtract(const Duration(days: 70)), now: now), '2 months ago');
      expect(reviewAge(DateTime(2024, 3, 1), now: now), 'Mar 2024');
    });

    test('cards say "No reviews" instead of a fake 0.0', () {
      BusinessCard card(double rating, int count) => BusinessCard(
            id: 1, name: 'X', tagline: '', tone: 'gold', address: '', priceLevel: r'$$',
            rating: rating, reviewCount: count, saveCount: 0, isVerified: false);
      expect(card(0, 0).ratingLabel, 'No reviews');
      expect(card(4.25, 8).ratingLabel, '★ 4.3');
    });
  });

  group('reviews controller', () {
    test('filters and sort reload the list; the summary stays whole', () async {
      final repo = FakeReviews();
      final c = container(repo);
      final sub = c.listen(reviewsControllerProvider(7), (_, __) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      final ctrl = c.read(reviewsControllerProvider(7).notifier);

      ctrl.toggleStars(4);
      await Future<void>.delayed(Duration.zero);
      expect(repo.listCalls.last.stars, {4});
      expect(c.read(reviewsControllerProvider(7)).items.map((r) => r.rating), [4]);
      expect(c.read(reviewsControllerProvider(7)).summary.count, 4);

      ctrl.setSort(ReviewSort.helpful);
      await Future<void>.delayed(Duration.zero);
      expect(repo.listCalls.last.sort, ReviewSort.helpful);
      ctrl.clearFilters();
      await Future<void>.delayed(Duration.zero);
      expect(repo.listCalls.last.stars, isEmpty);
    });

    test('helpful is optimistic and rolls back when the server refuses', () async {
      final repo = FakeReviews()..failHelpful = true;
      final c = container(repo);
      final sub = c.listen(reviewsControllerProvider(7), (_, __) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      final ctrl = c.read(reviewsControllerProvider(7).notifier);
      final target = c.read(reviewsControllerProvider(7)).items[1];

      final error = await ctrl.toggleHelpful(target);
      expect(error, isNotNull);
      final after = c.read(reviewsControllerProvider(7)).items[1];
      expect((after.helpfulCount, after.votedHelpful), (3, false));

      repo.failHelpful = false;
      expect(await ctrl.toggleHelpful(after), isNull);
      final voted = c.read(reviewsControllerProvider(7)).items[1];
      expect((voted.helpfulCount, voted.votedHelpful), (4, true));
    });

    test('an owner reply updates the review and tells other views', () async {
      final repo = FakeReviews(isOwner: true);
      final c = container(repo);
      final sub = c.listen(reviewsControllerProvider(7), (_, __) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      final before = c.read(reviewChangesProvider);
      final r = c.read(reviewsControllerProvider(7)).items.first;

      expect(await c.read(reviewsControllerProvider(7).notifier).reply(r, 'Thank you!'), isNull);
      expect(repo.replies.single, (1, 'Thank you!'));
      expect(c.read(reviewChangesProvider), before + 1);
    });
  });

  group('screens', () {
    testWidgets('reviews screen: score, verified first, helpful and report', (tester) async {
      final repo = FakeReviews();
      await pump(tester, container(repo),
          const ReviewsScreen(businessId: 7, businessName: 'Brew & Bloom'));

      expect(find.text('4.5'), findsOneWidget); // animated score circle
      expect(find.text('4 reviews'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);
      expect(find.text('Best chai in F-7'), findsOneWidget);
      expect(find.text('Write a review'), findsOneWidget);
      expect(find.text('With photos (1)'), findsOneWidget);

      await tester.tap(find.text('Helpful').first);
      await settle(tester);
      expect(find.text('Helpful (4)'), findsOneWidget);

      await tester.tap(find.byTooltip('More').last);
      await settle(tester);
      await tester.tap(find.text('Report review'));
      await settle(tester);
      await tester.tap(find.text('Fake — not a real visit'));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await settle(tester);
      expect(repo.reports.single, (2, ReportReason.fake));
      expect(find.text('Thanks — Khojlo’s team will take a look.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('writing a review: validation, then it posts and celebrates', (tester) async {
      final repo = FakeReviews();
      await pump(tester, container(repo),
          const ReviewsScreen(businessId: 7, businessName: 'Brew & Bloom'));

      await tester.tap(find.text('Write a review'));
      await settle(tester);
      expect(find.text('Rate your visit'), findsOneWidget);

      await tester.tap(find.text('Post review'));
      await tester.pump();
      expect(find.text('Pick a star rating first.'), findsOneWidget); // UC-7 "invalid review"

      await tester.tap(find.byKey(const ValueKey('star-4')));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Good'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '  Great pour over  ');
      await tester.tap(find.text('Post review'));
      await settle(tester);

      expect(repo.created.single, (rating: 4, comment: 'Great pour over'));
      expect(find.text('Thanks! Your review of Brew & Bloom is live.'), findsOneWidget);
      expect(find.text('YOUR REVIEW'), findsOneWidget); // reloaded with it pinned first
      expect(find.text('Write a review'), findsNothing);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('owners see a reply prompt instead of "Write a review"', (tester) async {
      final repo = FakeReviews(isOwner: true, canReview: false,
          pageSummary: const ReviewSummary(average: 4.5, count: 4, distribution: {5: 2, 4: 2},
              unreplied: 2));
      await pump(tester, container(repo),
          const ReviewsScreen(businessId: 7, businessName: 'Brew & Bloom'));
      expect(find.textContaining('2 reviews waiting for your reply'), findsOneWidget);
      expect(find.text('Write a review'), findsNothing);
      expect(find.text('Reply'), findsNWidgets(2));

      await tester.tap(find.text('Reply').first);
      await settle(tester);
      await tester.enterText(find.byType(TextField), 'Thanks for visiting!');
      await tester.tap(find.text('Post reply'));
      await settle(tester);
      expect(repo.replies.single, (1, 'Thanks for visiting!'));
      expect(find.text('Thanks for visiting!'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('business page section: summary, top reviews and the CTA', (tester) async {
      final repo = FakeReviews();
      await pump(
        tester,
        container(repo),
        const Scaffold(
            body: SingleChildScrollView(
                child: BusinessReviewsSection(businessId: 7, businessName: 'Brew & Bloom'))),
      );
      expect(find.text('REVIEWS'), findsOneWidget);
      expect(find.text('See all 4 →'), findsOneWidget);
      expect(find.text('Best chai in F-7'), findsOneWidget);
      expect(find.text('Write a review'), findsOneWidget);
    });

    testWidgets('business page section without reviews invites the first one', (tester) async {
      final repo = FakeReviews(items: [], pageSummary: ReviewSummary.empty);
      await pump(
        tester,
        container(repo),
        const Scaffold(
            body: SingleChildScrollView(
                child: BusinessReviewsSection(businessId: 7, businessName: 'Brew & Bloom'))),
      );
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.textContaining('Be the first'), findsOneWidget);
      expect(find.textContaining('See all'), findsNothing);
    });

    testWidgets('my reviews lists your reviews', (tester) async {
      final repo = FakeReviews(items: [])
        ..myReview = review(5, mine: true, comment: 'My favourite café', name: 'Ali C.');
      await pump(tester, container(repo), const MyReviewsScreen());
      expect(find.text('Brew & Bloom'), findsOneWidget);
      expect(find.text('My favourite café'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('my reviews explains how to write your first one', (tester) async {
      await pump(tester, container(FakeReviews(items: [])), const MyReviewsScreen());
      expect(find.text('No reviews yet'), findsOneWidget);
      expect(find.text('Explore places'), findsOneWidget);
    });
  });
}
