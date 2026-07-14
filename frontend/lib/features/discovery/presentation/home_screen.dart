import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/feed.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/auth_controller.dart';
import '../discovery_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feedAsync = ref.watch(feedProvider);
    final user = ref.watch(authControllerProvider).user;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: feedAsync.when(
        loading: () => const FeedSkeleton(),
        error: (e, _) => _FeedError(onRetry: () => ref.refresh(feedProvider)),
        data: (feed) => RefreshIndicator(
          color: AppColors.emerald,
          onRefresh: () async => ref.refresh(feedProvider.future),
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(feed: feed, initials: user?.initials ?? '?', tone: user?.avatarTone ?? 'gold'),
              _SearchRow(),
              const SizedBox(height: 18),
              _Categories(categories: feed.categories),
              const SizedBox(height: 8),
              for (final section in feed.sections) _Section(section: section),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.feed, required this.initials, required this.tone});
  final Feed feed;
  final String initials;
  final String tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 64, 22, 56),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.3, -1),
          end: Alignment(0.3, 1),
          colors: [AppColors.plum, Color(0xFF4E2137), AppColors.ink],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(feed.greeting.toUpperCase(),
                    style: AppType.mono(
                        size: 10.5,
                        color: AppColors.coral.withValues(alpha: 0.8),
                        letterSpacing: 1.6)),
              ),
              GestureDetector(
                onTap: () => context.push('/profile'),
                child: KhojloAvatar(initials: initials, tone: tone, size: 40),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(feed.headline,
              style: AppType.serif(size: 34, color: Colors.white, height: 1.1)),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }
}

class _SearchRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -30),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            Expanded(
              child: SearchPill(onTap: () => context.go('/explore')),
            ),
            const SizedBox(width: 10),
            GlassIconButton(
              icon: Icons.notifications_none_rounded,
              size: 48,
              showDot: true,
              onTap: () => context.push('/notifications'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({required this.categories});
  final List categories;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        children: [
          KhojloChip(label: 'All', active: true, onTap: () => context.go('/explore')),
          for (final c in categories) ...[
            const SizedBox(width: 10),
            KhojloChip(label: c.name, onTap: () => context.go('/explore')),
          ],
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.section});
  final FeedSection section;

  @override
  Widget build(BuildContext context) {
    if (section.businesses.isEmpty) return const SizedBox.shrink();
    return switch (section.layout) {
      'hero' => _HeroSection(section: section),
      'list' => _ListSection(section: section),
      _ => _HorizontalSection(section: section),
    };
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.section});
  final FeedSection section;

  @override
  Widget build(BuildContext context) {
    final b = section.businesses.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionEyebrow(label: section.title),
          const SizedBox(height: 12),
          BusinessHeroCard(business: b, onTap: () => context.push('/business/${b.id}')),
        ],
      ),
    );
  }
}

class _HorizontalSection extends StatelessWidget {
  const _HorizontalSection({required this.section});
  final FeedSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: SectionEyebrow(label: section.title),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 172,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: section.businesses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final b = section.businesses[i];
                return BusinessMiniCard(
                    business: b, onTap: () => context.push('/business/${b.id}'));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ListSection extends StatelessWidget {
  const _ListSection({required this.section});
  final FeedSection section;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title.toUpperCase(),
              style: AppType.mono(
                  size: 10.5,
                  color: AppColors.inkA(0.47),
                  letterSpacing: 1.0)),
          const SizedBox(height: 6),
          for (var i = 0; i < section.businesses.length; i++)
            BusinessListRow(
              business: section.businesses[i],
              showDivider: i != 0,
              onTap: () => context.push('/business/${section.businesses[i].id}'),
            ),
        ],
      ),
    );
  }
}

class _FeedError extends StatelessWidget {
  const _FeedError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.explore_off_rounded, size: 40, color: AppColors.inkA(0.3)),
            const SizedBox(height: 16),
            Text('Couldn’t load your feed',
                style: AppType.serif(size: 20)),
            const SizedBox(height: 8),
            Text('Make sure the backend is running, then try again.',
                textAlign: TextAlign.center,
                style: AppType.sans(size: 13, color: AppColors.inkA(0.5))),
            const SizedBox(height: 20),
            PrimaryButton(
                label: 'Retry',
                expand: false,
                small: true,
                onTap: onRetry),
          ],
        ),
      ),
    );
  }
}
