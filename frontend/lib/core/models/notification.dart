// Push notifications and the Notifications list, mirroring
// backend/app/schemas/notification.py.

enum NotificationKind {
  message,
  review,
  reviewReply,
  offer,
  newBusiness,
  trending,
  // Module 8: always delivered, not switchable.
  account,
  verification;

  static NotificationKind fromApi(String? s) => switch (s) {
        'message' => message,
        'review' => review,
        'review_reply' => reviewReply,
        'offer' => offer,
        'new_business' => newBusiness,
        'account' => account,
        'verification' => verification,
        _ => trending,
      };
}

class AppNotification {
  const AppNotification({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.route,
    required this.isRead,
    required this.createdAt,
  });

  final int id;
  final NotificationKind kind;
  final String title;
  final String body;

  /// The screen to open, e.g. "/business/5/reviews?name=…".
  final String route;
  final bool isRead;
  final DateTime createdAt;

  factory AppNotification.fromJson(Map<String, dynamic> j) => AppNotification(
        id: j['id'] as int,
        kind: NotificationKind.fromApi(j['kind'] as String?),
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        route: j['route'] as String? ?? '',
        isRead: j['is_read'] as bool? ?? false,
        createdAt: DateTime.parse(j['created_at'] as String),
      );

  AppNotification read() => AppNotification(
        id: id,
        kind: kind,
        title: title,
        body: body,
        route: route,
        isRead: true,
        createdAt: createdAt,
      );
}

class NotificationPage {
  const NotificationPage({required this.items, required this.total, required this.unread});
  final List<AppNotification> items;
  final int total;
  final int unread;

  factory NotificationPage.fromJson(Map<String, dynamic> j) => NotificationPage(
        items: (j['items'] as List)
            .map((e) => AppNotification.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: j['total'] as int? ?? 0,
        unread: j['unread'] as int? ?? 0,
      );
}

/// One switch per notification type (all on by default).
class NotificationPrefs {
  const NotificationPrefs({
    this.messages = true,
    this.reviews = true,
    this.offers = true,
    this.newPlaces = true,
    this.trending = true,
  });

  final bool messages;
  final bool reviews;
  final bool offers;
  final bool newPlaces;
  final bool trending;

  factory NotificationPrefs.fromJson(Map<String, dynamic> j) => NotificationPrefs(
        messages: j['messages'] as bool? ?? true,
        reviews: j['reviews'] as bool? ?? true,
        offers: j['offers'] as bool? ?? true,
        newPlaces: j['new_places'] as bool? ?? true,
        trending: j['trending'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {
        'messages': messages,
        'reviews': reviews,
        'offers': offers,
        'new_places': newPlaces,
        'trending': trending,
      };

  NotificationPrefs copyWith({
    bool? messages,
    bool? reviews,
    bool? offers,
    bool? newPlaces,
    bool? trending,
  }) =>
      NotificationPrefs(
        messages: messages ?? this.messages,
        reviews: reviews ?? this.reviews,
        offers: offers ?? this.offers,
        newPlaces: newPlaces ?? this.newPlaces,
        trending: trending ?? this.trending,
      );
}
