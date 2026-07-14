import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../business_providers.dart';
import 'dashboard_screen.dart';

/// Business tab — the consumer CTA before the user owns a business, or the
/// owner dashboard once they do.
class BusinessTabScreen extends ConsumerWidget {
  const BusinessTabScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myBusinessesProvider);
    return mine.when(
      loading: () => const Scaffold(
        backgroundColor: AppColors.cream,
        body: Center(child: CircularProgressIndicator(color: AppColors.emerald)),
      ),
      // A customer account gets a 403 → still show the CTA to upsell.
      error: (_, __) => const _GrowCta(),
      data: (businesses) =>
          businesses.isEmpty ? const _GrowCta() : DashboardScreen(business: businesses.first),
    );
  }
}

class _GrowCta extends StatelessWidget {
  const _GrowCta();

  static const _benefits = [
    ('Get listed in minutes', 'Add your details, photos and hours — no approval wait.'),
    ('Reach nearby customers organically',
        'Show up in discovery feeds without paying for placement.'),
    ('Manage everything from your phone',
        'Offers, messages and insights, all in one dashboard.'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 40),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.3, -1),
                end: Alignment(0.3, 1),
                colors: [AppColors.emerald, Color(0xFF123F34)],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('FOR BUSINESS OWNERS',
                    style: AppType.mono(
                        size: 10.5,
                        color: AppColors.coral.withValues(alpha: 0.85),
                        letterSpacing: 1.6)),
                const SizedBox(height: 10),
                Text('Own a business?\nGet discovered.',
                    style: AppType.serif(
                        size: 32, color: Colors.white, height: 1.1)),
                const SizedBox(height: 12),
                Text(
                  'List on Khojlo and reach people looking for exactly what you offer — no ad spend required.',
                  style: AppType.sans(
                      size: 13.5,
                      height: 1.55,
                      color: AppColors.whiteA(0.8)),
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Register your business',
                  tone: ButtonTone.gold,
                  expand: false,
                  onTap: () => context.push('/register-business'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 140),
            child: Column(
              children: [
                for (var i = 0; i < _benefits.length; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : Border(
                              top: BorderSide(
                                  color: AppColors.ink.withValues(alpha: 0.06))),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                              color: AppColors.gold, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_benefits[i].$1,
                                  style: AppType.sans(
                                      size: 14, weight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(_benefits[i].$2,
                                  style: AppType.sans(
                                      size: 12.5,
                                      height: 1.5,
                                      color: AppColors.inkA(0.53))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
