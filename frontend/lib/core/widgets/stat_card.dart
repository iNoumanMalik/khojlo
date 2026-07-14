import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Dashboard metric tile: mono label, serif value, optional emerald trend.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.trend,
  });

  final String label;
  final String value;
  final String? trend;

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
          Text(label.toUpperCase(),
              style: AppType.label(color: AppColors.inkA(0.47))),
          const SizedBox(height: 6),
          Text(value, style: AppType.serif(size: 26)),
          if (trend != null) ...[
            const SizedBox(height: 4),
            Text(trend!, style: AppType.mono(size: 11, color: AppColors.emerald)),
          ],
        ],
      ),
    );
  }
}

/// Horizontal rating distribution bar (gold fill).
class RatingBar extends StatelessWidget {
  const RatingBar({super.key, required this.label, required this.pct});

  final String label;
  final int pct;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 10,
          child: Text(label,
              style: AppType.mono(size: 10.5, color: AppColors.inkA(0.53))),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 6,
              backgroundColor: AppColors.ink.withValues(alpha: 0.06),
              valueColor: const AlwaysStoppedAnimation(AppColors.gold),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 26,
          child: Text('$pct%',
              textAlign: TextAlign.right,
              style: AppType.mono(size: 10, color: AppColors.inkA(0.4))),
        ),
      ],
    );
  }
}
