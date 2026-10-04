import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/review.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../reviews_providers.dart';
import 'review_flows.dart';
import 'review_sheets.dart';
import 'widgets/rating_summary.dart';
import 'widgets/review_card.dart';

/// Module 5 — every review of a business (SDD Screen 3 "See All"; SRS UC-7, FR-6):
/// score circle and distribution, sort and filters, your own review first, helpful votes,
/// reports, and owner replies.
class ReviewsScreen extends ConsumerStatefulWidget {
  const ReviewsScreen({super.key, required this.businessId, this.businessName = ''});

  final int businessId;
  final String businessName;

  @override
  ConsumerState<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends ConsumerState<ReviewsScreen> {
  final _scroll = ScrollController();

  ReviewsController get _controller =>
      ref.read(reviewsControllerProvider(widget.businessId).notifier);

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final p = _scroll.position;
      if (p.pixels > p.maxScrollExtent - 400) _controller.loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  String get _name => widget.businessName.isEmpty ? 'this place' : widget.businessName;

  void _snack(String? error, [String? success]) {
    final message = error ?? success;
    if (message != null) showReviewSnack(context, message);
  }

  Future<void> _report(Review review) async {
    final result = await showReportSheet(context);
    if (result == null || !mounted) return;
    final error = await _controller.report(review, result.$1, result.$2);
    if (mounted) _snack(error, 'Thanks — Khojlo’s team will take a look.');
  }

  Future<void> _reply(Review review) async {
    final text = await showReplySheet(context,
        reviewerName: review.author.name, initial: review.ownerReply?.text);
    if (text == null || !mounted) return;
    final error = await _controller.reply(review, text);
    if (mounted) _snack(error, 'Reply posted.');
  }

  Future<void> _deleteReply(Review review) async {
    final error = await _controller.deleteReply(review);
    if (mounted) _snack(error, 'Reply removed.');
  }

  Future<void> _helpful(Review review) async {
    final error = await _controller.toggleHelpful(review);
    if (mounted && error != null) _snack(error);
  }

  Widget _card(Review r, ReviewsState state) => ReviewCard(
        key: ValueKey('review-${r.id}'),
        review: r,
        isOwner: state.isOwner,
        onHelpful: () => _helpful(r),
        onReport: () => _report(r),
        onReply: () => _reply(r),
        onDeleteReply: () => _deleteReply(r),
        onEdit: () => openWriteReview(context,
            businessId: widget.businessId, businessName: _name, existing: r),
        onDelete: () => deleteMyReview(context, ref, r),
      );

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewsControllerProvider(widget.businessId));
    final others = [for (final r in state.items) if (r.id != state.mine?.id) r];

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(
            title: 'Reviews',
            subtitle: widget.businessName.isEmpty ? null : widget.businessName,
            onBack: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.emerald,
              onRefresh: _controller.load,
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [
                  ReviewSummaryCard(
                    summary: state.summary,
                    selected: state.stars,
                    onStarsTap: _controller.toggleStars,
                  ),
                  const SizedBox(height: 14),
                  if (state.isOwner)
                    _OwnerBanner(unreplied: state.summary.unreplied ?? 0)
                  else if (state.canReview)
                    PrimaryButton(
                      label: 'Write a review',
                      tone: ButtonTone.emerald,
                      icon: Icons.rate_review_outlined,
                      onTap: () => openWriteReview(context,
                          businessId: widget.businessId, businessName: _name),
                    ),
                  if (state.mine != null) ...[
                    const SizedBox(height: 18),
                    Text('YOUR REVIEW', style: AppType.label()),
                    const SizedBox(height: 10),
                    _card(state.mine!, state),
                  ],
                  const SizedBox(height: 18),
                  _FilterBar(
                    state: state,
                    onPhotos: _controller.setPhotosOnly,
                    onSort: _controller.setSort,
                    onClear: _controller.clearFilters,
                  ),
                  const SizedBox(height: 12),
                  ..._list(state, others),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _list(ReviewsState state, List<Review> others) {
    if (state.status == ReviewsStatus.loading && state.items.isEmpty) {
      return const [
        Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        ),
      ];
    }
    if (state.status == ReviewsStatus.error) {
      return [
        _Message(
          icon: Icons.cloud_off_rounded,
          title: 'Couldn’t load reviews',
          body: state.error ?? 'Check your connection and try again.',
          action: ('Try again', _controller.load),
        ),
      ];
    }
    if (others.isEmpty) {
      return [
        state.filtered
            ? _Message(
                icon: Icons.filter_alt_off_outlined,
                title: 'No reviews match',
                body: 'Try other star ratings, or show every review.',
                action: ('Show all reviews', _controller.clearFilters),
              )
            : _Message(
                icon: Icons.rate_review_outlined,
                title: state.mine != null ? 'Only your review so far' : 'No reviews yet',
                body: state.isOwner
                    ? 'Reviews from customers will appear here.'
                    : 'Be the first to share what $_name is like.',
              ),
      ];
    }
    return [
      for (final (i, r) in others.indexed)
        _card(r, state)
            .animate(delay: (30 * (i % 10)).ms)
            .fadeIn(duration: 250.ms)
            .slideY(begin: 0.04, end: 0, duration: 250.ms),
      if (state.loadingMore)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald)),
        ),
    ];
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.state,
    required this.onPhotos,
    required this.onSort,
    required this.onClear,
  });

  final ReviewsState state;
  final ValueChanged<bool> onPhotos;
  final ValueChanged<ReviewSort> onSort;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final starsLabel = (state.stars.toList()..sort((a, b) => b - a)).map((s) => '$s★').join(', ');
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                KhojloChip(label: 'All', active: !state.filtered, onTap: onClear, dense: true),
                const SizedBox(width: 8),
                KhojloChip(
                  label: 'With photos (${state.summary.withPhotos})',
                  active: state.photosOnly,
                  onTap: () => onPhotos(!state.photosOnly),
                  dense: true,
                ),
                if (state.stars.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  KhojloChip(label: '$starsLabel ✕', active: true, onTap: onClear, dense: true),
                ],
              ],
            ),
          ),
        ),
        PopupMenuButton<ReviewSort>(
          tooltip: 'Sort reviews',
          initialValue: state.sort,
          color: AppColors.cream,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          onSelected: onSort,
          itemBuilder: (_) => [
            for (final sort in ReviewSort.values)
              PopupMenuItem(
                value: sort,
                child: Text(sort.label,
                    style: AppType.sans(
                        size: 13.5,
                        weight: sort == state.sort ? FontWeight.w700 : FontWeight.w500)),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.sort_rounded, size: 18, color: AppColors.inkA(0.6)),
                const SizedBox(width: 4),
                Text(state.sort.label,
                    style: AppType.sans(size: 12.5, weight: FontWeight.w600)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnerBanner extends StatelessWidget {
  const _OwnerBanner({required this.unreplied});
  final int unreplied;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.forum_outlined, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              unreplied == 0
                  ? 'You’ve replied to every review. Replies show customers you’re listening.'
                  : '$unreplied review${unreplied == 1 ? '' : 's'} waiting for your reply. '
                      'Replies show customers you’re listening.',
              style: AppType.sans(size: 12.5, height: 1.4, color: AppColors.inkA(0.75)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 12),
      child: Column(
        children: [
          Icon(icon, size: 36, color: AppColors.inkA(0.3)),
          const SizedBox(height: 10),
          Text(title, style: AppType.serif(size: 19)),
          const SizedBox(height: 4),
          Text(body,
              textAlign: TextAlign.center,
              style: AppType.sans(size: 13, height: 1.4, color: AppColors.inkA(0.55))),
          if (action != null) ...[
            const SizedBox(height: 14),
            GhostButton(label: action!.$1, small: true, expand: false, onTap: action!.$2),
          ],
        ],
      ),
    );
  }
}
