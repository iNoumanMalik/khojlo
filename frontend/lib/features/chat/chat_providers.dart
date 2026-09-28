import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/media/media_repository.dart';
import '../../core/media/photo_source.dart';
import '../../core/models/chat.dart';
import '../../core/network/api_client.dart';
import '../../core/realtime/realtime_service.dart';
import '../notifications/push_controller.dart';
import 'data/chat_repository.dart';

enum ChatLoad { idle, loading, ready, error }

// ─────────────── the conversation list (Chat tab) ───────────────
class ConversationsState {
  const ConversationsState({this.items = const [], this.status = ChatLoad.idle, this.error});
  final List<ConversationSummary> items;
  final ChatLoad status;
  final String? error;

  /// Unread messages across conversations: the Chat tab badge.
  int get unread => items.fold(0, (sum, c) => sum + c.unreadCount);
}

/// My conversations, newest first, kept current by live `message.new` and
/// `conversation.read` events. The app loads it on sign-in (for the badge) and
/// clears it on sign-out.
class ConversationsController extends StateNotifier<ConversationsState> {
  ConversationsController(this._ref) : super(const ConversationsState()) {
    final realtime = _ref.read(realtimeProvider);
    _events = realtime.events.listen(_onEvent);
    // Back online after a gap: catch up on anything missed.
    _status = realtime.statusChanges.listen((status) {
      if (status == RealtimeStatus.online && state.status != ChatLoad.idle) load();
    });
  }

  final Ref _ref;
  late final StreamSubscription<Map<String, dynamic>> _events;
  late final StreamSubscription<RealtimeStatus> _status;
  int _requestId = 0;

  ChatRepository get _repo => _ref.read(chatRepositoryProvider);

  Future<void> load() async {
    final id = ++_requestId;
    if (state.items.isEmpty) state = const ConversationsState(status: ChatLoad.loading);
    try {
      final items = await _repo.list();
      if (id != _requestId || !mounted) return;
      state = ConversationsState(items: items, status: ChatLoad.ready);
    } catch (e) {
      if (id != _requestId || !mounted) return;
      state = ConversationsState(
          items: state.items, status: ChatLoad.error, error: describeApiError(e));
    }
  }

  void reset() {
    _requestId++;
    state = const ConversationsState();
  }

  /// Puts [summary] first (a new or updated conversation).
  void upsert(ConversationSummary summary) {
    state = ConversationsState(
      items: [summary, ...state.items.where((c) => c.id != summary.id)],
      status: state.status == ChatLoad.idle ? ChatLoad.ready : state.status,
      error: state.error,
    );
  }

  /// A message I sent, shown as the conversation's latest.
  void sent(ConversationDetail conversation, ChatMessage message) {
    final existing = state.items.where((c) => c.id == conversation.id).firstOrNull;
    upsert((existing ?? conversation).copyWith(lastMessage: message, unreadCount: 0));
  }

  void markedRead(int conversationId) {
    state = ConversationsState(
      items: [
        for (final c in state.items) c.id == conversationId ? c.copyWith(unreadCount: 0) : c
      ],
      status: state.status,
      error: state.error,
    );
  }

  void _onEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'message.new':
        final conversation = event['conversation'];
        if (conversation is Map<String, dynamic>) {
          upsert(ConversationSummary.fromJson(conversation));
        }
      case 'conversation.read':
        // My own read on another device (the reader's side is mine).
        final id = event['conversation_id'];
        final mine = state.items.where((c) => c.id == id && c.mySide.name == event['side']);
        if (mine.isNotEmpty) markedRead(id as int);
    }
  }

  @override
  void dispose() {
    _events.cancel();
    _status.cancel();
    super.dispose();
  }
}

final conversationsControllerProvider =
    StateNotifierProvider<ConversationsController, ConversationsState>(
        (ref) => ConversationsController(ref));

/// Unread messages: the Chat tab badge and the dashboard.
final unreadMessagesProvider =
    Provider<int>((ref) => ref.watch(conversationsControllerProvider).unread);

// ─────────────── one conversation ───────────────
class ConversationState {
  const ConversationState({
    this.detail,
    this.messages = const [],
    this.status = ChatLoad.loading,
    this.hasMore = false,
    this.loadingOlder = false,
    this.otherTyping = false,
    this.error,
  });

  final ConversationDetail? detail;

  /// Oldest first, including messages still being sent.
  final List<ChatMessage> messages;
  final ChatLoad status;
  final bool hasMore;
  final bool loadingOlder;
  final bool otherTyping;
  final String? error;

  /// My newest message the other side has read (it shows "Seen").
  int? get seenMessageId {
    final read = detail?.otherLastReadId;
    if (read == null) return null;
    return messages.where((m) => m.isMine && m.id > 0 && m.id <= read).lastOrNull?.id;
  }

  ConversationState copyWith({
    ConversationDetail? detail,
    List<ChatMessage>? messages,
    ChatLoad? status,
    bool? hasMore,
    bool? loadingOlder,
    bool? otherTyping,
    String? Function()? error,
  }) =>
      ConversationState(
        detail: detail ?? this.detail,
        messages: messages ?? this.messages,
        status: status ?? this.status,
        hasMore: hasMore ?? this.hasMore,
        loadingOlder: loadingOlder ?? this.loadingOlder,
        otherTyping: otherTyping ?? this.otherTyping,
        error: error != null ? error() : this.error,
      );
}

/// A conversation screen: history, live messages, sending (optimistic, with
/// retry), photos, "Seen", typing, and polling while the socket is down.
class ConversationController extends StateNotifier<ConversationState> {
  ConversationController(this._ref, this.conversationId) : super(const ConversationState()) {
    final realtime = _ref.read(realtimeProvider);
    _events = realtime.events.listen(_onEvent);
    _status = realtime.statusChanges.listen(_onStatus);
    load();
  }

  final Ref _ref;
  final int conversationId;
  late final StreamSubscription<Map<String, dynamic>> _events;
  late final StreamSubscription<RealtimeStatus> _status;
  Timer? _pollTimer;
  Timer? _typingTimer;
  DateTime? _lastTypingSent;
  int _pendingSeq = 0;
  static final _random = Random.secure();

  static const pageSize = 30;
  static const pollEvery = Duration(seconds: 8);
  static const typingThrottle = Duration(seconds: 3);
  static const typingShownFor = Duration(seconds: 4);

  ChatRepository get _repo => _ref.read(chatRepositoryProvider);
  Realtime get _realtime => _ref.read(realtimeProvider);
  ChatSide get _mySide => state.detail?.mySide ?? ChatSide.customer;

  Future<void> load() async {
    state = state.copyWith(status: ChatLoad.loading, error: () => null);
    try {
      final detail = await _repo.get(conversationId);
      final page = await _repo.messages(conversationId, limit: pageSize);
      if (!mounted) return;
      state = state.copyWith(
          detail: detail, messages: page.items, hasMore: page.hasMore, status: ChatLoad.ready);
      _onStatus(_realtime.status);
      _markRead();
    } catch (e) {
      if (mounted) state = state.copyWith(status: ChatLoad.error, error: () => describeApiError(e));
    }
  }

  Future<void> loadOlder() async {
    final first = state.messages.where((m) => m.id > 0).firstOrNull;
    if (state.loadingOlder || !state.hasMore || first == null) return;
    state = state.copyWith(loadingOlder: true);
    try {
      final page = await _repo.messages(conversationId, beforeId: first.id, limit: pageSize);
      if (!mounted) return;
      state = state.copyWith(
          messages: [...page.items, ...state.messages], hasMore: page.hasMore, loadingOlder: false);
    } catch (_) {
      if (mounted) state = state.copyWith(loadingOlder: false);
    }
  }

  /// Fetches messages newer than the last one shown (after a reconnect, or while polling).
  Future<void> catchUp() async {
    final last = state.messages.where((m) => m.id > 0).lastOrNull;
    if (state.status != ChatLoad.ready) return;
    try {
      final page = await _repo.messages(conversationId, afterId: last?.id, limit: 100);
      if (!mounted || page.items.isEmpty) return;
      for (final m in page.items) {
        _add(m);
      }
      _markRead();
    } catch (_) {}
  }

  Future<void> send(String text) async {
    final body = text.trim();
    if (body.isEmpty) return;
    // Asked here, while the user's tap is still "fresh" (browsers require that).
    unawaited(_ref.read(pushControllerProvider.notifier).maybeAskAfterFirstMessage());
    final pending = _pending(body: body);
    state = state.copyWith(messages: [...state.messages, pending]);
    await _deliver(pending);
  }

  Future<void> sendPhoto(PickedPhoto photo) async {
    final pending = _pending(body: '', localPhoto: photo);
    state = state.copyWith(messages: [...state.messages, pending]);
    await _deliver(pending, photo: photo);
  }

  Future<void> retry(ChatMessage failed) async {
    _replace(failed.clientId!, failed.copyWith(status: SendStatus.sending));
    await _deliver(failed);
  }

  /// Tells the other side I'm typing, at most every few seconds.
  void typing() {
    final now = DateTime.now();
    if (_lastTypingSent != null && now.difference(_lastTypingSent!) < typingThrottle) return;
    _lastTypingSent = now;
    _realtime.send({'type': 'typing', 'conversation_id': conversationId});
  }

  ChatMessage _pending({required String body, PickedPhoto? localPhoto}) {
    final clientId =
        List.generate(16, (_) => _random.nextInt(16).toRadixString(16)).join();
    return ChatMessage(
      id: -(++_pendingSeq),
      conversationId: conversationId,
      body: body,
      fromBusiness: _mySide == ChatSide.business,
      isMine: true,
      createdAt: DateTime.now(),
      clientId: clientId,
      status: SendStatus.sending,
      localPhoto: localPhoto?.bytes,
    );
  }

  Future<void> _deliver(ChatMessage pending, {PickedPhoto? photo}) async {
    try {
      String? key;
      if (photo != null) {
        key = (await _ref.read(mediaRepositoryProvider).upload(photo.bytes, filename: photo.name))
            .key;
      }
      final saved = await _repo.send(conversationId,
          body: pending.body, clientId: pending.clientId!, photoKey: key);
      if (!mounted) return;
      _add(saved);
      final detail = state.detail;
      if (detail != null) _ref.read(conversationsControllerProvider.notifier).sent(detail, saved);
    } catch (_) {
      if (mounted) _replace(pending.clientId!, pending.copyWith(status: SendStatus.failed));
    }
  }

  /// Adds a confirmed message: replaces its pending copy, or skips a duplicate.
  void _add(ChatMessage message) {
    final messages = [...state.messages];
    if (messages.any((m) => m.id == message.id)) {
      messages.removeWhere((m) => m.id < 0 && m.clientId != null && m.clientId == message.clientId);
    } else {
      final pending = messages.indexWhere(
          (m) => m.id < 0 && message.clientId != null && m.clientId == message.clientId);
      if (pending >= 0) {
        messages[pending] = message;
      } else {
        messages.add(message);
      }
    }
    state = state.copyWith(messages: messages);
  }

  void _replace(String clientId, ChatMessage message) {
    state = state.copyWith(messages: [
      for (final m in state.messages) m.id < 0 && m.clientId == clientId ? message : m
    ]);
  }

  Future<void> _markRead() async {
    final detail = state.detail;
    final lastFromThem = state.messages.where((m) => !m.isMine && m.id > 0).lastOrNull;
    if (detail == null || lastFromThem == null) return;
    if ((detail.myLastReadId ?? 0) >= lastFromThem.id) return;
    try {
      await _repo.markRead(conversationId);
      _ref.read(conversationsControllerProvider.notifier).markedRead(conversationId);
    } catch (_) {}
  }

  void _onEvent(Map<String, dynamic> event) {
    if (event['conversation_id'] != conversationId || state.detail == null) return;
    switch (event['type']) {
      case 'message.new':
        final message = ChatMessage.fromJson(event['message'] as Map<String, dynamic>);
        _add(message);
        if (!message.isMine) {
          _typingTimer?.cancel();
          state = state.copyWith(otherTyping: false);
          _markRead();
        }
      case 'conversation.read':
        if (event['side'] != _mySide.name) {
          state = state.copyWith(detail: state.detail!.withOtherRead(event['last_read_id'] as int));
        }
      case 'typing':
        if (event['side'] != _mySide.name) {
          state = state.copyWith(otherTyping: true);
          _typingTimer?.cancel();
          _typingTimer = Timer(typingShownFor, () {
            if (mounted) state = state.copyWith(otherTyping: false);
          });
        }
    }
  }

  void _onStatus(RealtimeStatus status) {
    if (status == RealtimeStatus.online) {
      _pollTimer?.cancel();
      _pollTimer = null;
      catchUp();
    } else if (_pollTimer == null && state.status == ChatLoad.ready) {
      // REL-5: without live events, look for new messages every few seconds.
      _pollTimer = Timer.periodic(pollEvery, (_) => catchUp());
    }
  }

  @override
  void dispose() {
    _events.cancel();
    _status.cancel();
    _pollTimer?.cancel();
    _typingTimer?.cancel();
    super.dispose();
  }
}

final conversationControllerProvider = StateNotifierProvider.autoDispose
    .family<ConversationController, ConversationState, int>(
        (ref, id) => ConversationController(ref, id));

/// Opens (or starts) the customer's conversation with a business; returns its id.
Future<int> openConversationWith(WidgetRef ref, int businessId) async =>
    (await ref.read(chatRepositoryProvider).open(businessId)).id;
