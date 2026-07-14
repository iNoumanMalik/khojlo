import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Gradient circular avatar with serif initials.
class KhojloAvatar extends StatelessWidget {
  const KhojloAvatar({
    super.key,
    required this.initials,
    this.tone = 'gold',
    this.size = 44,
  });

  final String initials;
  final String tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: AppColors.gradientFor(tone),
        ),
      ),
      child: Text(
        initials,
        style: AppType.serif(size: size * 0.38, color: Colors.white),
      ),
    );
  }
}
