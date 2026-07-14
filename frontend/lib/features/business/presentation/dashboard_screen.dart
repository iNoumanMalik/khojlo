import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/analytics.dart';
import '../../../core/models/business.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
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
                KhojloAvatar(initials: business.name[0], tone: business.tone, size: 46),
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
                    onTap: () => context.push('/notifications')),
              ],
            ),
          ),
          const SizedBox(height: 20),
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
                    trend: '+18% this week')),
            const SizedBox(width: 10),
            Expanded(
                child: StatCard(
                    label: 'Saves', value: '${a.saves}', trend: 'this week')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
                child: StatCard(
                    label: 'Messages',
                    value: '${a.messages}',
                    trend: 'new')),
            const SizedBox(width: 10),
            Expanded(
                child: StatCard(
                    label: 'Rating',
                    value: '${a.rating.toStringAsFixed(1)} ★',
                    trend: '${a.reviewCount} reviews')),
          ]),
          const SizedBox(height: 26),
          Text('PROFILE VIEWS THIS WEEK', style: AppType.label()),
          const SizedBox(height: 14),
          _WeeklyChart(points: a.weeklyViews),
          const SizedBox(height: 26),
          Text('MANAGE', style: AppType.label()),
          const SizedBox(height: 10),
          const Hairline(),
          for (final item in const [
            ('Edit business profile', Icons.edit_outlined),
            ('Offers & promotions', Icons.local_offer_outlined),
            ('Photos', Icons.photo_library_outlined),
            ('Operating hours', Icons.schedule_outlined),
          ])
            _ManageRow(
              label: item.$1,
              onTap: item.$1.startsWith('Offers')
                  ? () => context.push('/offers/${business.id}')
                  : null,
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

class _WeeklyChart extends StatelessWidget {
  const _WeeklyChart({required this.points});
  final List<WeeklyPoint> points;

  @override
  Widget build(BuildContext context) {
    final max = points.fold<int>(1, (m, p) => p.value > m ? p.value : m);
    final peak = points.indexOf(
        points.reduce((a, b) => a.value >= b.value ? a : b));
    return SizedBox(
      height: 110,
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
                    TweenAnimationBuilder<double>(
                      duration: Duration(milliseconds: 400 + i * 60),
                      curve: Curves.easeOutCubic,
                      tween: Tween(begin: 0, end: (points[i].value / max)),
                      builder: (_, v, __) => Container(
                        height: 80 * v.clamp(0.05, 1),
                        decoration: BoxDecoration(
                          color: i == peak
                              ? AppColors.gold
                              : AppColors.emerald.withValues(alpha: 0.33),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(points[i].label,
                        style: AppType.mono(
                            size: 9.5, color: AppColors.inkA(0.4))),
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
