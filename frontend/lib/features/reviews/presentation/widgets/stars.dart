import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/models/review.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';

/// Five stars filled to [rating] (halves shown for averages like 4.5).
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.rating, this.size = 14});

  final double rating;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            Icon(
              rating >= i
                  ? Icons.star_rounded
                  : rating >= i - 0.5
                      ? Icons.star_half_rounded
                      : Icons.star_outline_rounded,
              size: size,
              color: rating >= i - 0.5 ? AppColors.gold : AppColors.inkA(0.2),
            ),
        ],
      ),
    );
  }
}

/// Tap-to-rate stars with a label ("Loved it") under them (UC-7 "enter rating").
class StarPicker extends StatelessWidget {
  const StarPicker({super.key, required this.value, required this.onChanged});

  /// 0 while nothing is picked.
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 1; i <= 5; i++)
              Semantics(
                button: true,
                selected: value == i,
                label: '$i star${i == 1 ? '' : 's'}: ${starLabels[i]}',
                excludeSemantics: true,
                child: GestureDetector(
                  key: ValueKey('star-$i'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    onChanged(i);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: AnimatedScale(
                      scale: value == i ? 1.18 : 1,
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOutBack,
                      child: Icon(
                        value >= i ? Icons.star_rounded : Icons.star_outline_rounded,
                        size: 40,
                        color: value >= i ? AppColors.gold : AppColors.inkA(0.22),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: Text(
            value == 0 ? 'Tap a star to rate' : starLabels[value]!,
            key: ValueKey(value),
            style: AppType.sans(
                size: 13,
                weight: FontWeight.w600,
                color: value == 0 ? AppColors.inkA(0.45) : AppColors.emerald),
          ),
        ),
      ],
    );
  }
}
