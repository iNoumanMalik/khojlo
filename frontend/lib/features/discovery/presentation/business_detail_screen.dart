import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/maps/map_service.dart';
import '../../../core/models/business.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/photo_viewer.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/widgets.dart';
import '../../account/account_providers.dart';
import '../../chat/chat_providers.dart';
import 'report_business_sheet.dart';
import '../../maps/map_providers.dart';
import '../../promotions/presentation/widgets/promo_widgets.dart';
import '../../reviews/presentation/business_reviews_section.dart';
import '../../reviews/reviews_providers.dart';
import '../../search/compare_controller.dart';
import '../data/discovery_repository.dart';
import '../discovery_providers.dart';

class BusinessDetailScreen extends ConsumerStatefulWidget {
  const BusinessDetailScreen({super.key, required this.id});
  final int id;

  @override
  ConsumerState<BusinessDetailScreen> createState() =>
      _BusinessDetailScreenState();
}

class _BusinessDetailScreenState extends ConsumerState<BusinessDetailScreen> {
  bool? _savedOverride;
  bool _saving = false;
  bool _openingChat = false;

  /// UC-13: open (or start) the conversation with this business. Owners see
  /// their customers' messages in the Chat tab instead.
  Future<void> _message(BusinessDetail b) async {
    if (b.isOwner) {
      context.go('/chat');
      return;
    }
    if (_openingChat) return;
    setState(() => _openingChat = true);
    try {
      final id = await openConversationWith(ref, b.id);
      if (mounted) context.push('/conversations/$id');
    } catch (e) {
      if (mounted) _snack(describeApiError(e));
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  /// Optimistic: the heart and the message change at once, and the server catches
  /// up in the background. If it fails, the heart goes back and says why.
  Future<void> _toggleSave(BusinessDetail b) async {
    if (_saving) return;
    final repo = ref.read(discoveryRepositoryProvider);
    final wasSaved = _savedOverride ?? b.isSaved;
    final saving = !wasSaved;
    setState(() {
      _saving = true;
      _savedOverride = saving;
    });
    _snack(saving ? 'Saved ${b.name}' : 'Removed from your saved places',
        actionLabel: saving ? 'View' : null,
        onAction: saving ? () => context.push('/saved') : null);
    try {
      saving ? await repo.save(b.id) : await repo.unsave(b.id);
      ref.invalidate(savedListsProvider);
    } catch (e) {
      if (!mounted) return;
      setState(() => _savedOverride = wasSaved);
      _snack(saving ? 'Couldn’t save ${b.name}. ${describeApiError(e)}' : describeApiError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _toggleCompare(BusinessDetail b) {
    final notifier = ref.read(compareSelectionProvider.notifier);
    final outcome = notifier.toggle(b);
    final count = ref.read(compareSelectionProvider).length;
    final message = switch (outcome) {
      CompareToggle.added => 'Added to compare ($count/${CompareController.max})',
      CompareToggle.removed => 'Removed from compare',
      CompareToggle.full =>
        'You can compare up to ${CompareController.max} places. Remove one first.',
    };
    final canView = count >= CompareController.min;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(message, style: AppType.sans(size: 13, color: Colors.white)),
        action: canView
            ? SnackBarAction(
                label: 'View',
                textColor: AppColors.gold,
                onPressed: () => context.push('/compare'),
              )
            : null,
      ));
  }

  void _snack(String message, {String? actionLabel, VoidCallback? onAction}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        backgroundColor: AppColors.ink,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(message, style: AppType.sans(size: 13, color: Colors.white)),
        action: actionLabel == null
            ? null
            : SnackBarAction(label: actionLabel, textColor: AppColors.gold, onPressed: onAction!),
      ));
  }

  /// Share the place through the phone's share sheet: what it is, where, and a map link.
  Future<void> _share(BusinessDetail b) async {
    final point = b.location;
    final lines = [
      '${b.name}${b.typeLabel != null ? ' · ${b.typeLabel}' : ''}',
      if (b.tagline.isNotEmpty) b.tagline,
      if (b.address.isNotEmpty) b.address,
      if (b.phone != null) 'Call: ${b.phone}',
      if (point != null)
        'Map: https://www.google.com/maps/search/?api=1&query=${point.latitude},${point.longitude}',
      'Found on Khojlo',
    ];
    try {
      await SharePlus.instance.share(ShareParams(text: lines.join('\n'), subject: b.name));
    } catch (_) {
      if (mounted) _snack('Couldn’t open sharing on this device.');
    }
  }

  /// Module 8: report the listing. It stays up until an admin decides (BR-13).
  Future<void> _report(BusinessDetail b) async {
    final result = await showReportBusinessSheet(context, b.name);
    if (result == null || !mounted) return;
    try {
      await ref.read(discoveryRepositoryProvider).report(b.id, result.$1, note: result.$2);
      _snack('Thanks for letting us know. Our team will take a look.');
    } catch (e) {
      if (mounted) _snack(describeApiError(e));
    }
  }

  Future<void> _call(BusinessDetail b) async {
    final phone = b.phone;
    if (phone == null) {
      _snack('${b.name} hasn’t added a phone number yet.');
      return;
    }
    final dialable = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final opened = await launchUrl(Uri(scheme: 'tel', path: dialable));
    if (!opened && mounted) _snack('Couldn’t open the dialer. The number is $phone.');
  }

  /// UC-9 alternative flow: navigation in Google Maps.
  Future<void> _directions(BusinessDetail b) async {
    final point = b.location;
    if (point == null) {
      _snack('${b.name} hasn’t pinned its location yet.');
      return;
    }
    final opened = await ref.read(mapServiceProvider).openDirections(point);
    if (!opened && mounted) _snack('Couldn’t open Google Maps on this device.');
  }

  /// Open the Map tab centred on this business.
  void _viewOnMap(BusinessDetail b) {
    final point = b.location;
    if (point == null) return;
    ref.read(mapFocusProvider.notifier).state = MapFocus(point, businessId: b.id);
    context.go('/map');
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(businessDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: async.when(
        skipLoadingOnRefresh: true,
        loading: () => _LoadingDetail(card: RecentCards.get(widget.id)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('Couldn’t load this place',
                  style: AppType.sans(color: AppColors.inkA(0.6))),
              const SizedBox(height: 12),
              GhostButton(
                  label: 'Try again',
                  expand: false,
                  onTap: () => ref.invalidate(businessDetailProvider(widget.id))),
              const SizedBox(height: 8),
              TextButton(onPressed: () => context.pop(), child: const Text('Go back')),
            ]),
          ),
        ),
        data: (b) => _content(b),
      ),
    );
  }

  Widget _content(BusinessDetail b) {
    final saved = _savedOverride ?? b.isSaved;
    // The review summary is fresher than the detail after you write a review.
    final reviews = ref.watch(reviewPreviewProvider(b.id)).valueOrNull?.summary;
    final average = reviews?.average ?? b.rating;
    final reviewCount = reviews?.count ?? b.reviewCount;
    final comparing = ref.watch(compareSelectionProvider).any((c) => c.id == b.id);
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            // hero: the cover photo (tap for the full gallery), or the tone gradient
            Semantics(
              image: b.photos.isNotEmpty,
              label: b.photos.isEmpty ? null : 'Photos of ${b.name}, open gallery',
              child: GestureDetector(
                onTap: b.photos.isEmpty ? null : () => showPhotoViewer(context, b.photos),
                child: ImageTile(tone: b.tone, radius: 0, height: 300, photo: b.cover),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -34),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: GlassSurface(
                  radius: 24,
                  opacity: 0.85,
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (b.typeLabel != null)
                            KhojloBadge(label: b.typeLabel!, tone: BadgeTone.emerald),
                          const Spacer(),
                          if (b.isVerified)
                            KhojloBadge(
                                label: 'Verified', tone: BadgeTone.gold),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(b.name, style: AppType.serif(size: 26)),
                      if (b.tagline.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(b.tagline,
                            style: AppType.sans(
                                size: 13.5, color: AppColors.inkA(0.6))),
                      ],
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => context.push(reviewsRoute(b.id, b.name)),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: reviewCount == 0
                                  ? const [
                                      _MetaChip(
                                          icon: Icons.reviews_outlined, label: 'No reviews yet'),
                                    ]
                                  : [
                                      _MetaChip(
                                          icon: Icons.star_rounded,
                                          label: average.toStringAsFixed(1)),
                                      const SizedBox(width: 8),
                                      _MetaChip(
                                          icon: Icons.reviews_outlined,
                                          label:
                                              '$reviewCount review${reviewCount == 1 ? '' : 's'}'),
                                    ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _MetaChip(
                              icon: Icons.attach_money_rounded,
                              label: b.priceLevel),
                        ],
                      ),
                      if (b.priceRange.isNotEmpty || b.isOpenNow != null) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            if (b.priceRange.isNotEmpty)
                              _MetaChip(icon: Icons.payments_outlined, label: b.priceRange),
                            if (b.isOpenNow != null)
                              _MetaChip(
                                icon: Icons.schedule_rounded,
                                label: [
                                  b.isOpenNow! ? 'Open now' : 'Closed now',
                                  if (b.todayHours != null) b.todayHours!,
                                ].join(' · '),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            // action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _Action(
                      icon: Icons.call_rounded,
                      label: 'Call',
                      dimmed: b.phone == null,
                      onTap: () => _call(b)),
                  _Action(
                      icon: Icons.directions_rounded,
                      label: 'Directions',
                      dimmed: b.location == null,
                      onTap: () => _directions(b)),
                  _Action(
                      icon: Icons.compare_arrows_rounded,
                      label: comparing ? 'Comparing' : 'Compare',
                      active: comparing,
                      onTap: () => _toggleCompare(b)),
                  _Action(
                      icon: Icons.ios_share_rounded,
                      label: 'Share',
                      onTap: () => _share(b)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (b.activeCampaign != null) _campaignStrip(b),
            if (b.offers.isNotEmpty) _offers(b),
            // The cover is already the hero, so the gallery appears once there's more.
            if (b.photos.length > 1) _gallery(b),
            _sectionTitle('The story'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                b.description.isEmpty
                    ? 'A fresh find on Khojlo — one of the newest spots worth your time.'
                    : b.description,
                style: AppType.sans(
                    size: 14, height: 1.6, color: AppColors.inkA(0.7)),
              ),
            ),
            if (b.services.isNotEmpty) ...[
              _sectionTitle('Services'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    for (final s in b.services)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(s.name,
                                    style: AppType.sans(
                                        size: 14, weight: FontWeight.w600))),
                            Text(s.price,
                                style: AppType.mono(
                                    size: 12, color: AppColors.inkA(0.6))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
            BusinessReviewsSection(businessId: b.id, businessName: b.name),
            _sectionTitle('Where'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _LocationCard(
                business: b,
                onViewOnMap: () => _viewOnMap(b),
                onDirections: () => _directions(b),
              ),
            ),
            if (b.phone != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                child: GestureDetector(
                  onTap: () => _call(b),
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      const Icon(Icons.call_rounded, size: 18, color: AppColors.emerald),
                      const SizedBox(width: 10),
                      Text(b.phone!, style: AppType.mono(size: 13, color: AppColors.ink)),
                      const Spacer(),
                      Text('Call',
                          style: AppType.sans(
                              size: 13, weight: FontWeight.w700, color: AppColors.emerald)),
                    ],
                  ),
                ),
              ),
            if (!b.isOwner)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 26, 20, 0),
                child: GestureDetector(
                  onTap: () => _report(b),
                  behavior: HitTestBehavior.opaque,
                  child: Row(children: [
                    Icon(Icons.flag_outlined, size: 16, color: AppColors.inkA(0.45)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text('Something wrong with this listing? Report it',
                          style: AppType.sans(size: 12.5, color: AppColors.inkA(0.55))),
                    ),
                  ]),
                ),
              ),
            const SizedBox(height: 140),
          ],
        ),
        // top back / save bar
        Positioned(
          top: 52,
          left: 20,
          right: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GlassIconButton(
                  icon: Icons.chevron_left_rounded,
                  onTap: () => context.pop()),
              GlassIconButton(
                icon: saved ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                onTap: () => _toggleSave(b),
              ),
            ],
          ),
        ),
        // bottom chat CTA
        Positioned(
          left: 20,
          right: 20,
          bottom: 28,
          child: PrimaryButton(
            label: b.isOwner ? 'View customer messages' : 'Message ${b.name}',
            tone: ButtonTone.ink,
            icon: Icons.chat_bubble_outline_rounded,
            loading: _openingChat,
            onTap: () => _message(b),
          ),
        ),
      ],
    );
  }

  Widget _offers(BusinessDetail b) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Offers'),
        SizedBox(
          height: OfferCoupon.height(context),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: b.offers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => OfferCoupon(
              offer: b.offers[i],
              width: 240,
              onTap: () => showOfferDetails(context, b.offers[i], businessName: b.name),
            ),
          ),
        ),
      ],
    );
  }

  /// "On now": the business's live promotional campaign.
  Widget _campaignStrip(BusinessDetail b) {
    final campaign = b.activeCampaign!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
      child: GestureDetector(
        onTap: () => context.push('/campaign/${campaign.id}'),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              AppColors.plum.withValues(alpha: 0.14),
              AppColors.gold.withValues(alpha: 0.1),
            ]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.plum.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department_rounded, color: AppColors.plum),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ON NOW',
                        style: AppType.mono(
                            size: 9.5, weight: FontWeight.w700, color: AppColors.plum)),
                    Text(campaign.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sans(size: 14.5, weight: FontWeight.w700)),
                  ],
                ),
              ),
              Text('See deals',
                  style: AppType.sans(size: 12.5, weight: FontWeight.w700, color: AppColors.plum)),
              const Icon(Icons.chevron_right_rounded, color: AppColors.plum),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gallery(BusinessDetail b) {
    const height = 150.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Gallery · ${b.photos.length} photos'),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: b.photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final photo = b.photos[i];
              // Close to each photo's own shape, within limits so the strip stays tidy.
              final width = (height * photo.aspectRatio).clamp(height * 0.66, height * 1.6);
              return Semantics(
                button: true,
                label: 'Photo ${i + 1} of ${b.photos.length}',
                child: GestureDetector(
                  onTap: () => showPhotoViewer(context, b.photos, initialIndex: i),
                  child: ImageTile(
                      photo: photo, tone: b.tone, width: width, height: height, radius: 16),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
        child: Text(t.toUpperCase(),
            style: AppType.mono(
                size: 10.5, color: AppColors.inkA(0.47), letterSpacing: 1.0)),
      );
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.gold),
        const SizedBox(width: 4),
        Text(label, style: AppType.mono(size: 11.5, color: AppColors.inkA(0.7))),
      ],
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    this.onTap,
    this.active = false,
    this.dimmed = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;

  /// Shown faded when the action isn't available (e.g. no phone number).
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: dimmed ? 0.45 : 1,
          child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: active ? AppColors.emerald : AppColors.whiteA(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.inkA(0.06)),
              ),
              child: Icon(icon, size: 20, color: active ? Colors.white : AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: AppType.sans(size: 11, color: AppColors.inkA(0.6))),
          ],
          ),
        ),
      ),
    );
  }
}


/// SDD Screen 3: the business's location on Google Maps (SDD Algorithm 12
/// `displayLocation()`), or "Location unavailable" (UC-9 exception) without a pin.
class _LocationCard extends ConsumerWidget {
  const _LocationCard({
    required this.business,
    required this.onViewOnMap,
    required this.onDirections,
  });

  final BusinessDetail business;
  final VoidCallback onViewOnMap;
  final VoidCallback onDirections;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b = business;
    final point = b.location;
    final address = b.address.isEmpty ? null : b.address;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Container(
        color: AppColors.whiteA(0.7),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 160,
              child: point == null
                  ? Container(
                      color: const Color(0xFFEFE9DC),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.location_off_outlined,
                              size: 28, color: AppColors.inkA(0.35)),
                          const SizedBox(height: 8),
                          Text('Location unavailable',
                              style: AppType.sans(size: 13.5, weight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text('This place hasn’t pinned itself on the map yet.',
                              style: AppType.sans(size: 12, color: AppColors.inkA(0.5))),
                        ],
                      ),
                    )
                  : Semantics(
                      button: true,
                      label: 'View ${b.name} on the map',
                      child: ref
                          .watch(mapServiceProvider)
                          .displayLocation(point, onTap: onViewOnMap),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  const Icon(Icons.place_outlined, size: 18, color: AppColors.emerald),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(address ?? 'No address added',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.sans(
                            size: 13,
                            color: address == null ? AppColors.inkA(0.45) : AppColors.ink)),
                  ),
                  if (point != null) ...[
                    TextButton(
                      onPressed: onViewOnMap,
                      child: Text('Map',
                          style: AppType.sans(
                              size: 12.5, weight: FontWeight.w700, color: AppColors.emerald)),
                    ),
                    TextButton(
                      onPressed: onDirections,
                      child: Text('Directions',
                          style: AppType.sans(
                              size: 12.5, weight: FontWeight.w700, color: AppColors.emerald)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// While the full profile loads: the photo, name and type already known from the
/// card that was tapped, so the page appears at once instead of a spinner.
class _LoadingDetail extends StatelessWidget {
  const _LoadingDetail({this.card});
  final BusinessCard? card;

  @override
  Widget build(BuildContext context) {
    final c = card;
    return Stack(children: [
      ListView(
        padding: EdgeInsets.zero,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          ImageTile(tone: c?.tone ?? 'gold', radius: 0, height: 300, photo: c?.cover),
          Transform.translate(
            offset: const Offset(0, -34),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.whiteA(0.92),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  if (c?.typeLabel != null)
                    KhojloBadge(label: c!.typeLabel!, tone: BadgeTone.emerald)
                  else
                    const SkeletonBox(width: 80, height: 20, radius: 999),
                  const SizedBox(height: 12),
                  if (c != null)
                    Text(c.name, style: AppType.serif(size: 26))
                  else
                    const SkeletonBox(width: 200, height: 26),
                  const SizedBox(height: 10),
                  const SkeletonBox(width: 220, height: 14),
                  const SizedBox(height: 12),
                  const SkeletonBox(width: 160, height: 24, radius: 999),
                ]),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: Column(children: [
              SkeletonBox(height: 64, radius: 16),
              SizedBox(height: 18),
              SkeletonBox(height: 90, radius: 16),
            ]),
          ),
        ],
      ),
      Positioned(
        top: 52,
        left: 20,
        child: GlassIconButton(
            icon: Icons.chevron_left_rounded, onTap: () => context.pop()),
      ),
    ]);
  }
}
