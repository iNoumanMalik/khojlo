import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/campaign.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../promotions_providers.dart';
import 'widgets/promo_widgets.dart';

/// A promotional campaign for customers: banner, business, description, message, dates,
/// its live offers, featured services and terms, then on to the business.
/// Banner → campaign → offers → business profile.
class CampaignScreen extends ConsumerWidget {
  const CampaignScreen({super.key, required this.campaignId});
  final int campaignId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(campaignProvider(campaignId));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => _Ended(message: describeApiError(e)),
        data: (c) => _Content(campaign: c),
      ),
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.campaign});
  final Campaign campaign;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    final b = c.business;
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 260,
          pinned: true,
          backgroundColor: AppColors.cream,
          leading: Padding(
            padding: const EdgeInsets.all(8),
            child: GlassIconButton(
              icon: Icons.arrow_back_rounded,
              size: 40,
              onTap: () => context.canPop() ? context.pop() : context.go('/home'),
            ),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                ImageTile(tone: b.tone, photo: c.banner, radius: 0),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black.withValues(alpha: 0.1), Colors.black.withValues(alpha: 0.7)],
                    ),
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 20,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('PROMOTION · ${c.rangeLabel.toUpperCase()}',
                          style: AppType.mono(
                              size: 10, weight: FontWeight.w700,
                              color: Colors.white.withValues(alpha: 0.85))),
                      const SizedBox(height: 6),
                      Text(c.name,
                          style: AppType.serif(size: 30, color: Colors.white, height: 1.05)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 40),
          sliver: SliverList.list(children: [
            if (!c.isVisible)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(children: [
                  PromoStatusChip(status: c.status),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('Only you can see this right now.',
                        style: AppType.sans(size: 12.5, color: AppColors.inkA(0.55))),
                  ),
                ]),
              ),
            GestureDetector(
              onTap: () => context.push('/business/${b.id}'),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: ImageTile(tone: b.tone, photo: b.cover, radius: 12),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(b.name, style: AppType.sans(size: 15, weight: FontWeight.w700)),
                        Text([if (b.typeLabel != null) b.typeLabel!, b.ratingLabel].join(' · '),
                            style: AppType.mono(size: 10.5, color: AppColors.inkA(0.55))),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.inkA(0.35)),
                ],
              ),
            ),
            if (c.message.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text(c.message, style: AppType.serif(size: 20, color: AppColors.emerald)),
            ],
            if (c.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(c.description,
                  style: AppType.sans(size: 14, height: 1.55, color: AppColors.inkA(0.72))),
            ],
            const SizedBox(height: 22),
            Text('AVAILABLE OFFERS', style: AppType.label()),
            const SizedBox(height: 10),
            for (final (i, o) in c.offers.indexed)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: OfferCoupon(
                  offer: o,
                  onTap: () => showOfferDetails(context, o, businessName: b.name),
                ).animate(delay: (60 * i).ms).fadeIn(duration: 250.ms).slideX(begin: 0.05, end: 0),
              ),
            if (c.services.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text('FEATURED', style: AppType.label()),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in c.services)
                    KhojloChip(
                        label: s.price.isEmpty ? s.name : '${s.name} · ${s.price}', dense: true),
                ],
              ),
            ],
            if (c.terms.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text('TERMS & CONDITIONS', style: AppType.label()),
              const SizedBox(height: 6),
              Text(c.terms,
                  style: AppType.sans(size: 12.5, height: 1.45, color: AppColors.inkA(0.6))),
            ],
            const SizedBox(height: 26),
            PrimaryButton(
              label: 'View ${b.name}',
              icon: Icons.storefront_outlined,
              tone: ButtonTone.emerald,
              onTap: () => context.push('/business/${b.id}'),
            ),
          ]),
        ),
      ],
    );
  }
}

class _Ended extends StatelessWidget {
  const _Ended({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: GlassIconButton(
                icon: Icons.arrow_back_rounded,
                size: 40,
                onTap: () => context.canPop() ? context.pop() : context.go('/home'),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.event_busy_outlined, size: 40, color: AppColors.inkA(0.3)),
                    const SizedBox(height: 12),
                    Text('This promotion isn’t running', style: AppType.serif(size: 20)),
                    const SizedBox(height: 6),
                    Text(message,
                        textAlign: TextAlign.center,
                        style: AppType.sans(size: 13, color: AppColors.inkA(0.55))),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
