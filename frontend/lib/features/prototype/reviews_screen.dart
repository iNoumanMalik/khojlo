import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';
import 'mock_data.dart';

/// Module 5 — Reviews & ratings (prototype).
class ReviewsScreen extends StatelessWidget {
  const ReviewsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.emerald,
          onPressed: () {},
          icon: const Icon(Icons.edit_outlined, color: Colors.white),
          label: Text('Write a review',
              style: AppType.sans(
                  size: 13, weight: FontWeight.w700, color: Colors.white)),
        ),
      ),
      body: Column(
        children: [
          TopBar(title: 'Reviews', subtitle: 'Sky Eleven Rooftop', onBack: () => context.pop()),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 90),
              children: [
                Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('4.9', style: AppType.serif(size: 52)),
                        Row(
                          children: List.generate(
                              5,
                              (_) => const Icon(Icons.star_rounded,
                                  size: 16, color: AppColors.gold)),
                        ),
                        const SizedBox(height: 4),
                        Text('312 reviews',
                            style: AppType.mono(
                                size: 11, color: AppColors.inkA(0.53))),
                      ],
                    ),
                    const SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          for (final e in const [
                            ('5', 82),
                            ('4', 12),
                            ('3', 4),
                            ('2', 1),
                            ('1', 1),
                          ])
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: RatingBar(label: e.$1, pct: e.$2),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.whiteA(0.7),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.emerald.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.auto_awesome,
                          color: AppColors.emerald, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                            'AI summary: guests love the view and cocktails; a few note it gets busy on weekends.',
                            style: AppType.sans(
                                size: 12.5,
                                height: 1.4,
                                color: AppColors.inkA(0.7))),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text('RECENT REVIEWS', style: AppType.label()),
                const SizedBox(height: 12),
                for (final r in Mock.reviews) _ReviewCard(r: r),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.r});
  final ({String author, String tone, int rating, String body, String time}) r;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.whiteA(0.7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.inkA(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              KhojloAvatar(initials: r.author[0], tone: r.tone, size: 38),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(r.author,
                          style: AppType.sans(
                              size: 14, weight: FontWeight.w700)),
                      const SizedBox(width: 6),
                      KhojloBadge(label: 'Verified', tone: BadgeTone.emerald),
                    ],
                  ),
                  Row(
                    children: [
                      ...List.generate(
                          r.rating,
                          (_) => const Icon(Icons.star_rounded,
                              size: 13, color: AppColors.gold)),
                      const SizedBox(width: 6),
                      Text(r.time,
                          style: AppType.mono(
                              size: 10, color: AppColors.inkA(0.4))),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(r.body,
              style: AppType.sans(
                  size: 13.5, height: 1.5, color: AppColors.inkA(0.75))),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.favorite_border_rounded,
                  size: 16, color: AppColors.inkA(0.5)),
              const SizedBox(width: 4),
              Text('Helpful',
                  style: AppType.sans(size: 12, color: AppColors.inkA(0.5))),
            ],
          ),
        ],
      ),
    );
  }
}
