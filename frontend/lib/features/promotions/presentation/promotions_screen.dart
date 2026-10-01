import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/business.dart';
import '../../../core/models/campaign.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../business/business_providers.dart';
import '../data/promotions_repository.dart';
import '../promotions_providers.dart';
import 'campaign_editor_screen.dart';
import 'offer_editor_screen.dart';
import 'widgets/promo_widgets.dart';

/// Business dashboard → Offers & promotions: individual deals (SRS FR-10, UC-11) and the
/// campaigns that promote them, kept visibly separate.
class PromotionsScreen extends ConsumerWidget {
  const PromotionsScreen({super.key, required this.businessId});
  final int businessId;

  void _snack(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(message, style: AppType.sans(size: 13, color: Colors.white)),
      ));
  }

  Future<void> _act(BuildContext context, WidgetRef ref, Future<void> Function() action,
      String done) async {
    try {
      await action();
      ref.read(promotionChangesProvider.notifier).state++;
      if (context.mounted) _snack(context, done);
    } catch (e) {
      if (context.mounted) _snack(context, describeApiError(e));
    }
  }

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cream,
        title: Text(title, style: AppType.serif(size: 20)),
        content: Text(body,
            style: AppType.sans(size: 13.5, height: 1.45, color: AppColors.inkA(0.7))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Delete',
                style: AppType.sans(weight: FontWeight.w700, color: AppColors.plum)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final business = ref.watch(ownerBusinessDetailProvider(businessId)).valueOrNull;
    final offers = ref.watch(ownerOffersProvider(businessId));
    final campaigns = ref.watch(ownerCampaignsProvider(businessId));
    final repo = ref.read(promotionsRepositoryProvider);
    final verified = business?.isVerified ?? true;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(
            title: 'Offers & promotions',
            subtitle: business?.name,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.emerald,
              onRefresh: () async => ref.read(promotionChangesProvider.notifier).state++,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                children: [
                  if (!verified) const _VerifyNote(),
                  _SectionHeader(
                    title: 'Offers',
                    subtitle: 'Create and manage individual deals.',
                    action: 'Create offer',
                    onAction: () => openOfferEditor(context, businessId: businessId),
                  ),
                  ...offers.when(
                    loading: () => const [_Loading()],
                    error: (e, _) => [_Error(message: describeApiError(e))],
                    data: (list) => list.isEmpty
                        ? const [
                            _Empty(
                                icon: Icons.local_offer_outlined,
                                text: 'No offers yet. An offer is the deal itself, like '
                                    '“20% off burgers” or “Buy 1 get 1 pizza”.'),
                          ]
                        : [
                            for (final o in list)
                              _OfferRow(
                                offer: o,
                                onTap: () =>
                                    openOfferEditor(context, businessId: businessId, existing: o),
                                onToggle: o.status == PromoStatus.expired
                                    ? null
                                    : () => _act(
                                          context,
                                          ref,
                                          () => repo.setOfferActive(businessId, o.id, !o.isActive),
                                          o.isActive ? 'Offer deactivated.' : 'Offer activated.',
                                        ),
                                onDelete: () async {
                                  if (!await _confirm(context, 'Delete this offer?',
                                      'It disappears from your profile and from any campaign '
                                      'that promotes it.')) {
                                    return;
                                  }
                                  if (context.mounted) {
                                    await _act(context, ref,
                                        () => repo.deleteOffer(businessId, o.id), 'Offer deleted.');
                                  }
                                },
                              ),
                          ],
                  ),
                  const SizedBox(height: 26),
                  _SectionHeader(
                    title: 'Promotional campaigns',
                    subtitle: 'Create a promotion that highlights one or more existing offers.',
                    action: 'Create campaign',
                    onAction: () => openCampaignEditor(context, businessId: businessId),
                  ),
                  ...campaigns.when(
                    loading: () => const [_Loading()],
                    error: (e, _) => [_Error(message: describeApiError(e))],
                    data: (list) => list.isEmpty
                        ? const [
                            _Empty(
                                icon: Icons.campaign_outlined,
                                text: 'No campaigns yet. A campaign promotes your offers for a '
                                    'period, like a “Weekend Food Festival”, with a banner on '
                                    'Khojlo’s home screen.'),
                          ]
                        : [
                            for (final c in list)
                              _CampaignRow(
                                campaign: c,
                                onTap: () => openCampaignEditor(context,
                                    businessId: businessId, existing: c),
                                onPreview: () => context.push('/campaign/${c.id}'),
                                onToggle: c.status == PromoStatus.expired
                                    ? null
                                    : () => _act(
                                          context,
                                          ref,
                                          () => repo.setPublished(businessId, c.id, !c.isPublished),
                                          c.isPublished
                                              ? 'Campaign unpublished.'
                                              : 'Campaign published.',
                                        ),
                                onDelete: () async {
                                  if (!await _confirm(context, 'Delete this campaign?',
                                      'Its banner comes down. Your offers stay as they are.')) {
                                    return;
                                  }
                                  if (context.mounted) {
                                    await _act(context, ref,
                                        () => repo.deleteCampaign(businessId, c.id),
                                        'Campaign deleted.');
                                  }
                                },
                              ),
                          ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerifyNote extends StatelessWidget {
  const _VerifyNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.gold.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_outlined, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Your business isn’t verified yet. You can prepare offers and campaigns as '
              'drafts; activating and publishing unlock once Khojlo verifies it.',
              style: AppType.sans(size: 12.5, height: 1.4, color: AppColors.inkA(0.75)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.action,
    required this.onAction,
  });
  final String title;
  final String subtitle;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppType.serif(size: 22)),
          const SizedBox(height: 2),
          Text(subtitle, style: AppType.sans(size: 12.5, color: AppColors.inkA(0.55))),
          const SizedBox(height: 10),
          GhostButton(
            label: '+ $action',
            tone: AppColors.emerald,
            small: true,
            onTap: onAction,
          ),
        ],
      ),
    );
  }
}

class _OfferRow extends StatelessWidget {
  const _OfferRow({
    required this.offer,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });
  final Offer offer;
  final VoidCallback onTap;
  final VoidCallback? onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    return _RowCard(
      onTap: onTap,
      leading: DealBadge(label: o.dealLabel, size: 10),
      title: o.title,
      subtitle: o.rangeLabel,
      status: o.status,
      menu: [
        ('edit', o.isActive ? 'Edit offer' : 'Edit draft', onTap),
        if (onToggle != null) ('toggle', o.isActive ? 'Deactivate' : 'Activate', onToggle!),
        ('delete', 'Delete', onDelete),
      ],
    );
  }
}

class _CampaignRow extends StatelessWidget {
  const _CampaignRow({
    required this.campaign,
    required this.onTap,
    required this.onPreview,
    required this.onToggle,
    required this.onDelete,
  });
  final Campaign campaign;
  final VoidCallback onTap;
  final VoidCallback onPreview;
  final VoidCallback? onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final c = campaign;
    return _RowCard(
      onTap: onTap,
      leading: SizedBox(
        width: 52,
        height: 40,
        child: ImageTile(tone: c.business.tone, photo: c.banner, radius: 10),
      ),
      title: c.name,
      subtitle: '${c.rangeLabel} · ${c.offers.length} offer${c.offers.length == 1 ? '' : 's'}',
      status: c.status,
      menu: [
        ('edit', 'Edit campaign', onTap),
        ('preview', 'Preview', onPreview),
        if (onToggle != null) ('toggle', c.isPublished ? 'Unpublish' : 'Publish', onToggle!),
        ('delete', 'Delete', onDelete),
      ],
    );
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.onTap,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.menu,
  });
  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String subtitle;
  final PromoStatus status;
  final List<(String, String, VoidCallback)> menu;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        decoration: BoxDecoration(
          color: AppColors.whiteA(0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.inkA(0.06)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.sans(size: 14, weight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Row(children: [
                    PromoStatusChip(status: status),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.mono(size: 10.5, color: AppColors.inkA(0.5))),
                    ),
                  ]),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More',
              icon: Icon(Icons.more_vert_rounded, color: AppColors.inkA(0.45)),
              color: AppColors.cream,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (key) {
                for (final item in menu) {
                  if (item.$1 == key) item.$3();
                }
              },
              itemBuilder: (_) => [
                for (final item in menu)
                  PopupMenuItem(
                    value: item.$1,
                    child: Text(item.$2,
                        style: AppType.sans(
                            size: 13.5,
                            color: item.$1 == 'delete' ? AppColors.plum : AppColors.ink)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.whiteA(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.inkA(0.06)),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.inkA(0.35)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: AppType.sans(size: 12.5, height: 1.4, color: AppColors.inkA(0.6))),
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald)),
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) =>
      Text(message, style: AppType.sans(size: 13, color: AppColors.plum));
}
