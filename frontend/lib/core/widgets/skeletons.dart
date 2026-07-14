import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../theme/app_colors.dart';

/// Shimmer skeleton block (the design forbids spinning loaders).
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.radius = 12,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.ink.withValues(alpha: 0.06),
      highlightColor: AppColors.ink.withValues(alpha: 0.02),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

/// Feed placeholder shown while the discovery feed loads.
class FeedSkeleton extends StatelessWidget {
  const FeedSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 120, 22, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SkeletonBox(width: 180, height: 28),
          const SizedBox(height: 20),
          const SkeletonBox(height: 50, radius: 999),
          const SizedBox(height: 24),
          const SkeletonBox(height: 230, radius: 26),
          const SizedBox(height: 24),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                const Expanded(child: SkeletonBox(height: 100, radius: 16)),
                if (i < 2) const SizedBox(width: 12),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
