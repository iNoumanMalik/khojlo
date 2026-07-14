import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/business.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';
import '../discovery/discovery_providers.dart';

/// Module 3 — "Surprise Me" swipeable discovery stack (uses /feed/surprise).
class SurpriseScreen extends ConsumerStatefulWidget {
  const SurpriseScreen({super.key});

  @override
  ConsumerState<SurpriseScreen> createState() => _SurpriseScreenState();
}

class _SurpriseScreenState extends ConsumerState<SurpriseScreen> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(surpriseProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          const Positioned.fill(child: MeshBackground()),
          SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: Row(
                    children: [
                      GlassIconButton(
                          icon: Icons.chevron_left_rounded,
                          size: 38,
                          onTap: () => context.pop()),
                      const Spacer(),
                      Text('SURPRISE ME', style: AppType.label()),
                      const Spacer(),
                      const SizedBox(width: 38),
                    ],
                  ),
                ),
                Expanded(
                  child: async.when(
                    loading: () => const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.emerald)),
                    error: (_, __) => Center(
                        child: Text('Couldn’t shuffle right now',
                            style: AppType.sans(color: AppColors.inkA(0.6)))),
                    data: (list) =>
                        list.isEmpty ? _empty() : _stack(list),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
        child: Text('Nothing to surprise you with yet',
            style: AppType.sans(color: AppColors.inkA(0.6))),
      );

  Widget _stack(List<BusinessCard> list) {
    final current = list[_index % list.length];
    final next = list[(_index + 1) % list.length];
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: const Offset(0, 14),
                  child: Transform.rotate(
                    angle: 0.04,
                    child: _Card(business: next, faded: true),
                  ),
                ),
                Dismissible(
                  key: ValueKey(_index),
                  onDismissed: (_) => setState(() => _index++),
                  child: GestureDetector(
                    onTap: () => context.push('/business/${current.id}'),
                    child: _Card(business: current),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 20),
          child: Row(
            children: [
              Expanded(
                child: GhostButton(
                    label: 'Skip',
                    tone: AppColors.inkA(0.6),
                    onTap: () => setState(() => _index++)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'View',
                  tone: ButtonTone.ink,
                  onTap: () => context.push('/business/${current.id}'),
                ),
              ),
            ],
          ),
        ),
        Text('← swipe to explore →',
            style: AppType.mono(
                size: 10, color: AppColors.inkA(0.45), letterSpacing: 1.4)),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.business, this.faded = false});
  final BusinessCard business;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: faded ? 0.5 : 1,
      child: Container(
        width: 280,
        height: 380,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.22),
                blurRadius: 40,
                offset: const Offset(0, 24)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ImageTile(height: 220, tone: business.tone, radius: 18),
            const SizedBox(height: 14),
            Text(business.name, style: AppType.serif(size: 22)),
            const SizedBox(height: 4),
            Text(business.categoryName ?? '',
                style: AppType.sans(size: 12.5, color: AppColors.inkA(0.6))),
            const Spacer(),
            Row(
              children: [
                Text('★ ${business.rating.toStringAsFixed(1)}',
                    style: AppType.mono(size: 12, color: AppColors.inkA(0.7))),
                const SizedBox(width: 10),
                Text(business.priceLevel,
                    style: AppType.mono(size: 12, color: AppColors.inkA(0.7))),
                if (business.distanceLabel.isNotEmpty) ...[
                  const SizedBox(width: 10),
                  Text(business.distanceLabel,
                      style:
                          AppType.mono(size: 12, color: AppColors.inkA(0.7))),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
