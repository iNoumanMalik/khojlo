import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/business.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';
import '../discovery/discovery_providers.dart';

/// Module 3 — "Surprise Me": a swipeable stack of every listed business, in a new
/// random order each time (uses /feed/surprise). Swipe or tap Skip for the next one;
/// after the last card, shuffle again.
class SurpriseScreen extends ConsumerStatefulWidget {
  const SurpriseScreen({super.key});

  @override
  ConsumerState<SurpriseScreen> createState() => _SurpriseScreenState();
}

class _SurpriseScreenState extends ConsumerState<SurpriseScreen> {
  int _index = 0;

  void _next() => setState(() => _index++);

  void _shuffleAgain() {
    setState(() => _index = 0);
    ref.invalidate(surpriseProvider);
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(surpriseProvider);
    final total = async.valueOrNull?.length ?? 0;
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
                      Expanded(
                        child: Column(
                          children: [
                            Text('SURPRISE ME', style: AppType.label()),
                            if (total > 0 && _index < total)
                              Text('${_index + 1} of $total',
                                  style: AppType.mono(
                                      size: 10.5, color: AppColors.inkA(0.45))),
                          ],
                        ),
                      ),
                      GlassIconButton(
                          icon: Icons.shuffle_rounded, size: 38, onTap: _shuffleAgain),
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
                    data: (list) => list.isEmpty
                        ? _message('Nothing to surprise you with yet')
                        : _index >= list.length
                            ? _finished(list.length)
                            : _stack(list),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _message(String text) => Center(
        child: Text(text, style: AppType.sans(color: AppColors.inkA(0.6))),
      );

  /// After the last card: every listed business has been shown once.
  Widget _finished(int total) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.auto_awesome, size: 36, color: AppColors.gold),
              const SizedBox(height: 14),
              Text('You’ve seen all $total places',
                  textAlign: TextAlign.center, style: AppType.serif(size: 22)),
              const SizedBox(height: 6),
              Text('Shuffle again for a new order.',
                  textAlign: TextAlign.center,
                  style: AppType.sans(size: 13, color: AppColors.inkA(0.6))),
              const SizedBox(height: 18),
              PrimaryButton(
                  label: 'Shuffle again',
                  icon: Icons.shuffle_rounded,
                  expand: false,
                  onTap: _shuffleAgain),
            ],
          ),
        ),
      );

  Widget _stack(List<BusinessCard> list) {
    final current = list[_index];
    final next = _index + 1 < list.length ? list[_index + 1] : null;
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            // Scales the fixed-size card down on short screens instead of overflowing.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30),
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    if (next != null)
                      Transform.translate(
                        offset: const Offset(0, 14),
                        child: Transform.rotate(
                          angle: 0.04,
                          child: _Card(business: next, faded: true),
                        ),
                      ),
                    Dismissible(
                      key: ValueKey('surprise-$_index-${current.id}'),
                      onDismissed: (_) => _next(),
                      child: GestureDetector(
                        onTap: () => context.push('/business/${current.id}'),
                        child: _Card(business: current),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
          child: Row(
            children: [
              Expanded(
                child: GhostButton(
                    label: 'Skip', tone: AppColors.inkA(0.6), onTap: _next),
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
    final meta = [
      business.ratingLabel,
      business.priceLabel,
      if (business.distanceLabel.isNotEmpty) business.distanceLabel,
    ].join('  ·  ');
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
            ImageTile(height: 220, tone: business.tone, radius: 18, photo: business.cover),
            const SizedBox(height: 14),
            Text(business.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.serif(size: 22, height: 1.15)),
            const SizedBox(height: 4),
            Text(business.typeLabel ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.sans(size: 12.5, color: AppColors.inkA(0.6))),
            const Spacer(),
            Text(meta,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.mono(size: 12, color: AppColors.inkA(0.7))),
          ],
        ),
      ),
    );
  }
}
