import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khojlo/core/models/notification.dart';
import 'package:khojlo/core/push/push_platform.dart';
import 'package:khojlo/core/router/app_router.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/core/ui/messenger.dart';
import 'package:khojlo/core/widgets/widgets.dart';
import 'package:khojlo/features/notifications/data/notifications_repository.dart';
import 'package:khojlo/features/notifications/notifications_providers.dart';
import 'package:khojlo/features/notifications/presentation/notification_settings_screen.dart';
import 'package:khojlo/features/notifications/presentation/notifications_screen.dart';
import 'package:khojlo/features/notifications/presentation/push_prompt_card.dart';
import 'package:khojlo/features/notifications/push_controller.dart';

final _now = DateTime.now();

AppNotification note(int id, {required String title, bool read = false, int daysAgo = 0,
        NotificationKind kind = NotificationKind.offer, String route = '/business/7'}) =>
    AppNotification(
      id: id,
      kind: kind,
      title: title,
      body: '',
      route: route,
      isRead: read,
      createdAt: _now.subtract(Duration(days: daysAgo)),
    );

class FakeNotifications extends NotificationsRepository {
  FakeNotifications({List<AppNotification>? items}) : items = items ?? [], super(Dio());

  List<AppNotification> items;
  NotificationPrefs prefs = const NotificationPrefs();
  final markedRead = <List<int>?>[];
  final registered = <(String, String)>[];
  final unregistered = <String>[];

  int get _unread => items.where((n) => !n.isRead).length;

  @override
  Future<NotificationPage> list({int limit = 50, int offset = 0}) async =>
      NotificationPage(items: items, total: items.length, unread: _unread);

  @override
  Future<int> unreadCount() async => _unread;

  @override
  Future<int> markRead({List<int>? ids}) async {
    markedRead.add(ids);
    items = [for (final n in items) ids == null || ids.contains(n.id) ? n.read() : n];
    return _unread;
  }

  @override
  Future<NotificationPrefs> preferences() async => prefs;

  @override
  Future<NotificationPrefs> savePreferences(NotificationPrefs p) async => prefs = p;

  @override
  Future<void> registerDevice(String token, String platform) async =>
      registered.add((token, platform));

  @override
  Future<void> unregisterDevice(String token) async => unregistered.add(token);
}

class FakePushPlatform implements PushPlatform {
  FakePushPlatform({this.current = PushPermission.notDetermined, this.answer = PushPermission.granted});

  PushPermission current;
  PushPermission answer;
  String? launch;
  bool deleted = false;
  final opened = StreamController<String>.broadcast();
  final incoming = StreamController<ForegroundPush>.broadcast();
  final refreshes = StreamController<String>.broadcast();

  @override
  bool get available => true;
  @override
  String get platform => 'android';
  @override
  Future<PushPermission> permission() async => current;
  @override
  Future<PushPermission> requestPermission() async => current = answer;
  @override
  Future<String?> token() async => current == PushPermission.granted ? 'device-token-1' : null;
  @override
  Future<void> deleteToken() async => deleted = true;
  @override
  Stream<String> get tokenRefreshes => refreshes.stream;
  @override
  Stream<String> get openedRoutes => opened.stream;
  @override
  Future<String?> launchRoute() async => launch;
  @override
  Stream<ForegroundPush> get foreground => incoming.stream;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Stand-in screens (with a Scaffold, like every real screen, so banners can show).
Widget page(String label) => Scaffold(body: Center(child: Text(label)));

GoRouter testRouter(Widget home) => GoRouter(routes: [
      GoRoute(path: '/', builder: (_, __) => home),
      GoRoute(path: '/business/:id', builder: (_, s) => page('business ${s.pathParameters['id']}')),
      GoRoute(
          path: '/conversations/:id',
          builder: (_, s) => page('conversation ${s.pathParameters['id']}')),
      GoRoute(path: '/notification-settings', builder: (_, __) => page('settings')),
    ]);

Future<ProviderContainer> pumpApp(WidgetTester tester, Widget home,
    {required FakeNotifications repo, PushPlatform push = const NoPushPlatform()}) async {
  tester.view.physicalSize = const Size(1440, 2600);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
  final router = testRouter(home);
  final c = ProviderContainer(overrides: [
    notificationsRepositoryProvider.overrideWithValue(repo),
    pushPlatformProvider.overrideWithValue(push),
    routerProvider.overrideWithValue(router),
  ]);
  addTearDown(c.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp.router(
        theme: AppTheme.light(), routerConfig: router, scaffoldMessengerKey: rootMessengerKey),
  ));
  await settle(tester);
  return c;
}

void main() {
  group('Notifications screen', () {
    testWidgets('groups today and earlier, and opens a notification', (tester) async {
      final repo = FakeNotifications(items: [
        note(3, title: 'New offer at Forno Italiano'),
        note(2, title: 'Trending in Cafés', read: true, daysAgo: 2,
            kind: NotificationKind.trending),
      ]);
      final c = await pumpApp(tester, const NotificationsScreen(), repo: repo);
      expect(find.text('TODAY'), findsOneWidget);
      expect(find.text('EARLIER'), findsOneWidget);
      expect(c.read(unreadNotificationsProvider), 1);

      await tester.tap(find.text('New offer at Forno Italiano'));
      await settle(tester);
      expect(repo.markedRead.single, [3]);
      expect(c.read(unreadNotificationsProvider), 0);
      expect(find.text('business 7'), findsOneWidget);
    });

    testWidgets('mark all read', (tester) async {
      final repo = FakeNotifications(items: [
        note(1, title: 'One'),
        note(2, title: 'Two'),
      ]);
      final c = await pumpApp(tester, const NotificationsScreen(), repo: repo);
      await tester.tap(find.text('Mark all read'));
      await settle(tester);
      expect(repo.markedRead.single, isNull);
      expect(c.read(unreadNotificationsProvider), 0);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets('an empty list says so', (tester) async {
      await pumpApp(tester, const NotificationsScreen(), repo: FakeNotifications());
      expect(find.text('You’re all caught up'), findsOneWidget);
    });
  });

  testWidgets('settings save each switch as it changes', (tester) async {
    final repo = FakeNotifications();
    await pumpApp(tester, const NotificationSettingsScreen(), repo: repo);
    expect(find.text('Trending'), findsOneWidget);
    await tester.tap(find.byType(KhojloToggle).at(2)); // Offers from saved places
    await settle(tester);
    expect(repo.prefs.offers, isFalse);
    expect(repo.prefs.messages, isTrue);
  });

  group('push notifications', () {
    testWidgets('the prompt appears until notifications are on', (tester) async {
      final repo = FakeNotifications();
      final push = FakePushPlatform();
      final c = await pumpApp(tester, const Scaffold(body: PushPromptCard()), repo: repo,
          push: push);
      expect(find.text('Turn on notifications'), findsOneWidget);
      await tester.tap(find.text('Turn on'));
      await settle(tester);
      expect(c.read(pushControllerProvider), PushPermission.granted);
      expect(repo.registered, [('device-token-1', 'android')]);
      expect(find.text('Turn on notifications'), findsNothing);
    });

    testWidgets('no prompt when push isn\'t available', (tester) async {
      await pumpApp(tester, const Scaffold(body: PushPromptCard()), repo: FakeNotifications());
      expect(find.text('Turn on notifications'), findsNothing);
    });

    testWidgets('blocked notifications explain how to allow them', (tester) async {
      await pumpApp(tester, const Scaffold(body: PushPromptCard()),
          repo: FakeNotifications(), push: FakePushPlatform(current: PushPermission.denied));
      expect(find.text('Notifications are blocked'), findsOneWidget);
      expect(find.text('Turn on'), findsNothing);
    });

    testWidgets('signed in: registers, opens tapped notifications, shows a banner, '
        'and unregisters on sign-out', (tester) async {
      final repo = FakeNotifications(items: [note(1, title: 'x')]);
      final push = FakePushPlatform(current: PushPermission.granted);
      final c = await pumpApp(tester, const Scaffold(body: Text('home')), repo: repo, push: push);
      final controller = c.read(pushControllerProvider.notifier);
      await controller.onSignedIn();
      expect(repo.registered, [('device-token-1', 'android')]);

      push.opened.add('/conversations/12');
      await settle(tester);
      expect(find.text('conversation 12'), findsOneWidget);

      push.incoming.add(const ForegroundPush(
          title: 'New 5★ review for Brew & Bloom', body: 'Ali R.: Great', route: '/business/7'));
      await settle(tester);
      expect(find.text('New 5★ review for Brew & Bloom'), findsOneWidget);
      await tester.tap(find.text('Open'));
      await settle(tester);
      expect(find.text('business 7'), findsOneWidget);

      await controller.unregister();
      expect(repo.unregistered, ['device-token-1']);
      expect(push.deleted, isTrue);
    });

    testWidgets('a notification that launched the app opens its screen', (tester) async {
      final push = FakePushPlatform(current: PushPermission.granted)..launch = '/business/9';
      final c = await pumpApp(tester, const Scaffold(body: Text('home')),
          repo: FakeNotifications(), push: push);
      await c.read(pushControllerProvider.notifier).onSignedIn();
      await settle(tester);
      expect(find.text('business 9'), findsOneWidget);
    });

    test('asks once after the first message, only if never asked before', () async {
      final push = FakePushPlatform();
      final c = ProviderContainer(overrides: [
        notificationsRepositoryProvider.overrideWithValue(FakeNotifications()),
        pushPlatformProvider.overrideWithValue(push),
      ]);
      addTearDown(c.dispose);
      final controller = c.read(pushControllerProvider.notifier);
      await Future<void>.delayed(Duration.zero); // reads the current permission
      push.answer = PushPermission.denied;
      await controller.maybeAskAfterFirstMessage();
      expect(c.read(pushControllerProvider), PushPermission.denied);
      push.answer = PushPermission.granted;
      await controller.maybeAskAfterFirstMessage();
      expect(c.read(pushControllerProvider), PushPermission.denied); // not asked again
    });
  });
}
