import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/business.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
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
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.zero,
          children: [
            // hero
            SizedBox(
              height: 300,
              child: ImageTile(tone: b.tone, radius: 0, height: 300),
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
                          if (b.categoryName != null)
                            KhojloBadge(
                                label: b.categoryName!, tone: BadgeTone.emerald),
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
                  _Action(icon: Icons.call_rounded, label: 'Call'),
                  _Action(icon: Icons.directions_rounded, label: 'Directions'),
                  _Action(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Chat',
                      onTap: () => context.push('/conversation')),
                  _Action(icon: Icons.ios_share_rounded, label: 'Share'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (b.offers.isNotEmpty) _offers(b),
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
  const _Action({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.whiteA(0.7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.inkA(0.06)),
              ),
              child: Icon(icon, size: 20, color: AppColors.ink),
            ),
            const SizedBox(height: 6),
            Text(label,
                style: AppType.sans(size: 11, color: AppColors.inkA(0.6))),
          ],
        ),
      ),
    );
  }
}
