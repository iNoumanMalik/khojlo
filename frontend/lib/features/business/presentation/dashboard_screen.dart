import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/analytics.dart';
import '../../../core/models/business.dart';
import '../../../core/models/moderation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../notifications/notifications_providers.dart';
import '../../reviews/presentation/business_reviews_section.dart';
import '../../reviews/reviews_providers.dart';
import '../business_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key, required this.business});
  final BusinessCard business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analytics = ref.watch(analyticsProvider(business.id));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: ListView(
        padding: const EdgeInsets.only(bottom: 130),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 64, 22, 0),
            child: Row(
              children: [
                KhojloAvatar(
                    initials: business.name[0],
                    tone: business.tone,
                    size: 46,
                    photo: business.cover),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(business.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppType.serif(size: 19)),
                          ),
                          if (business.isVerified) ...[
                            const SizedBox(width: 8),
                            KhojloBadge(label: 'Verified'),
                          ],
                        ],
                      ),
                      Text("Here's how you're doing",
                          style: AppType.sans(
                              size: 12, color: AppColors.inkA(0.53))),
                    ],
                  ),
                ),
                GlassIconButton(
                    icon: Icons.notifications_none_rounded,
                    size: 38,
                    showDot: ref.watch(unreadNotificationsProvider) > 0,
                    onTap: () => context.push('/notifications')),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _VerificationCard(business: business),
          const SizedBox(height: 16),
          analytics.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                children: [
                  Row(children: [
                    Expanded(child: SkeletonBox(height: 92, radius: 18)),
                    SizedBox(width: 10),
                    Expanded(child: SkeletonBox(height: 92, radius: 18)),
                  ]),
                ],
              ),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Text('Couldn’t load analytics',
                  style: AppType.sans(color: AppColors.inkA(0.6))),
            ),
            data: (a) => _analytics(context, a),
          ),
        ],
      ),
    );
  }

  Widget _analytics(BuildContext context, BusinessAnalytics a) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
                child: StatCard(
                    label: 'Profile views',
                    value: _fmt(a.profileViews),
                    trend: a.viewsTrend)),
            const SizedBox(width: 10),
            Expanded(
                child: StatCard(
                    label: 'Saves',
                    value: '${a.saves}',
                    trend: a.savesThisWeek > 0 ? '+${a.savesThisWeek} this week' : 'none this week')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: GestureDetector(
                    // Customers' messages to all your businesses are in the Chat tab.
                    onTap: () => context.go('/chat'),
                    child: StatCard(
                        label: 'Messages',
                        value: '${a.messages}',
                        trend: a.unreadMessages > 0
                            ? '${a.unreadMessages} unread'
                            : 'this week'))),
            const SizedBox(width: 10),
            Expanded(
                child: GestureDetector(
                    onTap: () => context.push(reviewsRoute(business.id, business.name)),
                    child: _RatingStat(businessId: business.id, fallback: a))),
          ]),
          const SizedBox(height: 26),
          Text('PROFILE VIEWS · LAST 7 DAYS', style: AppType.label()),
          const SizedBox(height: 14),
          _WeeklyChart(points: a.weeklyViews),
          const SizedBox(height: 26),
          Text('MANAGE', style: AppType.label()),
          const SizedBox(height: 10),
          const Hairline(),
          for (final item in const [
            ('Verification', Icons.verified_outlined),
            ('Edit business profile', Icons.edit_outlined),
            ('Reviews & replies', Icons.forum_outlined),
            ('Offers & promotions', Icons.local_offer_outlined),
            ('Photos', Icons.photo_library_outlined),
            ('Operating hours', Icons.schedule_outlined),
          ])
            _ManageRow(
              label: item.$1,
              onTap: switch (item.$1) {
                'Verification' => () => context.push('/verification/${business.id}'),
                'Edit business profile' => () =>
                    context.push('/edit-business/${business.id}'),
                'Reviews & replies' => () =>
                    context.push(reviewsRoute(business.id, business.name)),
                'Offers & promotions' => () => context.push('/offers/${business.id}'),
                'Photos' => () => context.push('/edit-photos/${business.id}'),
                'Operating hours' => () => context.push('/edit-hours/${business.id}'),
                _ => null,
              },
            ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.gold.withValues(alpha: 0.18),
                AppColors.gold.withValues(alpha: 0.05),
              ]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Boost your visibility',
                          style:
                              AppType.sans(size: 13.5, weight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text('Add a new offer to appear in more feeds',
                          style: AppType.sans(
                              size: 11.5, color: AppColors.inkA(0.53))),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                PrimaryButton(
                  label: 'Create offer',
                  small: true,
                  expand: false,
                  onTap: () => context.push('/offers/${business.id}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(int n) {
    if (n < 1000) return '$n';
    return '${(n / 1000).toStringAsFixed(1)}k';
  }
}

/// Real profile views per day for the last 7 days; today is the last bar.
class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.points});
  final List<WeeklyPoint> points;

  @override
  Widget build(BuildContext context) {
    final max = points.fold<int>(0, (m, p) => p.value > m ? p.value : m);
    final peak = max == 0 ? -1 : points.lastIndexWhere((p) => p.value == max);
    return SizedBox(
      height: 132,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < points.length; i++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text('${points[i].value}',
                        style: AppType.mono(
                            size: 10,
                            weight: i == peak ? FontWeight.w700 : FontWeight.w400,
                            color: AppColors.inkA(points[i].value == 0 ? 0.3 : 0.6))),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 400 + i * 60),
                      curve: Curves.easeOutCubic,
                      tween: Tween(begin: 0, end: max == 0 ? 0 : points[i].value / max),
                      builder: (_, v, __) => Container(
                        height: 80 * v.clamp(0.04, 1.0),
                        decoration: BoxDecoration(
                          color: i == peak
                              ? AppColors.gold
                              : AppColors.emerald.withValues(alpha: 0.33),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(i == points.length - 1 ? 'Today' : points[i].label,
                        maxLines: 1,
                        style: AppType.mono(
                            size: 9.5,
                            weight: i == points.length - 1 ? FontWeight.w700 : FontWeight.w400,
                            color: AppColors.inkA(0.45))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ManageRow extends StatelessWidget {
  const _ManageRow({required this.label, this.onTap});
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Text(label,
                      style: AppType.sans(size: 14, weight: FontWeight.w600)),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.inkA(0.4)),
              ],
            ),
          ),
        ),
        const Hairline(),
      ],
    );
  }
}

/// The dashboard's rating card, from real reviews (Module 5), with replies still owed.
class _RatingStat extends ConsumerWidget {
  const _RatingStat({required this.businessId, required this.fallback});
  final int businessId;
  final BusinessAnalytics fallback;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(reviewPreviewProvider(businessId)).valueOrNull?.summary;
    final count = summary?.count ?? fallback.reviewCount;
    final average = summary?.average ?? fallback.rating;
    final unreplied = summary?.unreplied ?? 0;
    return StatCard(
      label: 'Rating',
      value: count == 0 ? '–' : '${average.toStringAsFixed(1)} ★',
      trend: count == 0
          ? 'No reviews yet'
          : unreplied > 0
              ? '$unreplied awaiting reply'
              : '$count review${count == 1 ? '' : 's'}',
    );
  }
}


/// Module 8: where verification stands, or the suspension notice, at the top of
/// the dashboard. Hidden once the business is verified (the badge says it all).
class _VerificationCard extends ConsumerWidget {
  const _VerificationCard({required this.business});
  final BusinessCard business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = ref.watch(verificationProvider(business.id)).valueOrNull;
    if (info == null || (info.isVerified && !info.isSuspended)) return const SizedBox.shrink();
    final (color, title, body) = info.isSuspended
        ? (AppColors.plum, 'Suspended by Khojlo',
            'Your listing is hidden until Khojlo’s team reinstates it.')
        : switch (info.status) {
            VerificationStatus.pendingReview => (const Color(0xFF8A5B15),
                'Being reviewed', 'Khojlo’s team is looking at your listing.'),
            VerificationStatus.needsInfo => (const Color(0xFF8A5B15),
                'Khojlo needs a little more', 'Tap to see what to change.'),
            VerificationStatus.rejected => (AppColors.plum, 'Not verified',
                'Tap to see why and ask for another look.'),
            _ => (AppColors.emerald, 'Get the Verified badge',
                '${info.passedCount} of ${info.checks.length} checks done. It’s automatic.'),
          };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: GestureDetector(
        onTap: () => context.push('/verification/${business.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Row(children: [
            Icon(info.isSuspended ? Icons.block_rounded : Icons.verified_outlined, color: color),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: AppType.sans(size: 13.5, weight: FontWeight.w700)),
                Text(body, style: AppType.sans(size: 12, color: AppColors.inkA(0.6))),
              ]),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.inkA(0.4)),
          ]),
        ),
      ),
    );
  }
}
