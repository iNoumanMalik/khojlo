import 'package:flutter/material.dart';

import '../../../../core/models/business.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

/// A search result: thumbnail, name, "0.4 km · Rs 800–2,500 · ★ 4.7 · open", badges,
/// and a selection circle for comparison (SDD Screen 2 "Selection Indicator").
class SearchResultRow extends StatelessWidget {
  const SearchResultRow({
    super.key,
    required this.business,
    required this.selected,
    required this.onTap,
    required this.onToggleCompare,
    this.showDivider = true,
  });

  final BusinessCard business;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggleCompare;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final b = business;
    // Non-breaking spaces keep "★ 4.7", "0.4 km" and "Rs 800" together when the line wraps.
    String glued(String part) => part.replaceAll(' ', ' ');
    final meta = [
      if (b.distanceLabel.isNotEmpty) glued(b.distanceLabel),
      glued(b.priceLabel),
      if (b.rating > 0) glued('★ ${b.rating.toStringAsFixed(1)}'),
    ].join(' · ');
    final metaStyle = AppType.mono(size: 11.5, color: AppColors.inkA(0.55));

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: showDivider
              ? Border(top: BorderSide(color: AppColors.inkA(0.07)))
              : null,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              height: 64,
              child: ImageTile(tone: b.tone, radius: 14, photo: b.cover),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(b.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.serif(size: 17.5)),
                  const SizedBox(height: 3),
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(text: meta),
                      if (b.openLabel.isNotEmpty) ...[
                        const TextSpan(text: ' · '),
                        TextSpan(
                          text: b.openLabel,
                          style: metaStyle.copyWith(
                            color: b.isOpenNow == true ? AppColors.emerald : AppColors.plum,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: metaStyle,
                  ),
                  if (b.isNew || b.hasOffer || b.isVerified) ...[
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (b.isNew) const KhojloBadge(label: 'New', tone: BadgeTone.gold),
                        if (b.hasOffer) const KhojloBadge(label: 'Offer', tone: BadgeTone.plum),
                        if (b.isVerified)
                          const KhojloBadge(label: 'Verified', tone: BadgeTone.emerald),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            Semantics(
              button: true,
              selected: selected,
              label: selected ? 'Remove from compare' : 'Add to compare',
              child: GestureDetector(
                onTap: onToggleCompare,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    curve: Curves.easeOutBack,
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? AppColors.emerald : Colors.transparent,
                      border: Border.all(
                        color: selected ? AppColors.emerald : AppColors.inkA(0.22),
                        width: 1.6,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppColors.emerald.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: selected
                        ? const Icon(Icons.check_rounded, size: 17, color: Colors.white)
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Placeholder rows while results load (the design forbids spinners).
class SearchResultsSkeleton extends StatelessWidget {
  const SearchResultsSkeleton({super.key, this.rows = 5});
  final int rows;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < rows; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                const SkeletonBox(width: 64, height: 64, radius: 14),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 140 + (i % 3) * 30, height: 16),
                      const SizedBox(height: 8),
                      const SkeletonBox(width: 190, height: 11),
                      const SizedBox(height: 8),
                      const SkeletonBox(width: 90, height: 16, radius: 999),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
