// Module 8 — admin and moderation: the admin panel, the owner's verification
// checklist, reporting a business and blocked conversations.

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khojlo/core/media/media_repository.dart';
import 'package:khojlo/core/media/photo_source.dart';
import 'package:khojlo/core/models/chat.dart';
import 'package:khojlo/core/models/moderation.dart';
import 'package:khojlo/core/models/photo.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/features/admin/data/admin_repository.dart';
import 'package:khojlo/features/admin/presentation/admin_business_screen.dart';
import 'package:khojlo/features/admin/presentation/admin_report_screen.dart';
import 'package:khojlo/features/admin/presentation/admin_screen.dart';
import 'package:khojlo/features/business/data/business_repository.dart';
import 'package:khojlo/features/business/presentation/verification_screen.dart';
import 'package:khojlo/features/chat/presentation/conversation_screen.dart';
import 'package:khojlo/features/discovery/presentation/report_business_sheet.dart';

import 'chat_test.dart' as chat;

final _iso = DateTime.now().toUtc().toIso8601String();

Map<String, dynamic> personJson(int id, String name,
        {String role = 'customer', String status = 'active'}) =>
    {
      'id': id,
      'full_name': name,
      'email': '${name.split(' ').first.toLowerCase()}@khojlo.app',
      'role': role,
      'initials': name[0],
      'tone': 'gold',
      'email_verified': true,
      'status': status,
      'created_at': _iso,
    };

Map<String, dynamic> briefJson(
        {int id = 7, String status = 'pending_review', bool verified = false}) =>
    {
      'id': id,
      'name': 'Brew & Bloom',
      'tone': 'emerald',
      'category_label': 'Cafés',
      'address': 'F-7 Markaz',
      'owner_id': 3,
      'owner_name': 'Sara Owner',
      'verification_status': status,
      'is_verified': verified,
      'is_published': true,
      'is_suspended': false,
      'created_at': _iso,
      'open_reports': 1,
    };

Map<String, dynamic> actionJson(int id, String label, {String? target}) => {
      'id': id,
      'action': 'remove_review',
      'label': label,
      'by': 'Asma Admin',
      'automatic': false,
      'target_type': 'review',
      'target_id': 4,
      'target_title': target,
      'note': '',
      'created_at': _iso,
    };

Map<String, dynamic> reportItemJson() => {
      'kind': 'review',
      'target_id': 4,
      'title': 'Review of Brew & Bloom by Promo D.',
      'snippet': 'Cheap followers at www.fastfollowers.pk',
      'report_count': 2,
      'reasons': {'Spam or advertising': 2},
      'first_at': _iso,
      'latest_at': _iso,
      'open': true,
    };

Map<String, dynamic> reportDetailJson({bool open = true}) => {
      'kind': 'review',
      'target_id': 4,
      'title': 'Review of Brew & Bloom by Promo D.',
      'open': open,
      'reports': [
        {
          'id': 1,
          'reason': 'spam',
          'reason_label': 'Spam or advertising',
          'note': 'An advert',
          'reporter_id': 9,
          'reporter_name': 'Zara Khan',
          'status': open ? 'open' : 'removed',
          'created_at': _iso,
        }
      ],
      'review': {
        'id': 4,
        'rating': 5,
        'comment': 'Cheap followers at www.fastfollowers.pk',
        'created_at': _iso,
        'is_visible': open,
        'author': personJson(5, 'Promo Deals'),
        'business': briefJson(),
      },
      'accounts': [personJson(5, 'Promo Deals')],
      'history': open ? [] : [actionJson(1, 'Removed a review')],
    };

VerificationInfo makeVerification({bool storefront = false, String status = 'unverified'}) =>
    VerificationInfo.fromJson({
      'business_id': 7,
      'status': status,
      'is_verified': status == 'verified',
      'checks': [
        {'key': 'email', 'label': 'Email verified', 'passed': true},
        {'key': 'profile', 'label': 'Listing complete', 'passed': true},
        {
          'key': 'storefront',
          'label': 'Storefront photo taken',
          'passed': storefront,
          'hint': 'Take a photo of your shop front or signboard, with the name showing.'
        },
        {'key': 'record', 'label': 'No open reports', 'passed': true},
      ],
    });

class FakeAdmin extends AdminRepository {
  FakeAdmin() : super(Dio());

  final resolutions = <Resolution>[];
  final decisions = <(String, String)>[];
  bool resolved = false;

  @override
  Future<AdminOverview> overview() async => AdminOverview.fromJson({
        'pending_review': 2,
        'open_reports': 3,
        'open_review_reports': 1,
        'open_conversation_reports': 1,
        'open_business_reports': 1,
        'open_flags': 4,
        'users_total': 16,
        'businesses_total': 31,
        'verified_total': 22,
        'auto_verified_week': 5,
        'daily': [
          for (final d in ['Mon', 'Tue', 'Wed']) {'label': d, 'reports': 1, 'flags': 2}
        ],
        'recent': [actionJson(1, 'Removed a review', target: 'Review of Brew & Bloom')],
      });

  @override
  Future<Paged<ReportItem>> reports(
          {String kind = 'all', String status = 'open', int limit = 50, int offset = 0}) async =>
      Paged(items: resolved ? [] : [ReportItem.fromJson(reportItemJson())], total: 1);

  @override
  Future<ReportDetail> report(ReportKind kind, int targetId) async =>
      ReportDetail.fromJson(reportDetailJson(open: !resolved));

  @override
  Future<ReportDetail> resolveReport(ReportKind kind, int targetId, Resolution r) async {
    resolutions.add(r);
    resolved = true;
    return ReportDetail.fromJson(reportDetailJson(open: false));
  }

  @override
  Future<Paged<AdminBusinessBrief>> businesses(
          {String status = 'all', String q = '', int limit = 30, int offset = 0}) async =>
      Paged(items: [AdminBusinessBrief.fromJson(briefJson())], total: 1);

  @override
  Future<AdminBusinessDetail> business(int id) async => AdminBusinessDetail.fromJson({
        ...briefJson(
            status: decisions.isEmpty ? 'pending_review' : 'verified',
            verified: decisions.isNotEmpty),
        'owner': personJson(3, 'Sara Owner', role: 'business_owner'),
        'checks': makeVerification(storefront: true).checks
            .map((c) => {'key': c.key, 'label': c.label, 'passed': c.passed})
            .toList(),
        'reports': [],
        'flags': [],
        'history': [],
      });

  @override
  Future<AdminBusinessDetail> decide(int id, String decision, {String note = ''}) async {
    decisions.add((decision, note));
    return business(id);
  }

  @override
  Future<Paged<AdminFlag>> flags({String status = 'open', int limit = 50, int offset = 0}) async =>
      const Paged(items: [], total: 0);

  @override
  Future<Paged<AdminAction>> actions({bool? automatic, int limit = 50, int offset = 0}) async =>
      Paged(items: [AdminAction.fromJson(actionJson(1, 'Removed a review'))], total: 1);
}

class FakeBusinesses extends BusinessRepository {
  FakeBusinesses() : super(Dio());
  VerificationInfo info = makeVerification();
  String? storefrontKey;

  @override
  Future<VerificationInfo> verification(int id) async => info;

  @override
  Future<VerificationInfo> setStorefront(int id, String photoKey) async {
    storefrontKey = photoKey;
    return info = makeVerification(storefront: true, status: 'verified');
  }
}

class FakeCamera implements PhotoSource {
  int shots = 0;
  @override
  Future<List<PickedPhoto>> pickMany(int limit) async => const [];
  @override
  Future<PickedPhoto?> pickOne() async => null;
  @override
  Future<PickedPhoto?> takePhoto() async {
    shots++;
    return PickedPhoto(bytes: Uint8List(0), name: 'shop.jpg');
  }
}

class FakeMedia extends MediaRepository {
  FakeMedia() : super(Dio());
  @override
  Future<Photo> upload(Uint8List bytes,
          {required String filename, void Function(double progress)? onProgress}) async =>
      Photo.fromJson({'key': 'a' * 32, 'url': '/m/a', 'thumb_url': '/m/a/thumb', 'width': 4,
          'height': 3});
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> pumpApp(WidgetTester tester, Widget home, List<Override> overrides,
    {Size size = const Size(1440, 2600)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => home),
    GoRoute(
        path: '/admin/report/:kind/:id',
        builder: (_, s) => AdminReportScreen(
            kind: ReportKind.fromApi(s.pathParameters['kind']),
            targetId: int.parse(s.pathParameters['id']!))),
    GoRoute(
        path: '/admin/business/:id',
        builder: (_, s) => AdminBusinessScreen(businessId: int.parse(s.pathParameters['id']!))),
    GoRoute(path: '/admin/user/:id', builder: (_, s) => Text('user ${s.pathParameters['id']}')),
    GoRoute(path: '/guidelines', builder: (_, __) => const Text('guidelines')),
    GoRoute(path: '/edit-business/:id', builder: (_, __) => const Text('edit')),
    GoRoute(path: '/home', builder: (_, __) => const Text('home')),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  ));
  await settle(tester);
}

void main() {
  group('models', () {
    test('a reported conversation parses with its messages and accounts', () {
      final d = ReportDetail.fromJson({
        'kind': 'conversation',
        'target_id': 12,
        'title': 'Promo D. and Glow Studio',
        'open': true,
        'reports': [],
        'conversation': {
          'id': 12,
          'business': briefJson(),
          'customer': personJson(5, 'Promo Deals'),
          'owner': personJson(3, 'Sara Owner', role: 'business_owner'),
          'messages': [
            {'id': 1, 'side': 'customer', 'body': 'Pay the fee', 'created_at': _iso}
          ],
          'closed': false,
        },
        'accounts': [personJson(5, 'Promo Deals'), personJson(3, 'Sara Owner', role: 'business_owner')],
      });
      expect(d.kind, ReportKind.conversation);
      expect(d.conversation!.messages.single.fromBusiness, isFalse);
      expect(d.accounts.last.roleLabel, 'Business owner');
    });

    test('a resolution is sent the way the API expects', () {
      const r = Resolution(
          uphold: true, reason: ModerationReason.scam, accountAction: 'suspend',
          accountUserId: 5, suspendDays: 3);
      expect(r.toJson(), {
        'decision': 'uphold',
        'reason': 'scam',
        'note': '',
        'account_action': 'suspend',
        'account_user_id': 5,
        'suspend_days': 3,
        'hide_reviews': false,
      });
    });

    test('verification counts passed checks and reads statuses', () {
      final v = makeVerification();
      expect(v.passedCount, 3);
      expect(VerificationStatus.fromApi('needs_info'), VerificationStatus.needsInfo);
      expect(AccountStatus.fromApi('banned'), AccountStatus.banned);
    });
  });

  group('admin panel', () {
    testWidgets('overview: what needs you, with counts in the sidebar', (tester) async {
      await pumpApp(tester, const AdminScreen(),
          [adminRepositoryProvider.overrideWithValue(FakeAdmin())]);
      expect(find.text('Khojlo'), findsOneWidget); // wide layout: the sidebar
      expect(find.text('OPEN REPORTS'), findsOneWidget);
      expect(find.text('3'), findsWidgets);
      expect(find.textContaining('22 of 31 businesses are verified'), findsOneWidget);
      expect(find.text('Removed a review'), findsOneWidget);
    });

    testWidgets('phones get tabs instead of the sidebar', (tester) async {
      await pumpApp(tester, const AdminScreen(),
          [adminRepositoryProvider.overrideWithValue(FakeAdmin())],
          size: const Size(420, 900));
      expect(find.text('Admin & moderation'), findsOneWidget);
      expect(find.text('Verification · 2'), findsOneWidget); // counts on the tabs
    });

    testWidgets('a report: read it, remove it and warn the author', (tester) async {
      final admin = FakeAdmin();
      await pumpApp(tester, const AdminScreen(initial: AdminSection.reports),
          [adminRepositoryProvider.overrideWithValue(admin)]);
      expect(find.text('Review of Brew & Bloom by Promo D.'), findsOneWidget);
      expect(find.text('2 reporters'), findsOneWidget);

      await tester.tap(find.text('Review of Brew & Bloom by Promo D.'));
      await settle(tester);
      Finder onReport(Finder f) => find.descendant(of: find.byType(AdminReportScreen), matching: f);
      expect(onReport(find.text('Cheap followers at www.fastfollowers.pk')), findsOneWidget);
      expect(onReport(find.text('“An advert”')), findsOneWidget);

      await tester.tap(find.text('Decide'));
      await settle(tester);
      await tester.tap(find.text('Warn'));
      await tester.pump();
      await tester.tap(find.widgetWithText(GestureDetector, 'Remove review').last);
      await settle(tester);

      final r = admin.resolutions.single;
      expect((r.uphold, r.reason, r.accountAction, r.accountUserId),
          (true, ModerationReason.spam, 'warn', 5));
      expect(find.textContaining('Resolved'), findsOneWidget);
    });

    testWidgets('a referred business can be verified, and rejecting needs a reason',
        (tester) async {
      final admin = FakeAdmin();
      await pumpApp(tester, const AdminBusinessScreen(businessId: 7),
          [adminRepositoryProvider.overrideWithValue(admin)]);
      expect(find.text('Being reviewed'), findsOneWidget);
      expect(find.text('Storefront photo taken'), findsOneWidget);

      await tester.tap(find.text('Reject'));
      await settle(tester);
      final send = find.widgetWithText(GestureDetector, 'Reject').last;
      await tester.tap(send);
      await settle(tester);
      expect(admin.decisions, isEmpty); // no reason, no rejection
      await tester.enterText(find.byType(TextField), 'The sign says a different name.');
      await tester.pump();
      await tester.tap(send);
      await settle(tester);
      expect(admin.decisions.single, ('reject', 'The sign says a different name.'));
    });
  });

  group('owner', () {
    testWidgets('the checklist, and a storefront photo that verifies', (tester) async {
      final repo = FakeBusinesses();
      final camera = FakeCamera();
      await pumpApp(tester, const VerificationScreen(businessId: 7), [
        businessRepositoryProvider.overrideWithValue(repo),
        photoSourceProvider.overrideWithValue(camera),
        mediaRepositoryProvider.overrideWithValue(FakeMedia()),
      ]);
      expect(find.text('Get the Verified badge'), findsOneWidget);
      expect(find.text('THE CHECKS · 3 OF 4 DONE'), findsOneWidget);

      await tester.tap(find.text('Take storefront photo'));
      await settle(tester);
      expect(camera.shots, 1);
      expect(repo.storefrontKey, 'a' * 32);
      expect(find.text('You’re verified! Your listing now shows the badge.'), findsOneWidget);
      expect(find.text('You’re verified'), findsOneWidget);
    });

    testWidgets('reporting a business asks why', (tester) async {
      (BusinessReportReason, String)? result;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            onPressed: () async => result = await showReportBusinessSheet(context, 'Brew & Bloom'),
            child: const Text('open'),
          ),
        ),
        const [],
      );
      await tester.tap(find.text('open'));
      await settle(tester);
      expect(find.text('Report Brew & Bloom'), findsOneWidget);
      await tester.tap(find.text('Not a real business'));
      await tester.pump();
      await tester.tap(find.text('Send report'));
      await settle(tester);
      expect(result, (BusinessReportReason.fake, ''));
    });
  });

  group('chat', () {
    testWidgets('a blocked conversation replaces the composer', (tester) async {
      final blocked = ConversationDetail.fromJson({
        ...chat.summaryJson(),
        'business': chat.businessJson(),
        'blocked_by_me': true,
        'can_send': false,
      });
      final c = chat.makeContainer(chat.FakeChat(detail: blocked), chat.FakeRealtime());
      tester.view.physicalSize = const Size(1440, 2600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp(
            theme: AppTheme.light(), home: const ConversationScreen(conversationId: 1)),
      ));
      await settle(tester);
      expect(find.text('You blocked this conversation.'), findsOneWidget);
      expect(find.text('Unblock'), findsOneWidget);
      expect(find.text(customerStarters.first), findsNothing); // no composer
    });
  });
}
