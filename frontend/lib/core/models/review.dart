// Module 5 — reviews and ratings, mirroring backend/app/schemas/review.py.

import 'photo.dart';

enum ReviewSort {
  relevant('relevant', 'Most relevant'),
  recent('recent', 'Newest'),
  highest('highest', 'Highest rated'),
  lowest('lowest', 'Lowest rated'),
  helpful('helpful', 'Most helpful');

  const ReviewSort(this.api, this.label);
  final String api;
  final String label;
}

enum ReportReason {
  spam('spam', 'Spam or advertising'),
  fake('fake', 'Fake — not a real visit'),
  offensive('offensive', 'Offensive or abusive'),
  other('other', 'Something else');

  const ReportReason(this.api, this.label);
  final String api;
  final String label;
}

/// Labels for each star count, shown while picking a rating.
const starLabels = {
  1: 'Terrible',
  2: 'Poor',
  3: 'Okay',
  4: 'Good',
  5: 'Loved it',
};

class ReviewAuthor {
  const ReviewAuthor({
    required this.id,
    required this.name,
    required this.initials,
    required this.tone,
    this.avatar,
    this.isVerified = false,
  });

  final int id;

  /// "Hassan R."
  final String name;
  final String initials;
  final String tone;
  final Photo? avatar;

  /// Verified email: shown with a badge and listed first.
  final bool isVerified;

  factory ReviewAuthor.fromJson(Map<String, dynamic> j) => ReviewAuthor(
        id: j['id'] as int,
        name: j['name'] as String? ?? '',
        initials: j['initials'] as String? ?? '?',
        tone: j['tone'] as String? ?? 'gold',
        avatar: Photo.maybe(j['avatar']),
        isVerified: j['is_verified'] as bool? ?? false,
      );
}

class OwnerReply {
  const OwnerReply({required this.text, required this.createdAt});
  final String text;
  final DateTime createdAt;

  static OwnerReply? maybe(Object? j) => j is Map<String, dynamic>
      ? OwnerReply(
          text: j['text'] as String? ?? '',
          createdAt: DateTime.parse(j['created_at'] as String),
        )
      : null;
}

class Review {
  const Review({
    required this.id,
    required this.businessId,
    required this.rating,
    required this.comment,
    required this.author,
    required this.createdAt,
    this.photos = const [],
    this.updatedAt,
    this.helpfulCount = 0,
    this.ownerReply,
    this.isMine = false,
    this.votedHelpful = false,
    this.reported = false,
    this.isVisible = true,
  });

  final int id;
  final int businessId;
  final int rating;
  final String comment;
  final List<Photo> photos;
  final ReviewAuthor author;
  final DateTime createdAt;

  /// Set when the author edited it.
  final DateTime? updatedAt;
  final int helpfulCount;
  final OwnerReply? ownerReply;
  final bool isMine;
  final bool votedHelpful;
  final bool reported;

  /// False when a moderator hid it (only its author ever sees it then).
  final bool isVisible;

  bool get isEdited => updatedAt != null;

  Review copyWith({
    int? helpfulCount,
    bool? votedHelpful,
    bool? reported,
    OwnerReply? Function()? ownerReply,
  }) =>
      Review(
        id: id,
        businessId: businessId,
        rating: rating,
        comment: comment,
        photos: photos,
        author: author,
        createdAt: createdAt,
        updatedAt: updatedAt,
        helpfulCount: helpfulCount ?? this.helpfulCount,
        ownerReply: ownerReply != null ? ownerReply() : this.ownerReply,
        isMine: isMine,
        votedHelpful: votedHelpful ?? this.votedHelpful,
        reported: reported ?? this.reported,
        isVisible: isVisible,
      );

  factory Review.fromJson(Map<String, dynamic> j) => Review(
        id: j['id'] as int,
        businessId: j['business_id'] as int,
        rating: j['rating'] as int,
        comment: j['comment'] as String? ?? '',
        photos: (j['photos'] as List? ?? const [])
            .map((e) => Photo.fromJson(e as Map<String, dynamic>))
            .toList(),
        author: ReviewAuthor.fromJson(j['author'] as Map<String, dynamic>),
        createdAt: DateTime.parse(j['created_at'] as String),
        updatedAt: j['updated_at'] == null ? null : DateTime.parse(j['updated_at'] as String),
        helpfulCount: j['helpful_count'] as int? ?? 0,
        ownerReply: OwnerReply.maybe(j['owner_reply']),
        isMine: j['is_mine'] as bool? ?? false,
        votedHelpful: j['voted_helpful'] as bool? ?? false,
        reported: j['reported'] as bool? ?? false,
        isVisible: j['is_visible'] as bool? ?? true,
      );
}

class ReviewSummary {
  const ReviewSummary({
    required this.average,
    required this.count,
    required this.distribution,
    this.withPhotos = 0,
    this.unreplied,
  });

  static const empty = ReviewSummary(average: 0, count: 0, distribution: {});

  final double average;
  final int count;

  /// Reviews per star (1–5).
  final Map<int, int> distribution;
  final int withPhotos;

  /// Owners only: reviews still waiting for a reply.
  final int? unreplied;

  int countFor(int stars) => distribution[stars] ?? 0;

  /// Share of reviews with [stars], 0–1.
  double shareOf(int stars) => count == 0 ? 0 : countFor(stars) / count;

  factory ReviewSummary.fromJson(Map<String, dynamic> j) => ReviewSummary(
        average: (j['average'] as num?)?.toDouble() ?? 0,
        count: j['count'] as int? ?? 0,
        distribution: {
          for (final e in (j['distribution'] as Map<String, dynamic>? ?? const {}).entries)
            int.parse(e.key): e.value as int,
        },
        withPhotos: j['with_photos'] as int? ?? 0,
        unreplied: j['unreplied'] as int?,
      );
}

class ReviewPage {
  const ReviewPage({
    required this.summary,
    required this.items,
    required this.total,
    this.mine,
    this.canReview = false,
    this.isOwner = false,
  });

  final ReviewSummary summary;
  final List<Review> items;

  /// Reviews matching the current filters.
  final int total;
  final Review? mine;
  final bool canReview;
  final bool isOwner;

  factory ReviewPage.fromJson(Map<String, dynamic> j) => ReviewPage(
        summary: ReviewSummary.fromJson(j['summary'] as Map<String, dynamic>),
        items: (j['items'] as List)
            .map((e) => Review.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: j['total'] as int? ?? 0,
        mine: j['mine'] == null ? null : Review.fromJson(j['mine'] as Map<String, dynamic>),
        canReview: j['can_review'] as bool? ?? false,
        isOwner: j['is_owner'] as bool? ?? false,
      );
}

/// One of the user's own reviews, with the business it's about ("My reviews").
class MyReview {
  const MyReview({required this.review, required this.businessName, required this.tone,
      this.cover, this.categoryLabel});

  final Review review;
  final String businessName;
  final String tone;
  final Photo? cover;
  final String? categoryLabel;

  factory MyReview.fromJson(Map<String, dynamic> j) {
    final b = j['business'] as Map<String, dynamic>;
    return MyReview(
      review: Review.fromJson(j),
      businessName: b['name'] as String? ?? '',
      tone: b['tone'] as String? ?? 'gold',
      cover: Photo.maybe(b['cover']),
      categoryLabel: b['category_label'] as String?,
    );
  }
}

/// "3 days ago", "2 months ago", or a date for anything older than a year.
String reviewAge(DateTime when, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(when.toLocal());
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inHours < 1) return '${diff.inMinutes} min ago';
  if (diff.inDays < 1) return '${diff.inHours} h ago';
  if (diff.inDays < 7) return diff.inDays == 1 ? 'yesterday' : '${diff.inDays} days ago';
  if (diff.inDays < 30) {
    final weeks = diff.inDays ~/ 7;
    return weeks == 1 ? 'a week ago' : '$weeks weeks ago';
  }
  if (diff.inDays < 365) {
    final months = diff.inDays ~/ 30;
    return months == 1 ? 'a month ago' : '$months months ago';
  }
  const names = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct',
      'Nov', 'Dec'];
  final local = when.toLocal();
  return '${names[local.month - 1]} ${local.year}';
}
