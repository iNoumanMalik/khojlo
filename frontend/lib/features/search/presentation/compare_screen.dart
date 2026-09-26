import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_service.dart';
import '../../../core/models/business.dart';
import '../../../core/models/search.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../compare_controller.dart';

/// Module 4 — side-by-side comparison of 2–3 places (SRS UC-5; SDD FR08, Algorithm 3).
///
/// Animated "A vs B vs C" cards on top, then one row per attribute with the best value
/// in each row highlighted.
class CompareScreen extends ConsumerWidget {
  const CompareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(compareSelectionProvider);
    final ready = selection.length >= CompareController.min;

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(
            title: 'Compare',
            subtitle: '${selection.length} of ${CompareController.max} places',
            onBack: () => context.canPop() ? context.pop() : context.go('/explore'),
            trailing: selection.isEmpty
                ? null
                : GestureDetector(
                    onTap: () => ref.read(compareSelectionProvider.notifier).clear(),
                    child: Text('Clear',
                        style: AppType.sans(
                            size: 12.5, weight: FontWeight.w700, color: AppColors.plum)),
                  ),
          ),
          Expanded(
            child: ready
                ? _CompareLoader(ids: [for (final b in selection) b.id])
                : _PickMore(selected: selection),
          ),
        ],
      ),
    );
  }
}

class _CompareLoader extends ConsumerWidget {
  const _CompareLoader({required this.ids});
  final List<int> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = ids.join(',');
    final async = ref.watch(compareResultProvider(key));
    return async.when(
      // keep showing the previous comparison while a new one loads
      skipLoadingOnReload: true,
      loading: () => const _CompareSkeleton(),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.compare_arrows_rounded, size: 40, color: AppColors.inkA(0.3)),
              const SizedBox(height: 12),
              Text('Couldn’t compare these places', style: AppType.serif(size: 20)),
              const SizedBox(height: 6),
              Text(describeApiError(e),
                  textAlign: TextAlign.center,
                  style: AppType.sans(size: 13, color: AppColors.inkA(0.55))),
              const SizedBox(height: 16),
              PrimaryButton(
                label: 'Try again',
                small: true,
                expand: false,
                onTap: () => ref.invalidate(compareResultProvider(key)),
              ),
            ],
          ),
        ),
      ),
      data: (result) => _CompareBody(result: result),
    );
  }
}

class _CompareBody extends ConsumerWidget {
  const _CompareBody({required this.result});
  final CompareResult result;

  static const _labelWidth = 76.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = result.items;
    final hasLocation = ref.watch(locationControllerProvider.select((s) => s.hasFix));
    final canAdd = items.length < CompareController.max;

    final rows = <_RowSpec>[
      _RowSpec('Price', CompareRow.price, (i) {
        final range = i.card.priceRange;
        return range.isEmpty
            ? _Cell(i.card.priceLevel)
            : _Cell(range, sub: i.card.priceLevel);
      }),
      _RowSpec('Rating', CompareRow.rating, (i) => i.card.rating > 0
          ? _Cell('★ ${i.card.rating.toStringAsFixed(1)}', sub: '${i.card.reviewCount} reviews')
          : const _Cell('—', sub: 'No ratings yet')),
      _RowSpec('Distance', CompareRow.distance, (i) => i.card.distanceKm != null
          ? _Cell(i.card.distanceLabel)
          : _Cell('—', sub: hasLocation ? 'No map pin' : null)),
      _RowSpec('Open now', CompareRow.openNow, (i) => switch (i.card.isOpenNow) {
            true => _Cell('Open', sub: i.card.todayHours),
            false => _Cell('Closed', sub: i.card.todayHours),
            null => const _Cell('—', sub: 'Hours not listed'),
          }),
      _RowSpec('Services', CompareRow.services, (i) => i.services.isEmpty
          ? const _Cell('—')
          : _Cell('${i.services.length} listed',
              sub: i.services.take(2).map((s) => s.name).join(', '))),
      _RowSpec('Offers', CompareRow.offers, (i) => i.activeOffers.isEmpty
          ? const _Cell('None')
          : _Cell('${i.activeOffers.length} active', sub: i.activeOffers.first)),
      _RowSpec('Category', null, (i) => _Cell(i.card.categoryName ?? '—')),
      _RowSpec('Saves', CompareRow.saves, (i) => _Cell('${i.card.saveCount}')),
      _RowSpec('Verified', null,
          (i) => _Cell(i.card.isVerified ? 'Yes' : 'Not yet')),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        // ── A vs B vs C ──
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) const _VsBadge(),
                Expanded(
                  child: _PlaceCard(
                    item: items[i],
                    onOpen: () => context.push('/business/${items[i].card.id}'),
                    onRemove: () =>
                        ref.read(compareSelectionProvider.notifier).remove(items[i].card.id),
                  )
                      .animate(delay: (90 * i).ms)
                      .fadeIn(duration: 320.ms)
                      .slideY(begin: 0.12, end: 0, curve: Curves.easeOutCubic)
                      .scaleXY(begin: 0.96, end: 1),
                ),
              ],
              if (canAdd) ...[
                const _VsBadge(muted: true),
                Expanded(child: _AddSlot(onTap: () => context.go('/explore'))),
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        // ── attribute rows ──
        for (var r = 0; r < rows.length; r++)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: r.isEven ? AppColors.ink.withValues(alpha: 0.03) : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _labelWidth,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, top: 7),
                    child: Text(rows[r].label.toUpperCase(),
                        style: AppType.mono(
                            size: 9.5,
                            weight: FontWeight.w600,
                            color: AppColors.inkA(0.5),
                            letterSpacing: 0.6)),
                  ),
                ),
                for (final item in items)
                  Expanded(
                    child: _CellView(
                      cell: rows[r].cell(item),
                      best: rows[r].row != null && result.isBest(rows[r].row!, item.card.id),
                    ),
                  ),
                if (canAdd) const Expanded(child: SizedBox()),
              ],
            ),
          ).animate(delay: (200 + 45 * r).ms).fadeIn(duration: 260.ms).slideX(begin: 0.04, end: 0),
        const SizedBox(height: 14),
        Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: AppColors.emerald.withValues(alpha: 0.5)),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Highlighted = best in that row. Rows where every place ties stay plain.',
                style: AppType.sans(size: 11.5, color: AppColors.inkA(0.5)),
              ),
            ),
          ],
        ),
        if (!hasLocation) ...[
          const SizedBox(height: 14),
          _LocationHint(),
        ],
        const SizedBox(height: 22),
        GhostButton(
          label: 'View on map · coming soon',
          icon: Icons.map_outlined,
          tone: AppColors.inkA(0.45),
          onTap: null,
        ),
      ],
    );
  }
}

class _RowSpec {
  const _RowSpec(this.label, this.row, this.cell);
  final String label;

  /// Row the backend can pick a winner for (null = informational only).
  final CompareRow? row;
  final _Cell Function(CompareItem item) cell;
}

class _Cell {
  const _Cell(this.value, {this.sub});
  final String value;
  final String? sub;
}

class _CellView extends StatelessWidget {
  const _CellView({required this.cell, required this.best});
  final _Cell cell;
  final bool best;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: best ? AppColors.emerald.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: best ? AppColors.emerald.withValues(alpha: 0.45) : Colors.transparent,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (best) ...[
                const Icon(Icons.check_circle_rounded, size: 12, color: AppColors.emerald),
                const SizedBox(width: 3),
              ],
              Flexible(
                child: Text(
                  cell.value,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.mono(
                    size: 12,
                    weight: FontWeight.w600,
                    color: best ? AppColors.emerald : AppColors.ink,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          if (cell.sub != null && cell.sub!.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              cell.sub!,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppType.sans(size: 10, color: AppColors.inkA(0.5)),
            ),
          ],
        ],
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.item, required this.onOpen, required this.onRemove});
  final CompareItem item;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final b = item.card;
    return GestureDetector(
      onTap: onOpen,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.whiteA(0.75),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.inkA(0.06)),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ImageTile(height: 78, tone: b.tone, radius: 12),
                Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: onRemove,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                          color: AppColors.whiteA(0.9), shape: BoxShape.circle),
                      child: Icon(Icons.close_rounded, size: 15, color: AppColors.inkA(0.7)),
                    ),
                  ),
                ),
                if (b.isNew)
                  const Positioned(
                    left: 5,
                    bottom: 5,
                    child: KhojloBadge(label: 'New', tone: BadgeTone.gold),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(b.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppType.serif(size: 14.5, height: 1.15)),
            const SizedBox(height: 3),
            Text(b.categoryName ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.mono(size: 9.5, color: AppColors.inkA(0.5))),
          ],
        ),
      ),
    );
  }
}

class _VsBadge extends StatelessWidget {
  const _VsBadge({this.muted = false});
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      child: Center(
        child: Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: muted ? AppColors.inkA(0.08) : AppColors.ink,
            boxShadow: muted
                ? null
                : [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.25),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Text('VS',
              style: AppType.mono(
                  size: 8.5,
                  weight: FontWeight.w700,
                  color: muted ? AppColors.inkA(0.4) : Colors.white,
                  letterSpacing: 0.4)),
        ).animate().scale(delay: 250.ms, duration: 300.ms, curve: Curves.easeOutBack),
      ),
    );
  }
}

class _AddSlot extends StatelessWidget {
  const _AddSlot({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.whiteA(0.35),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.inkA(0.14), width: 1.4),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_circle_outline_rounded, color: AppColors.inkA(0.4)),
            const SizedBox(height: 6),
            Text('Add a place',
                textAlign: TextAlign.center,
                style: AppType.sans(
                    size: 11.5, weight: FontWeight.w600, color: AppColors.inkA(0.5))),
          ],
        ),
      ),
    );
  }
}

class _LocationHint extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(locationControllerProvider);
    final notifier = ref.read(locationControllerProvider.notifier);
    return GestureDetector(
      onTap: location.isLocating ? null : () => notifier.refresh(prompt: true),
      child: Row(
        children: [
          Icon(Icons.near_me_outlined, size: 15, color: AppColors.inkA(0.5)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              location.isLocating
                  ? 'Finding your location…'
                  : 'Share your location to compare distances.',
              style: AppType.sans(
                  size: 12, weight: FontWeight.w600, color: AppColors.emerald),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown until two places are picked.
class _PickMore extends StatelessWidget {
  const _PickMore({required this.selected});
  final List<BusinessCard> selected;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.compare_arrows_rounded, size: 52, color: AppColors.gold)
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .slideX(begin: -0.06, end: 0.06, duration: 1200.ms, curve: Curves.easeInOut),
            const SizedBox(height: 16),
            Text(selected.isEmpty ? 'Nothing to compare yet' : 'Pick one more place',
                style: AppType.serif(size: 22)),
            const SizedBox(height: 8),
            Text(
              selected.isEmpty
                  ? 'Tap the circle next to 2 or 3 search results, or use “Compare” on a business page.'
                  : '${selected.first.name} is waiting. Choose one or two more to compare side by side.',
              textAlign: TextAlign.center,
              style: AppType.sans(size: 13, height: 1.5, color: AppColors.inkA(0.55)),
            ),
            const SizedBox(height: 20),
            PrimaryButton(
              label: 'Find places',
              tone: ButtonTone.emerald,
              small: true,
              expand: false,
              icon: Icons.search_rounded,
              onTap: () => context.go('/explore'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareSkeleton extends StatelessWidget {
  const _CompareSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
      children: [
        const Row(
          children: [
            Expanded(child: SkeletonBox(height: 140, radius: 18)),
            SizedBox(width: 26),
            Expanded(child: SkeletonBox(height: 140, radius: 18)),
          ],
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < 7; i++)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 9),
            child: SkeletonBox(height: 22),
          ),
      ],
    );
  }
}
