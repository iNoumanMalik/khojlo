import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/review.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../reviews_providers.dart';
import 'review_flows.dart';
import 'widgets/review_card.dart';

/// Profile → My reviews: every review you've written, with Edit / Delete.
class MyReviewsScreen extends ConsumerWidget {
  const MyReviewsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myReviewsProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(
            title: 'My reviews',
            subtitle: async.valueOrNull == null
                ? null
                : '${async.value!.length} review${async.value!.length == 1 ? '' : 's'}',
            onBack: () => context.canPop() ? context.pop() : context.go('/profile'),
          ),
          Expanded(
            child: async.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
              error: (e, _) => _Empty(
                icon: Icons.cloud_off_rounded,
                title: 'Couldn’t load your reviews',
                body: describeApiError(e),
                action: ('Try again', () => ref.invalidate(myReviewsProvider)),
              ),
              data: (reviews) => reviews.isEmpty
                  ? _Empty(
                      icon: Icons.rate_review_outlined,
                      title: 'No reviews yet',
                      body: 'Visited somewhere good? Open it on Khojlo and tap “Write a review”. '
                          'Your reviews help others find great new places.',
                      action: ('Explore places', () => context.go('/explore')),
                    )
                  : RefreshIndicator(
                      color: AppColors.emerald,
                      onRefresh: () => ref.refresh(myReviewsProvider.future),
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        itemCount: reviews.length,
                        itemBuilder: (context, i) => _MyReviewTile(item: reviews[i])
                            .animate(delay: (40 * (i % 10)).ms)
                            .fadeIn(duration: 250.ms),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MyReviewTile extends ConsumerWidget {
  const _MyReviewTile({required this.item});
  final MyReview item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = item.review;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => context.push('/business/${r.businessId}'),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 6),
            child: Row(
              children: [
                SizedBox(
                  width: 36,
                  height: 36,
                  child: ImageTile(tone: item.tone, photo: item.cover, radius: 10),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.businessName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(size: 14, weight: FontWeight.w700)),
                      if (item.categoryLabel != null)
                        Text(item.categoryLabel!,
                            style: AppType.sans(size: 11.5, color: AppColors.inkA(0.5))),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.inkA(0.35)),
              ],
            ),
          ),
        ),
        ReviewCard(
          review: r,
          onEdit: () => openWriteReview(context,
              businessId: r.businessId, businessName: item.businessName, existing: r),
          onDelete: () => deleteMyReview(context, ref, r),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.title, required this.body, this.action});
  final IconData icon;
  final String title;
  final String body;
  final (String, VoidCallback)? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppColors.inkA(0.3)),
            const SizedBox(height: 12),
            Text(title, style: AppType.serif(size: 20)),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: AppType.sans(size: 13, height: 1.45, color: AppColors.inkA(0.55))),
            if (action != null) ...[
              const SizedBox(height: 16),
              GhostButton(label: action!.$1, small: true, expand: false, onTap: action!.$2),
            ],
          ],
        ),
      ),
    );
  }
}
