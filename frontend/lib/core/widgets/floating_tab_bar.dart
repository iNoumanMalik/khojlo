import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'glass.dart';

class TabItem {
  const TabItem(this.label, this.icon);
  final String label;
  final IconData icon;
}

/// The floating glass dock — Home · Explore · Map · Chat · Business.
/// Matches the `TabBar` primitive from the bundle (rounded 26, blur, emerald active).
class FloatingTabBar extends StatelessWidget {
  const FloatingTabBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const items = <TabItem>[
    TabItem('Home', Icons.circle_outlined),
    TabItem('Explore', Icons.travel_explore_rounded),
    TabItem('Map', Icons.place_rounded),
    TabItem('Chat', Icons.chat_bubble_outline_rounded),
    TabItem('Business', Icons.storefront_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: GlassSurface(
        radius: 26,
        opacity: 0.6,
        blur: 20,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            for (var i = 0; i < items.length; i++)
              Expanded(child: _tab(i)),
          ],
        ),
      ),
    );
  }

  Widget _tab(int i) {
    final selected = i == currentIndex;
    final color = selected ? AppColors.emerald : AppColors.inkA(0.45);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onTap(i),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedScale(
            scale: selected ? 1.15 : 1.0,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
            child: Icon(items[i].icon, size: 20, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            items[i].label,
            style: AppType.sans(
              size: 9.5,
              weight: selected ? FontWeight.w700 : FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
