import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'glass.dart';

/// Oversized frosted search pill. Static display element that routes to Search
/// on tap (the Explore tab hosts the real input).
class SearchPill extends StatelessWidget {
  const SearchPill({
    super.key,
    this.text = 'Search hidden gems...',
    this.onTap,
    this.active = false,
  });

  final String text;
  final VoidCallback? onTap;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: GlassSurface(
        radius: 999,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          children: [
            Icon(Icons.search_rounded, size: 19, color: AppColors.inkA(0.4)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: AppType.sans(
                  size: 14,
                  weight: active ? FontWeight.w600 : FontWeight.w500,
                  color: active ? AppColors.ink : AppColors.inkA(0.53),
                ),
              ),
            ),
            if (active)
              Icon(Icons.close_rounded, size: 16, color: AppColors.inkA(0.53)),
          ],
        ),
      ),
    );
  }
}
