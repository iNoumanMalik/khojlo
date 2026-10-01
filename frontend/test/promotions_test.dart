import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:khojlo/core/models/business.dart';
import 'package:khojlo/core/models/campaign.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/core/widgets/widgets.dart';
import 'package:khojlo/features/business/business_providers.dart';
import 'package:khojlo/features/promotions/data/promotions_repository.dart';
import 'package:khojlo/features/promotions/presentation/campaign_editor_screen.dart';
import 'package:khojlo/features/promotions/presentation/campaign_screen.dart';
import 'package:khojlo/features/promotions/presentation/offer_editor_screen.dart';
import 'package:khojlo/features/promotions/presentation/promotions_screen.dart';
import 'package:khojlo/features/promotions/presentation/widgets/promo_widgets.dart';

final _today = DateTime.now();
String _d(int offset) =>
    apiDate(DateTime(_today.year, _today.month, _today.day).add(Duration(days: offset)));

Map<String, dynamic> offerJson(int id, String title,
        {String status = 'active', String label = '25% OFF', bool active = true}) =>
    {
      'id': id,
      'title': title,
      'deal_type': 'percent_off',
      'deal_value': 25,
      'deal_label': label,
      'start_date': _d(-1),
      'end_date': _d(6),
      'terms': 'Dine-in only.',
      'is_active': active,
      'status': status,
    };

Map<String, dynamic> cardJson({bool verified = true, Map<String, dynamic>? campaign}) => {
      'id': 7,
      'name': 'Forno Italiano',
      'tagline': 'Wood-fired pizza',
      'tone': 'gold',
      'is_verified': verified,
      'rating': 4.6,
      'review_count': 12,
      if (campaign != null) 'active_campaign': campaign,
    };

Map<String, dynamic> campaignJson({String status = 'active', bool visible = true}) => {
      'id': 3,
      'name': 'Weekend Food Festival',
      'message': 'Special deals all weekend!',
      'description': 'Enjoy special weekend deals at our restaurant.',
      'start_date': _d(-1),
      'end_date': _d(5),
      'terms': 'Offers can’t be combined.',
      'is_published': status != 'draft',
      'status': status,
      'is_visible': visible,
      'offers': [offerJson(1, 'Family pizza night'), offerJson(2, 'Buy 1 get 1 tiramisu',
          label: 'BUY 1 GET 1')],
      'services': [
        {'id': 5, 'name': 'Tiramisu', 'price': 'Rs 900'}
      ],
      'business': cardJson(),
    };

class FakePromotions extends PromotionsRepository {
  FakePromotions({List<Offer>? offers, List<Campaign>? campaigns, this.failCampaign = false})
      : offerList = offers ?? [Offer.fromJson(offerJson(1, 'Family pizza night'))],
        campaignList = campaigns ?? [Campaign.fromJson(campaignJson())],
        super(Dio());

  List<Offer> offerList;
  List<Campaign> campaignList;
  final bool failCampaign;
  final savedOffers = <OfferDraft>[];
  final savedCampaigns = <CampaignDraft>[];

  @override
  Future<List<Offer>> offers(int businessId) async => offerList;

  @override
  Future<List<Campaign>> campaigns(int businessId) async => campaignList;

  @override
  Future<Offer> saveOffer(int businessId, OfferDraft draft, {int? offerId}) async {
    savedOffers.add(draft);
    return offerList.first;
  }

  @override
  Future<Campaign> saveCampaign(int businessId, CampaignDraft draft, {int? campaignId}) async {
    savedCampaigns.add(draft);
    return campaignList.first;
  }

  @override
  Future<Campaign> campaign(int id) async {
    if (failCampaign) {
      throw DioException(
        requestOptions: RequestOptions(path: '/campaigns/$id'),
        response: Response(
          requestOptions: RequestOptions(path: '/campaigns/$id'),
          statusCode: 404,
          data: {'detail': 'This promotion has ended.'},
        ),
      );
    }
    return campaignList.first;
  }
}

ProviderContainer container(FakePromotions repo, {bool verified = true}) {
  final c = ProviderContainer(overrides: [
    promotionsRepositoryProvider.overrideWithValue(repo),
    ownerBusinessDetailProvider.overrideWith((ref, id) async => BusinessDetail.fromJson({
          ...cardJson(verified: verified),
          'services': [
            {'id': 5, 'name': 'Tiramisu', 'price': 'Rs 900'},
            {'id': 6, 'name': 'Margherita pizza', 'price': 'Rs 1,400'},
          ],
        })),
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> pump(WidgetTester tester, ProviderContainer c, Widget screen) async {
  // Tall and wide: the test font draws every glyph as a full square.
  tester.view.physicalSize = const Size(1440, 4200);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(theme: AppTheme.light(), home: screen),
  ));
  await settle(tester);
}

/// Scrolls [finder] into view first: long forms push buttons below the fold.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pump();
  await tester.tap(finder);
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  group('models and labels', () {
    test('offers parse the deal, dates and status', () {
      final o = Offer.fromJson(offerJson(1, 'Family pizza night'));
      expect(o.dealType, DealType.percentOff);
      expect(o.dealValue, 25);
      expect(o.status, PromoStatus.active);
      expect(o.terms, 'Dine-in only.');
    });

    test('date ranges read naturally', () {
      final today = DateTime(2026, 10, 1);
      expect(dateRangeLabel(DateTime(2026, 9, 1), null, today: today), 'Ongoing');
      expect(dateRangeLabel(DateTime(2026, 9, 1), DateTime(2026, 10, 20), today: today),
          'Until 20 Oct');
      expect(dateRangeLabel(DateTime(2026, 9, 1), DateTime(2026, 10, 1), today: today),
          'Ends today');
      expect(dateRangeLabel(DateTime(2026, 10, 3), DateTime(2026, 10, 9), today: today),
          '3 Oct – 9 Oct');
      expect(dateRangeLabel(DateTime(2026, 10, 3), null, today: today), 'From 3 Oct');
    });

    test('the editor previews the same deal labels the server builds', () {
      expect(previewDealLabel(DealType.percentOff, 20, ''), '20% OFF');
      expect(previewDealLabel(DealType.percentOff, 12.5, ''), '12.5% OFF');
      expect(previewDealLabel(DealType.amountOff, 2000, ''), 'Rs 2,000 OFF');
      expect(previewDealLabel(DealType.bogo, null, ''), 'BUY 1 GET 1');
      expect(previewDealLabel(DealType.freeItem, null, 'coffee'), 'FREE COFFEE');
      expect(previewDealLabel(DealType.other, null, ''), 'SPECIAL OFFER');
    });

    test('feed banners and card badges parse', () {
      final card = BusinessCard.fromJson(cardJson(campaign: {'id': 3, 'name': 'Winter Special'}));
      expect(card.activeCampaign!.name, 'Winter Special');
      final banner = CampaignBanner.fromJson({
        'id': 3, 'name': 'Grand Opening', 'start_date': _d(0), 'end_date': _d(9),
        'business_id': 7, 'business_name': 'Brew & Bloom', 'offer_count': 2,
        'top_deal': '20% OFF',
      });
      expect((banner.offerCount, banner.topDeal), (2, '20% OFF'));
    });
  });

  group('owner', () {
    testWidgets('offers and campaigns are listed separately with their status',
        (tester) async {
      final repo = FakePromotions(offers: [
        Offer.fromJson(offerJson(1, 'Family pizza night')),
        Offer.fromJson(offerJson(2, 'Free coffee', status: 'expired', active: false)),
      ]);
      await pump(tester, container(repo), const PromotionsScreen(businessId: 7));

      expect(find.text('Offers'), findsOneWidget);
      expect(find.text('Create and manage individual deals.'), findsOneWidget);
      expect(find.text('Promotional campaigns'), findsOneWidget);
      expect(find.text('Family pizza night'), findsOneWidget);
      expect(find.text('Weekend Food Festival'), findsOneWidget);
      expect(find.text('ACTIVE'), findsNWidgets(2));
      expect(find.text('EXPIRED'), findsOneWidget);
      expect(find.textContaining('isn’t verified'), findsNothing);
    });

    testWidgets('unverified businesses are told publishing needs verification', (tester) async {
      await pump(tester, container(FakePromotions(), verified: false),
          const PromotionsScreen(businessId: 7));
      expect(find.textContaining('isn’t verified yet'), findsOneWidget);
    });

    testWidgets('offer editor validates, then saves the deal', (tester) async {
      final repo = FakePromotions();
      await pump(tester, container(repo), const OfferEditorScreen(businessId: 7));

      await tester.enterText(find.byKey(const ValueKey('offer-title')), '20% off burgers');
      await tester.tap(find.text('Save offer'));
      await tester.pump();
      expect(find.text('Enter a discount between 1% and 100%.'), findsOneWidget);

      await tester.enterText(find.byKey(const ValueKey('offer-value')), '20');
      await tester.pump();
      expect(find.text('20% OFF'), findsOneWidget); // live preview
      await tester.tap(find.byType(Switch).last); // Active
      await tester.pump();
      await tester.tap(find.text('Save offer'));
      await settle(tester);

      final draft = repo.savedOffers.single;
      expect((draft.title, draft.dealType, draft.dealValue, draft.isActive),
          ('20% off burgers', DealType.percentOff, 20.0, true));
      expect(draft.endDate, isNotNull);
    });

    testWidgets('an unverified business can only save offer drafts', (tester) async {
      final repo = FakePromotions();
      await pump(tester, container(repo, verified: false), const OfferEditorScreen(businessId: 7));
      expect(find.textContaining('once Khojlo verifies your business'), findsOneWidget);
      final active = tester.widget<Switch>(find.byType(Switch).last);
      expect(active.onChanged, isNull);
    });

    testWidgets('campaign editor needs a live offer to publish, then saves the links',
        (tester) async {
      final repo = FakePromotions(offers: [
        Offer.fromJson(offerJson(1, 'Family pizza night')),
        Offer.fromJson(offerJson(2, 'Old deal', status: 'expired', active: false)),
      ]);
      await pump(tester, container(repo), const CampaignEditorScreen(businessId: 7));

      await tester.enterText(find.byKey(const ValueKey('campaign-name')), 'Weekend Food Festival');
      await tester.tap(find.text('Publish'));
      await tester.pump();
      await tapVisible(tester, find.text('Save campaign'));
      await tester.pump();
      expect(find.textContaining('Link at least one active or scheduled offer'), findsOneWidget);

      // Expired offers can't be picked; live ones can.
      final expired = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile).last);
      expect(expired.onChanged, isNull);
      await tester.tap(find.text('Family pizza night'));
      await tapVisible(tester, find.text('Tiramisu'));
      await tester.pump();
      await tapVisible(tester, find.text('Save campaign'));
      await settle(tester);

      final draft = repo.savedCampaigns.single;
      expect((draft.name, draft.isPublished), ('Weekend Food Festival', true));
      expect(draft.offerIds, [1]);
      expect(draft.serviceIds, [5]);
    });
  });

  group('customer', () {
    testWidgets('campaign details: business, live offers, featured and terms', (tester) async {
      await pump(tester, container(FakePromotions()), const CampaignScreen(campaignId: 3));
      expect(find.text('Weekend Food Festival'), findsOneWidget);
      expect(find.text('Forno Italiano'), findsOneWidget);
      expect(find.text('Special deals all weekend!'), findsOneWidget);
      expect(find.text('Family pizza night'), findsOneWidget);
      expect(find.text('BUY 1 GET 1'), findsOneWidget);
      expect(find.text('Tiramisu · Rs 900'), findsOneWidget);
      expect(find.text('Offers can’t be combined.'), findsOneWidget);
      expect(find.text('View Forno Italiano'), findsOneWidget);

      await tester.tap(find.text('Family pizza night'));
      await settle(tester);
      expect(find.text('Dine-in only.'), findsOneWidget); // the offer's own terms
    });

    testWidgets('an ended campaign says so', (tester) async {
      await pump(tester, container(FakePromotions(failCampaign: true)),
          const CampaignScreen(campaignId: 3));
      expect(find.text('This promotion isn’t running'), findsOneWidget);
      expect(find.text('This promotion has ended.'), findsOneWidget);
    });

    testWidgets('home banner and the card badge', (tester) async {
      final banner = CampaignBanner.fromJson({
        'id': 3, 'name': 'Grand Opening', 'message': 'Come say hello!',
        'start_date': _d(-1), 'end_date': _d(9), 'business_id': 7,
        'business_name': 'Brew & Bloom', 'offer_count': 2, 'top_deal': '20% OFF',
      });
      final card = BusinessCard.fromJson(cardJson(campaign: {'id': 3, 'name': 'Grand Opening'}));
      await pump(
        tester,
        container(FakePromotions()),
        Scaffold(
          body: Column(children: [
            SizedBox(height: 200, child: CampaignBannerCard(banner: banner, onTap: () {})),
            BusinessListRow(business: card),
          ]),
        ),
      );
      expect(find.text('Grand Opening'), findsOneWidget);
      expect(find.text('Come say hello!'), findsOneWidget);
      expect(find.text('View offers'), findsOneWidget);
      expect(find.text('20% OFF'), findsOneWidget);
      expect(find.text('Active promotion'), findsOneWidget);
    });
  });
}
