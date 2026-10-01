import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khojlo/core/maps/map_service.dart';
import 'package:khojlo/core/models/business.dart';
import 'package:khojlo/core/models/chat.dart';
import 'package:khojlo/core/models/review.dart';
import 'package:khojlo/core/realtime/realtime_service.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/features/chat/chat_providers.dart';
import 'package:khojlo/features/chat/data/chat_repository.dart';
import 'package:khojlo/features/chat/presentation/conversation_screen.dart';
import 'package:khojlo/features/chat/presentation/messages_screen.dart';
import 'package:khojlo/features/discovery/discovery_providers.dart';
import 'package:khojlo/features/discovery/presentation/business_detail_screen.dart';
import 'package:khojlo/features/reviews/data/reviews_repository.dart';

final _now = DateTime.now();

Map<String, dynamic> businessJson({List<Map<String, dynamic>> offers = const []}) => {
      'id': 7,
      'name': 'Brew & Bloom',
      'tone': 'emerald',
      'category_label': 'Cafés',
      'is_open_now': true,
      'today_hours': '08:00–23:00',
      'phone': '051 000 1234',
      'offers': offers,
    };

const customerJson = {'id': 2, 'name': 'Ali C.', 'initials': 'AC', 'tone': 'gold'};

Map<String, dynamic> messageJson(int id,
        {String body = 'Hello', bool fromBusiness = false, bool mine = true, String? clientId,
        int minutesAgo = 0}) =>
    {
      'id': id,
      'conversation_id': 1,
      'body': body,
      'from_business': fromBusiness,
      'is_mine': mine,
      'created_at': _now.subtract(Duration(minutes: minutesAgo)).toUtc().toIso8601String(),
      'client_id': clientId,
    };

Map<String, dynamic> summaryJson(
        {int id = 1, String side = 'customer', int unread = 0, Map<String, dynamic>? last}) =>
    {
      'id': id,
      'my_side': side,
      'business': businessJson(),
      'customer': customerJson,
      'last_message': last,
      'last_message_at': last?['created_at'],
      'unread_count': unread,
    };

ConversationDetail detail({String side = 'customer', int? otherRead, int? myRead,
        List<Map<String, dynamic>> offers = const []}) =>
    ConversationDetail.fromJson({
      ...summaryJson(side: side),
      'business': businessJson(offers: offers),
      'other_last_read_id': otherRead,
      'my_last_read_id': myRead,
    });

class FakeRealtime implements Realtime {
  final _events = StreamController<Map<String, dynamic>>.broadcast();
  final _status = StreamController<RealtimeStatus>.broadcast();
  final sent = <Map<String, dynamic>>[];
  @override
  RealtimeStatus status = RealtimeStatus.online;

  void emit(Map<String, dynamic> event) => _events.add(event);

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;
  @override
  Stream<RealtimeStatus> get statusChanges => _status.stream;
  @override
  void start() {}
  @override
  void stop() {}
  @override
  void send(Map<String, dynamic> event) => sent.add(event);
}

class FakeChat extends ChatRepository {
  FakeChat({ConversationDetail? detail, List<ChatMessage>? messages, this.conversations = const []})
      : conversation = detail ?? _defaultDetail,
        history = messages ?? [],
        super(Dio());

  static final _defaultDetail = detail();

  ConversationDetail conversation;
  List<ChatMessage> history;
  List<ConversationSummary> conversations;
  final sends = <({String body, String clientId})>[];
  final opened = <int>[];
  int reads = 0;
  bool failNextSend = false;

  /// When set, sends wait for it (to deliver the socket echo first).
  Completer<void>? holdSends;
  int _nextId = 100;

  @override
  Future<ConversationDetail> open(int businessId) async {
    opened.add(businessId);
    return conversation;
  }

  @override
  Future<List<ConversationSummary>> list() async => conversations;

  @override
  Future<ConversationDetail> get(int conversationId) async => conversation;

  @override
  Future<MessagePage> messages(int conversationId,
          {int? beforeId, int? afterId, int limit = 30}) async =>
      MessagePage(items: afterId == null ? history : const []);

  @override
  Future<ChatMessage> send(int conversationId,
      {required String body, required String clientId, String? photoKey}) async {
    sends.add((body: body, clientId: clientId));
    if (failNextSend) {
      failNextSend = false;
      throw DioException(requestOptions: RequestOptions(path: '/messages'));
    }
    await holdSends?.future;
    return ChatMessage.fromJson(messageJson(_nextId++, body: body, clientId: clientId));
  }

  @override
  Future<int> markRead(int conversationId) async {
    reads++;
    return 0;
  }
}

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

ProviderContainer makeContainer(FakeChat chat, FakeRealtime realtime,
    {List<Override> extra = const []}) {
  final c = ProviderContainer(overrides: [
    chatRepositoryProvider.overrideWithValue(chat),
    realtimeProvider.overrideWithValue(realtime),
    ...extra,
  ]);
  addTearDown(c.dispose);
  return c;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('models', () {
    test('a conversation is titled with the other side', () {
      final asCustomer = ConversationSummary.fromJson(summaryJson());
      final asOwner = ConversationSummary.fromJson(summaryJson(side: 'business'));
      expect(asCustomer.title, 'Brew & Bloom');
      expect(asOwner.title, 'Ali C.');
      expect(asOwner.iAmTheBusiness, isTrue);
    });

    test('photo messages preview as a photo', () {
      final m = ChatMessage.fromJson({
        ...messageJson(1, body: ''),
        'photo': {'key': 'k', 'url': '/m/k', 'thumb_url': '/m/k/thumb', 'width': 4, 'height': 3},
      });
      expect(m.preview, '📷 Photo');
      expect(ChatMessage.fromJson(messageJson(2, body: 'Hi')).preview, 'Hi');
    });

    test('times read naturally', () {
      final now = DateTime(2026, 9, 28, 15, 30); // a Monday
      expect(conversationTime(DateTime(2026, 9, 28, 9, 5), now: now), '09:05');
      expect(conversationTime(DateTime(2026, 9, 27, 20), now: now), 'Yesterday');
      expect(conversationTime(DateTime(2026, 9, 24, 20), now: now), 'Thu');
      expect(conversationTime(DateTime(2026, 9, 2), now: now), '2 Sep');
      expect(dayLabel(DateTime(2026, 9, 28, 1), now: now), 'Today');
      expect(dayLabel(DateTime(2026, 9, 22), now: now), 'Tue 22 Sep');
      expect(dayLabel(DateTime(2025, 12, 1), now: now), 'Mon 1 Dec 2025');
    });
  });

  group('conversation list', () {
    test('live messages move a conversation to the top and update the badge', () async {
      final realtime = FakeRealtime();
      final chat = FakeChat(conversations: [
        ConversationSummary.fromJson(summaryJson(id: 1, last: messageJson(1))),
        ConversationSummary.fromJson(summaryJson(id: 2, last: messageJson(2))),
      ]);
      final c = makeContainer(chat, realtime);
      await c.read(conversationsControllerProvider.notifier).load();
      expect(c.read(unreadMessagesProvider), 0);

      realtime.emit({
        'type': 'message.new',
        'conversation_id': 2,
        'message': messageJson(3, mine: false, fromBusiness: true),
        'conversation': summaryJson(id: 2, unread: 1, last: messageJson(3, mine: false)),
        'unread_total': 1,
      });
      await Future<void>.delayed(Duration.zero);
      expect(c.read(conversationsControllerProvider).items.map((i) => i.id), [2, 1]);
      expect(c.read(unreadMessagesProvider), 1);

      // Read on another of my devices.
      realtime.emit({'type': 'conversation.read', 'conversation_id': 2, 'side': 'customer'});
      await Future<void>.delayed(Duration.zero);
      expect(c.read(unreadMessagesProvider), 0);
    });

    test('signing out clears it', () async {
      final chat = FakeChat(conversations: [
        ConversationSummary.fromJson(summaryJson(unread: 2, last: messageJson(1))),
      ]);
      final c = makeContainer(chat, FakeRealtime());
      await c.read(conversationsControllerProvider.notifier).load();
      expect(c.read(unreadMessagesProvider), 2);
      c.read(conversationsControllerProvider.notifier).reset();
      expect(c.read(conversationsControllerProvider).items, isEmpty);
    });
  });

  group('a conversation', () {
    Future<(ProviderContainer, FakeChat, FakeRealtime)> opened({
      ConversationDetail? d,
      List<ChatMessage>? messages,
    }) async {
      final realtime = FakeRealtime();
      final chat = FakeChat(detail: d, messages: messages);
      final c = makeContainer(chat, realtime);
      final sub = c.listen(conversationControllerProvider(1), (_, __) {});
      addTearDown(sub.close);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      return (c, chat, realtime);
    }

    test('sending shows the message at once, then confirms it', () async {
      final (c, chat, _) = await opened();
      final controller = c.read(conversationControllerProvider(1).notifier);
      final sending = controller.send('  Do you deliver?  ');
      final pending = c.read(conversationControllerProvider(1)).messages.single;
      expect(pending.status, SendStatus.sending);
      expect(pending.body, 'Do you deliver?');
      await sending;
      final sent = c.read(conversationControllerProvider(1)).messages.single;
      expect(sent.status, SendStatus.sent);
      expect(sent.id, greaterThan(0));
      expect(chat.sends.single.clientId, pending.clientId);
      expect(c.read(conversationsControllerProvider).items.single.lastMessage?.body,
          'Do you deliver?');
    });

    test('the socket echo arriving first doesn\'t duplicate the message', () async {
      final (c, chat, realtime) = await opened();
      chat.holdSends = Completer();
      final controller = c.read(conversationControllerProvider(1).notifier);
      final sending = controller.send('Hi there');
      final clientId = chat.sends.single.clientId;
      realtime.emit({
        'type': 'message.new',
        'conversation_id': 1,
        'message': messageJson(100, body: 'Hi there', clientId: clientId),
      });
      await Future<void>.delayed(Duration.zero);
      chat.holdSends!.complete();
      await sending;
      final messages = c.read(conversationControllerProvider(1)).messages;
      expect(messages.map((m) => m.id), [100]);
    });

    test('a failed send can be retried', () async {
      final (c, chat, _) = await opened();
      chat.failNextSend = true;
      final controller = c.read(conversationControllerProvider(1).notifier);
      await controller.send('Hello?');
      final failed = c.read(conversationControllerProvider(1)).messages.single;
      expect(failed.status, SendStatus.failed);
      await controller.retry(failed);
      final retried = c.read(conversationControllerProvider(1)).messages.single;
      expect(retried.status, SendStatus.sent);
      expect(chat.sends.map((s) => s.clientId).toSet(), {failed.clientId}); // same id: no duplicate
    });

    test('messages from the other side arrive live and are marked read', () async {
      final (c, chat, realtime) = await opened();
      realtime.emit({
        'type': 'message.new',
        'conversation_id': 1,
        'message': messageJson(50, body: 'Yes, within 5 km', mine: false, fromBusiness: true),
      });
      await Future<void>.delayed(Duration.zero);
      expect(c.read(conversationControllerProvider(1)).messages.single.body, 'Yes, within 5 km');
      expect(chat.reads, 1);

      realtime.emit({'type': 'message.new', 'conversation_id': 9, 'message': messageJson(51)});
      await Future<void>.delayed(Duration.zero);
      expect(c.read(conversationControllerProvider(1)).messages, hasLength(1)); // other chat
    });

    test('"Seen" follows the other side\'s read receipts', () async {
      final (c, _, realtime) = await opened(messages: [
        ChatMessage.fromJson(messageJson(10, minutesAgo: 5)),
        ChatMessage.fromJson(messageJson(11, minutesAgo: 4)),
      ]);
      expect(c.read(conversationControllerProvider(1)).seenMessageId, isNull);
      realtime.emit({'type': 'conversation.read', 'conversation_id': 1, 'side': 'business',
          'last_read_id': 10});
      await Future<void>.delayed(Duration.zero);
      expect(c.read(conversationControllerProvider(1)).seenMessageId, 10);
    });

    test('typing: shown for the other side, and sent at most every few seconds', () async {
      final (c, _, realtime) = await opened();
      realtime.emit({'type': 'typing', 'conversation_id': 1, 'side': 'business'});
      await Future<void>.delayed(Duration.zero);
      expect(c.read(conversationControllerProvider(1)).otherTyping, isTrue);

      realtime.emit({'type': 'typing', 'conversation_id': 1, 'side': 'customer'}); // my other device
      final controller = c.read(conversationControllerProvider(1).notifier);
      controller
        ..typing()
        ..typing()
        ..typing();
      expect(realtime.sent, [
        {'type': 'typing', 'conversation_id': 1}
      ]);
    });
  });

  group('screens', () {
    Future<void> pumpScreen(WidgetTester tester, ProviderContainer c, Widget screen) async {
      tester.view.physicalSize = const Size(1440, 2600);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(tester.view.reset);
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => screen),
        GoRoute(path: '/conversations/:id', builder: (_, s) => Text('conversation ${s.pathParameters['id']}')),
        GoRoute(path: '/business/:id', builder: (_, s) => Text('business ${s.pathParameters['id']}')),
        GoRoute(path: '/chat', builder: (_, __) => const Text('chat tab')),
        GoRoute(path: '/kai', builder: (_, __) => const Text('kai')),
      ]);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: c,
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ));
      await settle(tester);
    }

    testWidgets('the Chat tab lists conversations with unread counts', (tester) async {
      final chat = FakeChat(conversations: [
        ConversationSummary.fromJson(summaryJson(
            id: 1, unread: 2, last: messageJson(1, body: 'Terrace, please', mine: false))),
      ]);
      final c = makeContainer(chat, FakeRealtime());
      await pumpScreen(tester, c, const MessagesScreen());
      expect(find.text('Brew & Bloom'), findsOneWidget);
      expect(find.text('Terrace, please'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      await tester.tap(find.text('Brew & Bloom'));
      await settle(tester);
      expect(find.text('conversation 1'), findsOneWidget);
    });

    testWidgets('the Chat tab explains how to start a conversation', (tester) async {
      final c = makeContainer(FakeChat(), FakeRealtime());
      await pumpScreen(tester, c, const MessagesScreen());
      expect(find.text('No conversations yet'), findsOneWidget);
    });

    testWidgets('conversation: send from the composer, suggestions and offers', (tester) async {
      final chat = FakeChat(detail: detail(offers: [
        {
          'id': 3,
          'title': '20% off first visit',
          'deal_type': 'percent_off',
          'deal_value': 20,
          'deal_label': '20% OFF',
          'start_date': '2026-09-01',
          'is_active': true,
          'status': 'active',
        }
      ]));
      final c = makeContainer(chat, FakeRealtime());
      await pumpScreen(tester, c, const ConversationScreen(conversationId: 1));

      expect(find.text('Brew & Bloom'), findsOneWidget);
      expect(find.text('Open now · 08:00–23:00'), findsOneWidget);
      expect(find.text(customerStarters.first), findsOneWidget); // first-message suggestions
      expect(find.text('20% off first visit'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Do you deliver to G-9?');
      await tester.pump(); // the send button enables once there's text
      await tester.tap(find.byIcon(Icons.arrow_upward_rounded));
      await settle(tester);
      expect(find.text('Do you deliver to G-9?'), findsOneWidget);
      expect(chat.sends.single.body, 'Do you deliver to G-9?');

      await tester.tap(find.text('20% off first visit'));
      await settle(tester);
      expect(chat.sends.last.body, 'Is the “20% off first visit” offer still on?');
    });

    testWidgets('conversation: the owner sees the customer and quick replies', (tester) async {
      final chat = FakeChat(
        detail: detail(side: 'business', otherRead: 20),
        messages: [
          ChatMessage.fromJson(messageJson(19, body: 'Hi!', mine: false, minutesAgo: 3)),
          ChatMessage.fromJson(
              messageJson(20, body: 'Hello Ali', mine: true, fromBusiness: true, minutesAgo: 2)),
        ],
      );
      final c = makeContainer(chat, FakeRealtime());
      await pumpScreen(tester, c, const ConversationScreen(conversationId: 1));
      expect(find.text('Ali C.'), findsOneWidget);
      expect(find.text('about Brew & Bloom'), findsOneWidget);
      expect(find.text(ownerReplies.first), findsOneWidget);
      expect(find.textContaining('Seen'), findsOneWidget);
      expect(find.text('TODAY'), findsOneWidget);
    });

    Future<void> businessPage(WidgetTester tester, FakeChat chat, {required bool owner}) async {
      final json = {
        'id': 7,
        'name': 'Brew & Bloom',
        'is_owner': owner,
        'services': const [],
        'offers': const [],
        'hours': const [],
        'photos': const [],
      };
      final c = makeContainer(chat, FakeRealtime(), extra: [
        businessDetailProvider.overrideWith((ref, id) async => BusinessDetail.fromJson(json)),
        reviewsRepositoryProvider.overrideWithValue(NoReviews()),
        mapServiceProvider.overrideWithValue(const SketchMapService()),
      ]);
      await pumpScreen(tester, c, const BusinessDetailScreen(id: 7));
    }

    testWidgets('business page: Message opens the conversation', (tester) async {
      final chat = FakeChat();
      await businessPage(tester, chat, owner: false);
      await tester.tap(find.text('Message Brew & Bloom'));
      await settle(tester);
      expect(chat.opened, [7]);
      expect(find.text('conversation 1'), findsOneWidget);
    });

    testWidgets('business page: owners are sent to their Chat tab', (tester) async {
      final chat = FakeChat();
      await businessPage(tester, chat, owner: true);
      await tester.tap(find.text('View customer messages'));
      await settle(tester);
      expect(chat.opened, isEmpty);
      expect(find.text('chat tab'), findsOneWidget);
    });
  });
}
