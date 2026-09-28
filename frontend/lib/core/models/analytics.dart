class WeeklyPoint {
  const WeeklyPoint(this.label, this.value);
  final String label;
  final int value;

  factory WeeklyPoint.fromJson(Map<String, dynamic> j) =>
      WeeklyPoint(j['label'] as String, j['value'] as int);
}

class BusinessAnalytics {
  const BusinessAnalytics({
    required this.businessId,
    required this.profileViews,
    required this.saves,
    required this.messages,
    this.unreadMessages = 0,
    required this.rating,
    required this.reviewCount,
    required this.weeklyViews,
  });

  final int businessId;
  final int profileViews;
  final int saves;
  /// Customer messages received in the last 7 days, and how many are unread.
  final int messages;
  final int unreadMessages;
  final double rating;
  final int reviewCount;
  final List<WeeklyPoint> weeklyViews;

  factory BusinessAnalytics.fromJson(Map<String, dynamic> j) => BusinessAnalytics(
        businessId: j['business_id'] as int,
        profileViews: j['profile_views'] as int,
        saves: j['saves'] as int,
        messages: j['messages'] as int,
        unreadMessages: j['unread_messages'] as int? ?? 0,
        rating: (j['rating'] as num).toDouble(),
        reviewCount: j['review_count'] as int,
        weeklyViews: (j['weekly_views'] as List)
            .map((e) => WeeklyPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
