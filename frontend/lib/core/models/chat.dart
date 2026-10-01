// Module 9 — chat and messaging, mirroring backend/app/schemas/chat.py.

import 'dart:typed_data';

import '../maps/map_types.dart';
import 'business.dart';
import 'photo.dart';

/// Which participant the viewer is in a conversation.
enum ChatSide {
  customer,
  business;

  static ChatSide fromApi(String? s) => s == 'business' ? business : customer;
}

enum ConversationReportReason {
  spam('spam', 'Spam or advertising'),
  harassment('harassment', 'Harassment or abuse'),
  scam('scam', 'A scam or fraud'),
  other('other', 'Something else');

  const ConversationReportReason(this.api, this.label);
  final String api;
  final String label;
}

/// The customer, as a business owner sees them.
class ChatPerson {
  const ChatPerson({
    required this.id,
    required this.name,
    required this.initials,
    required this.tone,
    this.avatar,
  });

  final int id;

  /// "Ali C."
  final String name;
  final String initials;
  final String tone;
  final Photo? avatar;

  factory ChatPerson.fromJson(Map<String, dynamic> j) => ChatPerson(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        initials: j['initials'] as String? ?? '?',
        tone: j['tone'] as String? ?? 'gold',
        avatar: Photo.maybe(j['avatar']),
      );
}

/// The business in a conversation: a brief version in lists, the full header
/// (open now, phone, location, offers) inside the conversation.
class ChatBusiness {
  const ChatBusiness({
    required this.id,
    required this.name,
    required this.tone,
    this.cover,
    this.categoryLabel,
    this.isVerified = false,
    this.isOpenNow,
    this.todayHours,
    this.phone,
    this.latitude,
    this.longitude,
    this.offers = const [],
  });

  final int id;
  final String name;
  final String tone;
  final Photo? cover;
  final String? categoryLabel;
  final bool isVerified;
  final bool? isOpenNow;
  final String? todayHours;
  final String? phone;
  final double? latitude;
  final double? longitude;

  /// Active offers only.
  final List<Offer> offers;

  GeoPoint? get location {
    if (latitude == null || longitude == null) return null;
    final p = GeoPoint(latitude!, longitude!);
    return p.isValid ? p : null;
  }

  /// "Open now · 09:00–22:00", "Closed now", or null when hours are unknown.
  String? get openLabel {
    if (isOpenNow == null) return null;
    return [isOpenNow! ? 'Open now' : 'Closed now', if (todayHours != null) todayHours!]
        .join(' · ');
  }

  factory ChatBusiness.fromJson(Map<String, dynamic> j) => ChatBusiness(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        tone: j['tone'] as String? ?? 'gold',
        cover: Photo.maybe(j['cover']),
        categoryLabel: j['category_label'] as String?,
        isVerified: j['is_verified'] as bool? ?? false,
        isOpenNow: j['is_open_now'] as bool?,
        todayHours: j['today_hours'] as String?,
        phone: j['phone'] as String?,
        latitude: (j['latitude'] as num?)?.toDouble(),
        longitude: (j['longitude'] as num?)?.toDouble(),
        offers: (j['offers'] as List?)
                ?.map((e) => Offer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
      );
}

enum SendStatus { sending, sent, failed }

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.body,
    required this.fromBusiness,
    required this.isMine,
    required this.createdAt,
    this.photo,
    this.clientId,
    this.status = SendStatus.sent,
    this.localPhoto,
  });

  /// Negative while the message is still being sent.
  final int id;
  final int conversationId;
  final String body;
  final Photo? photo;
  final bool fromBusiness;
  final bool isMine;
  final DateTime createdAt;
  final String? clientId;
  final SendStatus status;

  /// The picked photo's bytes, shown until the upload finishes.
  final Uint8List? localPhoto;

  bool get hasPhoto => photo != null || localPhoto != null;

  /// What a conversation row shows as its last message.
  String get preview => body.isNotEmpty ? body : (hasPhoto ? '📷 Photo' : '');

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: j['id'] as int,
        conversationId: j['conversation_id'] as int,
        body: j['body'] as String? ?? '',
        photo: Photo.maybe(j['photo']),
        fromBusiness: j['from_business'] as bool? ?? false,
        isMine: j['is_mine'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
        clientId: j['client_id'] as String?,
      );

  ChatMessage copyWith({SendStatus? status}) => ChatMessage(
        id: id,
        conversationId: conversationId,
        body: body,
        photo: photo,
        fromBusiness: fromBusiness,
        isMine: isMine,
        createdAt: createdAt,
        clientId: clientId,
        status: status ?? this.status,
        localPhoto: localPhoto,
      );
}

class ConversationSummary {
  const ConversationSummary({
    required this.id,
    required this.mySide,
    required this.business,
    required this.customer,
    this.lastMessage,
    this.lastMessageAt,
    this.unreadCount = 0,
  });

  final int id;
  final ChatSide mySide;
  final ChatBusiness business;
  final ChatPerson customer;
  final ChatMessage? lastMessage;
  final DateTime? lastMessageAt;
  final int unreadCount;

  bool get iAmTheBusiness => mySide == ChatSide.business;

  /// Who the conversation is with.
  String get title => iAmTheBusiness ? customer.name : business.name;

  factory ConversationSummary.fromJson(Map<String, dynamic> j) => ConversationSummary(
        id: j['id'] as int,
        mySide: ChatSide.fromApi(j['my_side'] as String?),
        business: ChatBusiness.fromJson(j['business'] as Map<String, dynamic>),
        customer: ChatPerson.fromJson(j['customer'] as Map<String, dynamic>),
        lastMessage: j['last_message'] == null
            ? null
            : ChatMessage.fromJson(j['last_message'] as Map<String, dynamic>),
        lastMessageAt: j['last_message_at'] == null
            ? null
            : DateTime.parse(j['last_message_at'] as String),
        unreadCount: j['unread_count'] as int? ?? 0,
      );

  ConversationSummary copyWith({ChatMessage? lastMessage, int? unreadCount}) =>
      ConversationSummary(
        id: id,
        mySide: mySide,
        business: business,
        customer: customer,
        lastMessage: lastMessage ?? this.lastMessage,
        lastMessageAt: lastMessage?.createdAt ?? lastMessageAt,
        unreadCount: unreadCount ?? this.unreadCount,
      );
}

class ConversationDetail extends ConversationSummary {
  const ConversationDetail({
    required super.id,
    required super.mySide,
    required super.business,
    required super.customer,
    super.lastMessage,
    super.lastMessageAt,
    super.unreadCount,
    this.otherLastReadId,
    this.myLastReadId,
    this.blockedByMe = false,
    this.blockedByThem = false,
    this.closed = false,
    this.canSend = true,
  });

  /// Messages up to this id show "Seen".
  final int? otherLastReadId;
  final int? myLastReadId;

  // ── Module 8 ──
  final bool blockedByMe;
  final bool blockedByThem;

  /// Closed by Khojlo's moderators after a report.
  final bool closed;

  /// Whether the viewer can send a message now.
  final bool canSend;

  factory ConversationDetail.fromJson(Map<String, dynamic> j) {
    final s = ConversationSummary.fromJson(j);
    return ConversationDetail(
      id: s.id,
      mySide: s.mySide,
      business: s.business,
      customer: s.customer,
      lastMessage: s.lastMessage,
      lastMessageAt: s.lastMessageAt,
      unreadCount: s.unreadCount,
      otherLastReadId: j['other_last_read_id'] as int?,
      myLastReadId: j['my_last_read_id'] as int?,
      blockedByMe: j['blocked_by_me'] as bool? ?? false,
      blockedByThem: j['blocked_by_them'] as bool? ?? false,
      closed: j['closed'] as bool? ?? false,
      canSend: j['can_send'] as bool? ?? true,
    );
  }

  ConversationDetail withOtherRead(int lastReadId) => ConversationDetail(
        id: id,
        mySide: mySide,
        business: business,
        customer: customer,
        lastMessage: lastMessage,
        lastMessageAt: lastMessageAt,
        unreadCount: unreadCount,
        otherLastReadId: lastReadId,
        myLastReadId: myLastReadId,
        blockedByMe: blockedByMe,
        blockedByThem: blockedByThem,
        closed: closed,
        canSend: canSend,
      );
}

class MessagePage {
  const MessagePage({required this.items, this.hasMore = false});

  /// Oldest first.
  final List<ChatMessage> items;
  final bool hasMore;

  factory MessagePage.fromJson(Map<String, dynamic> j) => MessagePage(
        items: (j['items'] as List)
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList(),
        hasMore: j['has_more'] as bool? ?? false,
      );
}

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov',
    'Dec'];

String _hhmm(DateTime t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

bool _sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Time of a message inside a conversation: "14:05".
String messageTime(DateTime when) => _hhmm(when.toLocal());

/// A conversation row's time: "14:05" today, "Yesterday", "Mon" this week, else "12 Sep".
String conversationTime(DateTime when, {DateTime? now}) {
  final t = when.toLocal();
  final today = now ?? DateTime.now();
  if (_sameDay(t, today)) return _hhmm(t);
  if (_sameDay(t, today.subtract(const Duration(days: 1)))) return 'Yesterday';
  if (today.difference(t).inDays < 7) return _weekdays[t.weekday - 1];
  return '${t.day} ${_months[t.month - 1]}';
}

/// Separator between days in a conversation: "Today", "Yesterday", "Mon 22 Sep".
String dayLabel(DateTime when, {DateTime? now}) {
  final t = when.toLocal();
  final today = now ?? DateTime.now();
  if (_sameDay(t, today)) return 'Today';
  if (_sameDay(t, today.subtract(const Duration(days: 1)))) return 'Yesterday';
  final year = t.year == today.year ? '' : ' ${t.year}';
  return '${_weekdays[t.weekday - 1]} ${t.day} ${_months[t.month - 1]}$year';
}
