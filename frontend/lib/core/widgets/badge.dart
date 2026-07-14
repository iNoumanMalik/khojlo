import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

enum BadgeTone { emerald, gold, plum, ink }

/// Small pill badge — "Verified", offer status, etc.
class KhojloBadge extends StatelessWidget {
  const KhojloBadge({super.key, required this.label, this.tone = BadgeTone.emerald});

  final String label;
  final BadgeTone tone;

  (Color, Color) get _colors => switch (tone) {
        BadgeTone.emerald =>
          (AppColors.emerald, AppColors.emerald.withValues(alpha: 0.09)),
        BadgeTone.gold =>
          (const Color(0xFF8A5B15), AppColors.gold.withValues(alpha: 0.16)),
        BadgeTone.plum => (AppColors.plum, AppColors.plum.withValues(alpha: 0.09)),
        BadgeTone.ink =>
          (AppColors.inkA(0.6), AppColors.ink.withValues(alpha: 0.05)),
      };

  static BadgeTone fromString(String s) => switch (s.toLowerCase()) {
        'gold' => BadgeTone.gold,
        'plum' => BadgeTone.plum,
        'ink' => BadgeTone.ink,
        _ => BadgeTone.emerald,
      };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(label,
          style: AppType.sans(size: 10.5, weight: FontWeight.w700, color: fg)),
    );
  }
}
