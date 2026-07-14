import 'package:flutter/material.dart';

import '../models/business.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'image_tile.dart';

/// Compact vertical business card (image + name + rating/distance) used in
/// horizontal carousels.
class BusinessMiniCard extends StatelessWidget {
  const BusinessMiniCard({
    super.key,
    required this.business,
    this.onTap,
    this.width = 150,
  });

  final BusinessCard business;
  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImageTile(
                height: 100,
                tone: business.tone,
                radius: 16,
                imageUrl: business.images1st),
            const SizedBox(height: 8),
            Text(business.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.serif(size: 14.5)),
            const SizedBox(height: 2),
            Text(
              '★ ${business.rating.toStringAsFixed(1)}'
              '${business.distanceLabel.isNotEmpty ? ' · ${business.distanceLabel}' : ''}',
              style: AppType.mono(size: 10.5, color: AppColors.inkA(0.47)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-width editorial hero card (image + gradient overlay + name/tagline).
class BusinessHeroCard extends StatelessWidget {
  const BusinessHeroCard({super.key, required this.business, this.onTap});

  final BusinessCard business;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          ImageTile(
              height: 230,
              tone: business.tone,
              radius: 26,
              imageUrl: business.images1st),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.8),
                  ],
                ),
              ),
            ),
          ),
          if (business.distanceLabel.isNotEmpty)
            Positioned(
              top: 14,
              right: 14,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.whiteA(0.85),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(business.distanceLabel,
                    style: AppType.mono(size: 11)),
              ),
            ),
          Positioned(
            left: 18,
            right: 18,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(business.name,
                    style: AppType.serif(size: 24, color: Colors.white)),
                if (business.tagline.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(business.tagline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.sans(
                          size: 12.5, color: AppColors.whiteA(0.8))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Horizontal list row (thumbnail + name + meta).
class BusinessListRow extends StatelessWidget {
  const BusinessListRow({
    super.key,
    required this.business,
    this.onTap,
    this.showDivider = true,
  });

  final BusinessCard business;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(
                  top: BorderSide(color: AppColors.ink.withValues(alpha: 0.07)))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: ImageTile(
                  tone: business.tone,
                  radius: 14,
                  imageUrl: business.images1st),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(business.name, style: AppType.serif(size: 18)),
                  const SizedBox(height: 3),
                  Text(
                    '★ ${business.rating.toStringAsFixed(1)}'
                    '${business.distanceLabel.isNotEmpty ? ' · ${business.distanceLabel}' : ''}'
                    ' · ${business.priceLevel}',
                    style: AppType.mono(size: 11.5, color: AppColors.inkA(0.53)),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: AppColors.inkA(0.33)),
          ],
        ),
      ),
    );
  }
}

extension on BusinessCard {
  // Mock data has no photos yet — cards fall back to the tone gradient.
  String? get images1st => null;
}
