import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/review.dart';
import '../../../core/providers.dart';

final reviewsRepositoryProvider = Provider<ReviewsRepository>((ref) {
  return ReviewsRepository(ref.watch(dioProvider));
});

/// Module 5 endpoints: `/businesses/{id}/reviews`, `/reviews/*` and `/users/me/reviews`.
class ReviewsRepository {
  ReviewsRepository(this._dio);
  final Dio _dio;

  Future<ReviewPage> list(
    int businessId, {
    ReviewSort sort = ReviewSort.relevant,
    Set<int> stars = const {},
    bool photosOnly = false,
    int limit = 10,
    int offset = 0,
  }) async {
    final res = await _dio.get('/businesses/$businessId/reviews', queryParameters: {
      'sort': sort.api,
      if (stars.isNotEmpty) 'stars': stars.toList()..sort(),
      if (photosOnly) 'photos': true,
      'limit': limit,
      'offset': offset,
    });
    return ReviewPage.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Review> create(int businessId,
      {required int rating, String comment = '', List<String> photos = const []}) async {
    final res = await _dio.post('/businesses/$businessId/reviews',
        data: {'rating': rating, 'comment': comment, 'photos': photos});
    return Review.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Review> update(int reviewId,
      {required int rating, required String comment, required List<String> photos}) async {
    final res = await _dio.patch('/reviews/$reviewId',
        data: {'rating': rating, 'comment': comment, 'photos': photos});
    return Review.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> delete(int reviewId) => _dio.delete('/reviews/$reviewId');

  Future<Review> reply(int reviewId, String text) async {
    final res = await _dio.put('/reviews/$reviewId/reply', data: {'text': text});
    return Review.fromJson(res.data as Map<String, dynamic>);
  }

  Future<Review> deleteReply(int reviewId) async {
    final res = await _dio.delete('/reviews/$reviewId/reply');
    return Review.fromJson(res.data as Map<String, dynamic>);
  }

  /// Returns (helpful count, whether the user now has a vote on it).
  Future<(int, bool)> setHelpful(int reviewId, bool helpful) async {
    final res = helpful
        ? await _dio.put('/reviews/$reviewId/helpful')
        : await _dio.delete('/reviews/$reviewId/helpful');
    final data = res.data as Map<String, dynamic>;
    return (data['helpful_count'] as int, data['voted_helpful'] as bool);
  }

  Future<void> report(int reviewId, ReportReason reason, {String note = ''}) =>
      _dio.post('/reviews/$reviewId/report', data: {'reason': reason.api, 'note': note});

  Future<List<MyReview>> mine() async {
    final res = await _dio.get('/users/me/reviews');
    return (res.data as List).map((e) => MyReview.fromJson(e as Map<String, dynamic>)).toList();
  }
}
