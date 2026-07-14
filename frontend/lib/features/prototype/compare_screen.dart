import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/business.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';
import 'mock_data.dart';

/// Module 4 — side-by-side comparison (prototype).
class CompareScreen extends StatelessWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final places = Mock.places;
    final rows = <({String label, String Function(BusinessCard) value})>[
      (label: 'Rating', value: (b) => '★ ${b.rating}'),
      (label: 'Reviews', value: (b) => '${b.reviewCount}'),
      (label: 'Price', value: (b) => b.priceLevel),
      (label: 'Distance', value: (b) => b.distanceLabel),
      (label: 'Saves', value: (b) => '${b.saveCount}'),
      (label: 'Category', value: (b) => b.categoryName ?? '—'),
    ];

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(title: 'Compare places', subtitle: 'Up to 3', onBack: () => context.pop()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const SizedBox(width: 84),
                for (final b in places)
                  Expanded(
                    child: Column(
                      children: [
                        ImageTile(height: 70, tone: b.tone, radius: 14),
                        const SizedBox(height: 8),
                        Text(b.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.sans(
                                size: 11.5, weight: FontWeight.w700)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final row in rows)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      border: Border(
                          top: BorderSide(color: AppColors.inkA(0.06))),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 84,
                          child: Text(row.label.toUpperCase(),
                              style: AppType.label()),
                        ),
                        for (final b in places)
                          Expanded(
                            child: Center(
                              child: Text(row.value(b),
                                  style: AppType.mono(
                                      size: 12.5,
                                      color: AppColors.ink)),
                            ),
                          ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Pick Brew & Bloom',
                  tone: ButtonTone.emerald,
                  onTap: () => context.push('/business/1'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
