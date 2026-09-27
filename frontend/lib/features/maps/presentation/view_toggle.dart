import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';

/// "List | Map" switch shown on Explore and the Map tab. Both share one search, so
/// switching keeps the keyword and filters.
class ViewToggle extends StatelessWidget {
  const ViewToggle({super.key, required this.showingMap});
  final bool showingMap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColors.whiteA(0.7),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: AppColors.inkA(0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Segment(
            icon: Icons.view_agenda_outlined,
            label: 'List',
            active: !showingMap,
            onTap: () => context.go('/explore'),
          ),
          _Segment(
            icon: Icons.map_outlined,
            label: 'Map',
            active: showingMap,
            onTap: () => context.go('/map'),
          ),
        ],
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? Colors.white : AppColors.inkA(0.6);
    return Semantics(
      button: true,
      selected: active,
      label: 'Show as $label',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: active ? null : onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.ink : Colors.transparent,
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: AppType.sans(size: 12, weight: FontWeight.w700, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
