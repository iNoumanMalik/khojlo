import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/business.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../business_providers.dart';
import '../data/business_repository.dart';

class OffersScreen extends ConsumerWidget {
  const OffersScreen({super.key, required this.businessId});
  final int businessId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offers = ref.watch(offersProvider(businessId));
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopBar(
            title: 'Offers & Promotions',
            onBack: () => Navigator.of(context).maybePop(),
            trailing: GestureDetector(
              onTap: () => _newOffer(context, ref),
              child: Text('+ New',
                  style: AppType.sans(
                      size: 12.5,
                      weight: FontWeight.w700,
                      color: AppColors.emerald)),
            ),
          ),
          Expanded(
            child: offers.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(color: AppColors.emerald)),
              error: (_, __) => Center(
                  child: Text('Couldn’t load offers',
                      style: AppType.sans(color: AppColors.inkA(0.6)))),
              data: (list) => list.isEmpty
                  ? _empty(context, ref)
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(22, 0, 22, 40),
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 14),
                      itemBuilder: (_, i) => _OfferCard(offer: list[i]),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty(BuildContext context, WidgetRef ref) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.local_offer_outlined,
                size: 38, color: AppColors.inkA(0.3)),
            const SizedBox(height: 14),
            Text('No offers yet', style: AppType.serif(size: 20)),
            const SizedBox(height: 8),
            Text('Create one to appear in more feeds.',
                style: AppType.sans(size: 13, color: AppColors.inkA(0.5))),
            const SizedBox(height: 18),
            PrimaryButton(
                label: 'Create offer',
                expand: false,
                small: true,
                onTap: () => _newOffer(context, ref)),
          ],
        ),
      );

  Future<void> _newOffer(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final title = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: const BoxDecoration(
            color: AppColors.cream,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: AppColors.inkA(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Text('New offer', style: AppType.serif(size: 22)),
              const SizedBox(height: 16),
              AppField(
                  label: 'Offer title',
                  controller: controller,
                  hint: '20% off before 8PM'),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Publish offer',
                tone: ButtonTone.emerald,
                onTap: () => Navigator.of(ctx).pop(controller.text.trim()),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (title != null && title.isNotEmpty) {
      await ref
          .read(businessRepositoryProvider)
          .createOffer(businessId, title: title);
      ref.invalidate(offersProvider(businessId));
    }
  }
}

class _OfferCard extends StatelessWidget {
  const _OfferCard({required this.offer});
  final Offer offer;

  @override
  Widget build(BuildContext context) {
    return Container(
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(offer.title,
                    style: AppType.sans(
                        size: 14.5, weight: FontWeight.w700, height: 1.3)),
              ),
              const SizedBox(width: 10),
              KhojloBadge(
                  label: offer.status,
                  tone: KhojloBadge.fromString(offer.tone)),
            ],
          ),
          if (offer.rangeLabel.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(offer.rangeLabel,
                style: AppType.mono(size: 11, color: AppColors.inkA(0.53))),
          ],
          const Hairline(margin: EdgeInsets.symmetric(vertical: 12)),
          Text('${offer.views} views · ${offer.redemptions} redemptions',
              style: AppType.mono(size: 11, color: AppColors.inkA(0.53))),
        ],
      ),
    );
  }
}
