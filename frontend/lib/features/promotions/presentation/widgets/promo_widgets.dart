import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/models/business.dart';
import '../../../../core/models/campaign.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

/// Draft / Scheduled / Active / Expired.
class PromoStatusChip extends StatelessWidget {
  const PromoStatusChip({super.key, required this.status});
  final PromoStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      PromoStatus.active => AppColors.emerald,
      PromoStatus.scheduled => AppColors.plum,
      PromoStatus.draft => AppColors.inkA(0.55),
      PromoStatus.expired => AppColors.inkA(0.35),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(status.label.toUpperCase(),
          style: AppType.mono(size: 9.5, weight: FontWeight.w700, color: color)),
    );
  }
}

/// The deal as a gold ticket: "20% OFF", "BUY 1 GET 1". Live offers shimmer (design:
/// "offer cards should shimmer").
class DealBadge extends StatelessWidget {
  const DealBadge({super.key, required this.label, this.size = 11, this.shimmer = false});
  final String label;
  final double size;
  final bool shimmer;

  @override
  Widget build(BuildContext context) {
    final badge = Container(
      padding: EdgeInsets.symmetric(horizontal: size * 0.8, vertical: size * 0.4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppColors.gold, Color(0xFFF0C46A)]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppType.mono(size: size, weight: FontWeight.w700, color: AppColors.ink)),
    );
    if (!shimmer) return badge;
    return badge
        .animate(onPlay: (c) => c.repeat())
        .shimmer(duration: 2400.ms, delay: 1200.ms, color: Colors.white.withValues(alpha: 0.55));
  }
}

/// A coupon-style offer tile ("Offers → animated coupon-style tiles").
class OfferCoupon extends StatelessWidget {
  const OfferCoupon({super.key, required this.offer, this.onTap, this.width});
  final Offer offer;
  final VoidCallback? onTap;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final live = offer.status == PromoStatus.active;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            AppColors.gold.withValues(alpha: 0.18),
            AppColors.gold.withValues(alpha: 0.05),
          ]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            DealBadge(label: offer.dealLabel, shimmer: live),
            const SizedBox(height: 8),
            Text(offer.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.sans(size: 13.5, weight: FontWeight.w700, height: 1.3)),
            const SizedBox(height: 4),
            Text(offer.rangeLabel,
                style: AppType.mono(size: 10.5, color: AppColors.inkA(0.6))),
          ],
        ),
      ),
    );
  }
}

/// An offer in full: deal, description, dates and terms.
Future<void> showOfferDetails(BuildContext context, Offer offer, {String? businessName}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 18),
              decoration: BoxDecoration(
                  color: AppColors.inkA(0.15), borderRadius: BorderRadius.circular(99)),
            ),
          ),
          DealBadge(label: offer.dealLabel, size: 13, shimmer: true),
          const SizedBox(height: 12),
          Text(offer.title, style: AppType.serif(size: 22)),
          if (businessName != null) ...[
            const SizedBox(height: 2),
            Text(businessName, style: AppType.sans(size: 13, color: AppColors.inkA(0.55))),
          ],
          const SizedBox(height: 10),
          Row(children: [
            const Icon(Icons.event_outlined, size: 16, color: AppColors.emerald),
            const SizedBox(width: 6),
            Text(offer.rangeLabel, style: AppType.mono(size: 11.5, color: AppColors.inkA(0.7))),
          ]),
          if (offer.description.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(offer.description,
                style: AppType.sans(size: 14, height: 1.5, color: AppColors.inkA(0.75))),
          ],
          if (offer.terms.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('TERMS & CONDITIONS', style: AppType.label()),
            const SizedBox(height: 6),
            Text(offer.terms,
                style: AppType.sans(size: 12.5, height: 1.45, color: AppColors.inkA(0.6))),
          ],
        ],
      ),
    ),
  );
}

/// A live campaign as a large Home banner: image, name, message, business, dates, CTA.
class CampaignBannerCard extends StatelessWidget {
  const CampaignBannerCard({super.key, required this.banner, required this.onTap});
  final CampaignBanner banner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b = banner;
    return Semantics(
      button: true,
      label: '${b.name} at ${b.businessName}. View offers',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ImageTile(tone: b.tone, photo: b.banner, radius: 0),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.black.withValues(alpha: 0.05), Colors.black.withValues(alpha: 0.72)],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.campaign_outlined, size: 12, color: Colors.white),
                            const SizedBox(width: 4),
                            Text('PROMOTION',
                                style: AppType.mono(
                                    size: 9, weight: FontWeight.w700, color: Colors.white)),
                          ]),
                        ),
                        const Spacer(),
                        if (b.topDeal != null) DealBadge(label: b.topDeal!, size: 10),
                      ],
                    ),
                    const Spacer(),
                    Text(b.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.serif(size: 22, color: Colors.white, height: 1.1)),
                    if (b.message.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(b.message,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(size: 13, color: Colors.white.withValues(alpha: 0.9))),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: Text('${b.businessName} · ${b.rangeLabel}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.mono(
                                  size: 10.5, color: Colors.white.withValues(alpha: 0.8))),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text('View offers',
                              style: AppType.sans(
                                  size: 12, weight: FontWeight.w700, color: AppColors.ink)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
