import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/business.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// "Active promotion" on business cards; tapping it opens the campaign.
class PromotionBadge extends StatelessWidget {
  const PromotionBadge({super.key, required this.campaign, this.compact = false, this.onDark = false});
  final CampaignRef campaign;
  final bool compact;

  /// Over a photo (hero cards): white background so it stays readable.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Active promotion: ${campaign.name}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: () => context.push('/campaign/${campaign.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: onDark ? AppColors.whiteA(0.9) : AppColors.plum.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(99),
            border: Border.all(color: AppColors.plum.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.local_fire_department_rounded, size: 12, color: AppColors.plum),
              const SizedBox(width: 3),
              Flexible(
                child: Text(compact ? 'Promotion' : 'Active promotion',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.mono(size: 9.5, weight: FontWeight.w700, color: AppColors.plum)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
