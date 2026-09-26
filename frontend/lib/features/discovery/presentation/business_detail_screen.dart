import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/models/business.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/photo_viewer.dart';
import '../../../core/widgets/widgets.dart';
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

  Future<void> _toggleSave(BusinessDetail b) async {
    setState(() => _saving = true);
    final repo = ref.read(discoveryRepositoryProvider);
    final currentlySaved = _savedOverride ?? b.isSaved;
    try {
      final res =
          currentlySaved ? await repo.unsave(b.id) : await repo.save(b.id);
      if (mounted) setState(() => _savedOverride = res.isSaved);
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

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(message, style: AppType.sans(size: 13, color: Colors.white)),
      ));
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

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(businessDetailProvider(widget.id));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: async.when(
        loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => Center(
          child: Text('Couldn’t load this place',
              style: AppType.sans(color: AppColors.inkA(0.6))),
        ),
        data: (b) => _content(b),
      ),
    );
  }

  Widget _content(BusinessDetail b) {
    final saved = _savedOverride ?? b.isSaved;
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
                          _MetaChip(
                              icon: Icons.star_rounded,
                              label: b.rating.toStringAsFixed(1)),
                          const SizedBox(width: 8),
                          _MetaChip(
                              icon: Icons.reviews_outlined,
                              label: '${b.reviewCount} reviews'),
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
                  _Action(icon: Icons.directions_rounded, label: 'Directions'),
                  _Action(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Chat',
                      onTap: () => context.push('/conversation')),
                  _Action(
                      icon: Icons.compare_arrows_rounded,
                      label: comparing ? 'Comparing' : 'Compare',
                      active: comparing,
                      onTap: () => _toggleCompare(b)),
                  _Action(icon: Icons.ios_share_rounded, label: 'Share'),
                ],
              ),
            ),
            const SizedBox(height: 24),
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
            _sectionTitle('Where'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: SizedBox(
                  height: 150,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(color: const Color(0xFFEFE9DC)),
                      const Center(
                        child: Icon(Icons.place_rounded,
                            color: AppColors.emerald, size: 34),
                      ),
                      Positioned(
                        left: 12,
                        bottom: 12,
                        child: Text(
                            b.address.isEmpty ? 'Nearby' : b.address,
                            style: AppType.mono(
                                size: 11, color: AppColors.inkA(0.7))),
                      ),
                    ],
                  ),
                ),
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
                onTap: _saving ? null : () => _toggleSave(b),
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
            label: 'Message ${b.name}',
            tone: ButtonTone.ink,
            icon: Icons.chat_bubble_outline_rounded,
            onTap: () => context.push('/conversation'),
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
          height: 96,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: b.offers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final o = b.offers[i];
              return Container(
                width: 240,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.gold.withValues(alpha: 0.18),
                    AppColors.gold.withValues(alpha: 0.05),
                  ]),
                  borderRadius: BorderRadius.circular(16),
                  border:
                      Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(o.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppType.sans(size: 13.5, weight: FontWeight.w700)),
                    Text(o.rangeLabel,
                        style: AppType.mono(
                            size: 10.5, color: AppColors.inkA(0.6))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
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
