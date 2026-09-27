import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/review.dart';
import '../../core/network/api_client.dart';
import 'data/reviews_repository.dart';

/// Bumped after a review is written, edited or deleted, or a reply changes, so every
/// view of reviews (business page, full list, dashboard, My reviews) reloads.
final reviewChangesProvider = StateProvider<int>((ref) => 0);

/// The business page / dashboard preview: summary plus the top few reviews.
final reviewPreviewProvider =
    FutureProvider.autoDispose.family<ReviewPage, int>((ref, businessId) async {
  ref.watch(reviewChangesProvider);
  return ref.watch(reviewsRepositoryProvider).list(businessId, limit: 3);
});

final myReviewsProvider = FutureProvider.autoDispose<List<MyReview>>((ref) async {
  ref.watch(reviewChangesProvider);
  return ref.watch(reviewsRepositoryProvider).mine();
});

enum ReviewsStatus { loading, ready, error }

class ReviewsState {
  const ReviewsState({
    this.summary = ReviewSummary.empty,
    this.items = const [],
    this.total = 0,
    this.mine,
    this.canReview = false,
    this.isOwner = false,
    this.sort = ReviewSort.relevant,
    this.stars = const {},
    this.photosOnly = false,
    this.status = ReviewsStatus.loading,
    this.loadingMore = false,
    this.error,
  });

  final ReviewSummary summary;
  final List<Review> items;
  final int total;
  final Review? mine;
  final bool canReview;
  final bool isOwner;
  final ReviewSort sort;
  final Set<int> stars;
  final bool photosOnly;
  final ReviewsStatus status;
  final bool loadingMore;
  final String? error;

  bool get hasMore => items.length < total;
  bool get filtered => stars.isNotEmpty || photosOnly;

  ReviewsState copyWith({
    ReviewPage? page,
    List<Review>? items,
    Review? Function()? mine,
    ReviewSort? sort,
    Set<int>? stars,
    bool? photosOnly,
    ReviewsStatus? status,
    bool? loadingMore,
    String? Function()? error,
  }) =>
      ReviewsState(
        summary: page?.summary ?? summary,
        items: items ?? page?.items ?? this.items,
        total: page?.total ?? total,
        mine: mine != null ? mine() : (page != null ? page.mine : this.mine),
        canReview: page?.canReview ?? canReview,
        isOwner: page?.isOwner ?? isOwner,
        sort: sort ?? this.sort,
        stars: stars ?? this.stars,
        photosOnly: photosOnly ?? this.photosOnly,
        status: status ?? this.status,
        loadingMore: loadingMore ?? this.loadingMore,
        error: error != null ? error() : this.error,
      );
}

/// The full reviews list of one business (SDD Screen 3 "See All"): sort, filter by stars
/// or photos, page, and act on reviews. Stale responses are dropped.
class ReviewsController extends StateNotifier<ReviewsState> {
  ReviewsController(this._ref, this.businessId) : super(const ReviewsState()) {
    load();
  }

  final Ref _ref;
  final int businessId;
  int _requestId = 0;

  static const pageSize = 10;

  ReviewsRepository get _repo => _ref.read(reviewsRepositoryProvider);

  Future<void> load() async {
    final id = ++_requestId;
    state = state.copyWith(status: ReviewsStatus.loading, error: () => null);
    try {
      final page = await _repo.list(businessId,
          sort: state.sort, stars: state.stars, photosOnly: state.photosOnly, limit: pageSize);
      if (id != _requestId || !mounted) return;
      state = state.copyWith(page: page, status: ReviewsStatus.ready);
    } catch (e) {
      if (id != _requestId || !mounted) return;
      state = state.copyWith(status: ReviewsStatus.error, error: () => describeApiError(e));
    }
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore || state.status != ReviewsStatus.ready) return;
    final id = _requestId;
    state = state.copyWith(loadingMore: true);
    try {
      final page = await _repo.list(businessId,
          sort: state.sort,
          stars: state.stars,
          photosOnly: state.photosOnly,
          limit: pageSize,
          offset: state.items.length);
      if (id != _requestId || !mounted) return;
      state = state.copyWith(items: [...state.items, ...page.items], loadingMore: false);
    } catch (_) {
      if (id == _requestId && mounted) state = state.copyWith(loadingMore: false);
    }
  }

  void setSort(ReviewSort sort) {
    if (sort == state.sort) return;
    state = state.copyWith(sort: sort);
    load();
  }

  void toggleStars(int stars) {
    final next = {...state.stars};
    next.contains(stars) ? next.remove(stars) : next.add(stars);
    state = state.copyWith(stars: next);
    load();
  }

  void setPhotosOnly(bool value) {
    state = state.copyWith(photosOnly: value);
    load();
  }

  void clearFilters() {
    state = state.copyWith(stars: const {}, photosOnly: false);
    load();
  }

  void _replace(Review updated) {
    state = state.copyWith(
      items: [for (final r in state.items) r.id == updated.id ? updated : r],
      mine: state.mine?.id == updated.id ? () => updated : null,
    );
  }

  /// Toggle "Helpful" optimistically; rolls back if the server says no.
  Future<String?> toggleHelpful(Review review) async {
    final want = !review.votedHelpful;
    _replace(review.copyWith(
        votedHelpful: want, helpfulCount: review.helpfulCount + (want ? 1 : -1)));
    try {
      final (count, voted) = await _repo.setHelpful(review.id, want);
      if (mounted) _replace(review.copyWith(helpfulCount: count, votedHelpful: voted));
      return null;
    } catch (e) {
      if (mounted) _replace(review);
      return describeApiError(e);
    }
  }

  Future<String?> report(Review review, ReportReason reason, String note) async {
    try {
      await _repo.report(review.id, reason, note: note);
      if (mounted) _replace(review.copyWith(reported: true));
      return null;
    } catch (e) {
      return describeApiError(e);
    }
  }

  Future<String?> reply(Review review, String text) async {
    try {
      final updated = await _repo.reply(review.id, text);
      if (mounted) _replace(updated);
      _ref.read(reviewChangesProvider.notifier).state++;
      return null;
    } catch (e) {
      return describeApiError(e);
    }
  }

  Future<String?> deleteReply(Review review) async {
    try {
      final updated = await _repo.deleteReply(review.id);
      if (mounted) _replace(updated);
      _ref.read(reviewChangesProvider.notifier).state++;
      return null;
    } catch (e) {
      return describeApiError(e);
    }
  }
}

final reviewsControllerProvider = StateNotifierProvider.autoDispose
    .family<ReviewsController, ReviewsState, int>((ref, businessId) {
  final controller = ReviewsController(ref, businessId);
  // Written, edited or deleted elsewhere (e.g. the write sheet) → reload, keeping filters.
  ref.listen(reviewChangesProvider, (_, __) => controller.load());
  return controller;
});

/// Writing, editing and deleting your own review (UC-7), shared by every screen.
class ReviewActions {
  ReviewActions(this._ref);
  final Ref _ref;

  ReviewsRepository get _repo => _ref.read(reviewsRepositoryProvider);

  void _changed() => _ref.read(reviewChangesProvider.notifier).state++;

  Future<Review> save({
    required int businessId,
    Review? existing,
    required int rating,
    required String comment,
    required List<String> photos,
  }) async {
    final saved = existing == null
        ? await _repo.create(businessId, rating: rating, comment: comment, photos: photos)
        : await _repo.update(existing.id, rating: rating, comment: comment, photos: photos);
    _changed();
    return saved;
  }

  Future<void> delete(Review review) async {
    await _repo.delete(review.id);
    _changed();
  }
}

final reviewActionsProvider = Provider<ReviewActions>((ref) => ReviewActions(ref));
