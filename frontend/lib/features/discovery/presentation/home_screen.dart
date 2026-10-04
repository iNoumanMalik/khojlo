import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_service.dart';
import '../../../core/maps/geo_repository.dart';
import '../../../core/models/business.dart';
import '../../../core/models/campaign.dart';
import '../../../core/models/feed.dart';
import '../../../core/models/photo.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/auth_controller.dart';
import '../../notifications/notifications_providers.dart';
import '../../promotions/presentation/widgets/promo_widgets.dart';
import '../../search/search_providers.dart';
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
        skipLoadingOnReload: true,
        loading: () => const FeedSkeleton(),
        // Keep the header (and its profile avatar) so the account stays reachable.
        error: (e, _) => ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              greeting: 'Welcome, explorer',
              headline: 'Discover what’s\nnew nearby',
              initials: user?.initials ?? '?',
              tone: user?.avatarTone ?? 'gold',
              photo: user?.avatar,
            ),
            const SizedBox(height: 24),
            _FeedError(onRetry: () => ref.refresh(feedProvider)),
          ],
        ),
        data: (feed) => _HeaderColorOverscroll(
          child: RefreshIndicator(
            color: AppColors.emerald,
            onRefresh: () async => ref.refresh(feedProvider.future),
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _HeaderWithSearch(
                  header: _Header(
                    greeting: feed.greeting,
                    headline: feed.headline,
                    initials: user?.initials ?? '?',
                    tone: user?.avatarTone ?? 'gold',
                    photo: user?.avatar,
                  ),
                ),
                const SizedBox(height: _HeaderWithSearch.overlap),
                if (feed.campaigns.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _CampaignCarousel(campaigns: feed.campaigns),
                ],
                const SizedBox(height: 18),
                _Categories(categories: feed.categories),
                const SizedBox(height: 8),
                for (final section in feed.sections) _Section(section: section),
                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// When the feed is pulled down past its top (the bounce), the gap above the
/// header is filled with the header's plum instead of showing the cream page.
class _HeaderColorOverscroll extends StatefulWidget {
  const _HeaderColorOverscroll({required this.child});
  final Widget child;

  @override
  State<_HeaderColorOverscroll> createState() => _HeaderColorOverscrollState();
}

class _HeaderColorOverscrollState extends State<_HeaderColorOverscroll> {
  final _gap = ValueNotifier<double>(0);

  @override
  void dispose() {
    _gap.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      final over = n.metrics.minScrollExtent - n.metrics.pixels;
      _gap.value = over > 0 ? over : 0;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ValueListenableBuilder<double>(
          valueListenable: _gap,
          builder: (_, gap, __) => Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: gap + 2,
            child: const ColoredBox(color: AppColors.plum),
          ),
        ),
        NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: widget.child,
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.greeting,
    required this.headline,
    required this.initials,
    required this.tone,
    this.photo,
  });
  final String greeting;
  final String headline;
  final String initials;
  final String tone;
  final Photo? photo;

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
                child: Text(
                  greeting.toUpperCase(),
                  style: AppType.mono(
                    size: 10.5,
                    color: AppColors.coral.withValues(alpha: 0.8),
                    letterSpacing: 1.6,
                  ),
                ),
              ),
              Semantics(
                button: true,
                label: 'Profile',
                child: GestureDetector(
                  onTap: () => context.push('/profile'),
                  child: KhojloAvatar(
                    initials: initials,
                    tone: tone,
                    size: 40,
                    photo: photo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            headline,
            style: AppType.serif(size: 34, color: Colors.white, height: 1.1),
          ),
          const SizedBox(height: 14),
          const _LocationIndicator(),
        ],
      ),
    );
  }
}

/// SDD Screen 1 "Location Indicator": the area the user is in, used for the Nearby
/// row. Checks silently (no permission prompt) until the user taps it.
class _LocationIndicator extends ConsumerStatefulWidget {
  const _LocationIndicator();

  @override
  ConsumerState<_LocationIndicator> createState() => _LocationIndicatorState();
}

class _LocationIndicatorState extends ConsumerState<_LocationIndicator> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(locationControllerProvider.notifier).ensureChecked();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationControllerProvider);
    final label = ref.watch(locationLabelProvider).valueOrNull;
    final text = !location.hasFix
        ? (location.isLocating
              ? 'Finding your location…'
              : 'Turn on location for places near you')
        : (label == null || label.isEmpty)
        ? 'Using your current location'
        : 'Near $label';
    return Semantics(
      button: true,
      label: location.hasFix ? '$text. Open the map' : text,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () {
          if (location.hasFix) {
            context.go('/map');
          } else if (!location.isLocating) {
            ref.read(locationControllerProvider.notifier).refresh(prompt: true);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                location.hasFix
                    ? Icons.near_me_rounded
                    : Icons.location_searching_rounded,
                size: 14,
                color: AppColors.coral,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sans(
                    size: 12.5,
                    weight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The header with the search row overlapping its bottom edge.
///
/// A Stack rather than `Transform.translate`: a translated widget only receives
/// taps inside its original, untranslated box, which left most of the search bar
/// and the bell dead.
class _HeaderWithSearch extends StatelessWidget {
  const _HeaderWithSearch({required this.header});
  final Widget header;

  /// How far the search row reaches up into the header.
  static const overlap = 30.0;
  static const _rowHeight = 48.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: _rowHeight - overlap),
          child: header,
        ),
        const Positioned(left: 0, right: 0, bottom: 0, child: _SearchRow()),
      ],
    );
  }
}

class _SearchRow extends ConsumerWidget {
  const _SearchRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          Expanded(
            // One tap to the Explore tab with the keyboard up (SRS USE-1).
            child: SearchPill(
              onTap: () {
                context.go('/explore');
                ref.read(searchFocusRequestProvider.notifier).state++;
              },
            ),
          ),
          const SizedBox(width: 10),
          GlassIconButton(
            icon: Icons.notifications_none_rounded,
            size: 48,
            showDot: ref.watch(unreadNotificationsProvider) > 0,
            onTap: () => context.push('/notifications'),
          ),
        ],
      ),
    );
  }
}

class _Categories extends ConsumerWidget {
  const _Categories({required this.categories});
  final List<Category> categories;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final search = ref.read(searchControllerProvider.notifier);
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        children: [
          KhojloChip(
            label: 'All',
            active: true,
            onTap: () {
              search.reset();
              context.go('/explore');
            },
          ),
          for (final c in categories) ...[
            const SizedBox(width: 10),
            KhojloChip(
              label: c.name,
              emoji: c.emoji,
              onTap: () {
                search.browseCategory(c.slug);
                context.go('/explore');
              },
            ),
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
          BusinessHeroCard(
            business: b,
            onTap: () => context.push('/business/${b.id}'),
          ),
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
            // Cards with a "Promotion" badge are taller; size the row to fit them.
            height: section.businesses.any((b) => b.activeCampaign != null)
                ? BusinessMiniCard.heightWithBadge
                : BusinessMiniCard.height,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 22),
              itemCount: section.businesses.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, i) {
                final b = section.businesses[i];
                return BusinessMiniCard(
                  business: b,
                  onTap: () => context.push('/business/${b.id}'),
                );
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
          Text(
            section.title.toUpperCase(),
            style: AppType.mono(
              size: 10.5,
              color: AppColors.inkA(0.47),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 6),
          for (var i = 0; i < section.businesses.length; i++)
            BusinessListRow(
              business: section.businesses[i],
              showDivider: i != 0,
              onTap: () =>
                  context.push('/business/${section.businesses[i].id}'),
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
            Icon(
              Icons.explore_off_rounded,
              size: 40,
              color: AppColors.inkA(0.3),
            ),
            const SizedBox(height: 16),
            Text('Couldn’t load your feed', style: AppType.serif(size: 20)),
            const SizedBox(height: 8),
            Text(
              'Make sure the backend is running, then try again.',
              textAlign: TextAlign.center,
              style: AppType.sans(size: 13, color: AppColors.inkA(0.5)),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Retry',
              expand: false,
              small: true,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

/// Live promotional campaigns as swipeable banners at the top of the discovery feed.
/// Banner → campaign details → offers → business.
class _CampaignCarousel extends StatefulWidget {
  const _CampaignCarousel({required this.campaigns});
  final List<CampaignBanner> campaigns;

  @override
  State<_CampaignCarousel> createState() => _CampaignCarouselState();
}

class _CampaignCarouselState extends State<_CampaignCarousel> {
  final _pages = PageController(viewportFraction: 0.9);
  int _page = 0;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final campaigns = widget.campaigns;
    return Column(
      children: [
        SizedBox(
          height: 196,
          child: PageView.builder(
            controller: _pages,
            itemCount: campaigns.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: CampaignBannerCard(
                banner: campaigns[i],
                onTap: () => context.push('/campaign/${campaigns[i].id}'),
              ),
            ),
          ),
        ),
        if (campaigns.length > 1) ...[
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < campaigns.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page
                        ? AppColors.emerald
                        : AppColors.inkA(0.15),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
