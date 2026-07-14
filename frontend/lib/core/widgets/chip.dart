import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Category filter chip — glass when idle, solid emerald/plum with a glow when active.
class KhojloChip extends StatelessWidget {
  const KhojloChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
    this.activeTone = AppColors.emerald,
  });

  final String label;
  final bool active;
  final VoidCallback? onTap;
  final Color activeTone;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: active ? activeTone : AppColors.whiteA(0.55),
          borderRadius: BorderRadius.circular(999),
          border:
              active ? null : Border.all(color: AppColors.whiteA(0.6), width: 1),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: activeTone.withValues(alpha: 0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : [
                  BoxShadow(
                    color: AppColors.ink.withValues(alpha: 0.06),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? AppColors.whiteA(0.8) : AppColors.gold,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppType.sans(
                size: 13,
                weight: FontWeight.w600,
                color: active ? Colors.white : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
