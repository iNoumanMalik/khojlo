import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../reviews_providers.dart';
import 'review_flows.dart';
import 'widgets/rating_summary.dart';
import 'widgets/review_card.dart';

/// The route to a business's full reviews list.
String reviewsRoute(int businessId, String businessName) =>
    Uri(path: '/business/$businessId/reviews', queryParameters: {'name': businessName})
        .toString();

/// SDD Screen 3 "Reviews Section" + "See All Button": the score, the top reviews
/// (verified reviewers first), and the right call to action for the viewer.
class BusinessReviewsSection extends ConsumerWidget {
  const BusinessReviewsSection({super.key, required this.businessId, required this.businessName});

  final int businessId;
  final String businessName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reviewPreviewProvider(businessId));
    final page = async.valueOrNull;
    final seeAll = reviewsRoute(businessId, businessName);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 26, 0, 12),
            child: Row(
              children: [
                Expanded(
                  child: Text('REVIEWS',
                      style: AppType.mono(
                          size: 10.5, color: AppColors.inkA(0.47), letterSpacing: 1.0)),
                ),
                if ((page?.summary.count ?? 0) > 0)
                  GestureDetector(
                    onTap: () => context.push(seeAll),
                    child: Text('See all ${page!.summary.count} →',
                        style: AppType.mono(size: 11, color: AppColors.emerald)),
                  ),
              ],
            ),
          ),
          if (page == null)
            async.hasError
                ? GhostButton(
                    label: 'Couldn’t load reviews · Retry',
                    small: true,
                    onTap: () => ref.invalidate(reviewPreviewProvider(businessId)),
                  )
                : const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald)),
                  )
          else ...[
            GestureDetector(
              onTap: page.summary.count > 0 ? () => context.push(seeAll) : null,
              child: ReviewSummaryCard(summary: page.summary),
            ),
            const SizedBox(height: 12),
            for (final r in page.items.take(2))
              GestureDetector(
                onTap: () => context.push(seeAll),
                child: ReviewCard(review: r, compact: true),
              ),
            if (page.summary.count == 0 && !page.isOwner)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('No reviews yet. Been here? Be the first to share what it’s like.',
                    textAlign: TextAlign.center,
                    style: AppType.sans(size: 13, color: AppColors.inkA(0.55))),
              ),
            if (page.isOwner)
              GhostButton(
                label: (page.summary.unreplied ?? 0) > 0
                    ? 'Reply to reviews (${page.summary.unreplied} waiting)'
                    : 'See and reply to reviews',
                icon: Icons.forum_outlined,
                tone: AppColors.emerald,
                onTap: () => context.push(seeAll),
              )
            else if (page.mine != null)
              GhostButton(
                label: 'Edit your review',
                icon: Icons.edit_outlined,
                tone: AppColors.emerald,
                onTap: () => openWriteReview(context,
                    businessId: businessId, businessName: businessName, existing: page.mine),
              )
            else if (page.canReview)
              PrimaryButton(
                label: 'Write a review',
                icon: Icons.rate_review_outlined,
                tone: ButtonTone.emerald,
                onTap: () =>
                    openWriteReview(context, businessId: businessId, businessName: businessName),
              ),
          ],
        ],
      ),
    );
  }
}
