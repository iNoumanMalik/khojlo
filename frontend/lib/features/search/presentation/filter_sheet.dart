import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/location/location_service.dart';
import '../../../core/models/search.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../business/business_providers.dart';
import '../search_providers.dart';
import 'widgets/search_parts.dart';

/// Opens the filter sheet; resolves to the new filters, or null if dismissed.
Future<SearchFilters?> showFilterSheet(BuildContext context, SearchFilters current) {
  return showModalBottomSheet<SearchFilters>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    backgroundColor: Colors.transparent,
    barrierColor: AppColors.ink.withValues(alpha: 0.35),
    builder: (_) => FilterSheet(initial: current),
  );
}

/// Glass filter sheet from the design bundle: price, budget, rating, distance, open now,
/// offers, verified, categories, and a live "Show N results" button.
class FilterSheet extends ConsumerStatefulWidget {
  const FilterSheet({super.key, required this.initial});
  final SearchFilters initial;

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late SearchFilters _draft = widget.initial;

  // Slider positions while dragging; the result count refreshes when the drag ends.
  RangeValues? _budgetDrag;
  double? _radiusDrag;

  static const _anyDistance = 26.0; // slider stop meaning "no distance limit"
  static const _ratings = <double?>[null, 3.5, 4.0, 4.5];

  void _update(SearchFilters next) => setState(() => _draft = next);

  @override
  Widget build(BuildContext context) {
    final location = ref.watch(locationControllerProvider);
    final categories = ref.watch(categoriesProvider);
    final count = ref.watch(filterPreviewCountProvider(_draft));
    final maxHeight = MediaQuery.of(context).size.height * 0.88;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cream.withValues(alpha: 0.97),
              border: Border.all(color: AppColors.whiteA(0.8)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.inkA(0.2), borderRadius: BorderRadius.circular(2)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 16, 22, 4),
                  child: Row(
                    children: [
                      Text('Filters',
                          style: AppType.sans(size: 16, weight: FontWeight.w700)),
                      const Spacer(),
                      GestureDetector(
                        onTap: _draft.hasFilters
                            ? () => _update(_draft.withoutFilters())
                            : null,
                        child: Text('Reset',
                            style: AppType.sans(
                                size: 12.5,
                                weight: FontWeight.w700,
                                color: _draft.hasFilters
                                    ? AppColors.plum
                                    : AppColors.inkA(0.3))),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(22, 8, 22, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Price'),
                        _tiers(),
                        _label('Budget · ${_budgetText()}'),
                        _budget(),
                        _label('Rating'),
                        _rating(),
                        _label('Distance · ${_distanceText(location.hasFix)}'),
                        _distance(location),
                        const SizedBox(height: 8),
                        _toggle('Open now', 'Only places open at this moment', _draft.openNow,
                            (v) => _update(_draft.copyWith(openNow: v))),
                        _toggle('Has an offer', 'Running a discount or deal', _draft.hasOffer,
                            (v) => _update(_draft.copyWith(hasOffer: v))),
                        _toggle('Verified only', 'Checked by the Khojlo team',
                            _draft.verifiedOnly,
                            (v) => _update(_draft.copyWith(verifiedOnly: v))),
                        const Hairline(margin: EdgeInsets.symmetric(vertical: 10)),
                        _label('Category'),
                        categories.when(
                          loading: () => const SkeletonBox(height: 36, radius: 999),
                          error: (_, __) => Text('Couldn’t load categories',
                              style: AppType.sans(size: 12.5, color: AppColors.inkA(0.5))),
                          data: (list) => Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final c in list)
                                KhojloChip(
                                  label: c.name,
                                  active: _draft.categories.contains(c.slug),
                                  onTap: () {
                                    final next = {..._draft.categories};
                                    next.contains(c.slug)
                                        ? next.remove(c.slug)
                                        : next.add(c.slug);
                                    _update(_draft.copyWith(categories: next));
                                  },
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 4, 22, 16),
                    child: PrimaryButton(
                      tone: ButtonTone.ink,
                      label: count.when(
                        data: (n) => n == 0
                            ? 'No places match'
                            : 'Show $n result${n == 1 ? '' : 's'}',
                        loading: () => 'Counting places…',
                        error: (_, __) => 'Show results',
                      ),
                      onTap: count.valueOrNull == 0
                          ? null
                          : () => Navigator.of(context).pop(_draft),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(text.toUpperCase(), style: AppType.label()),
      );

  // ── price tiers (multi-select) ──
  static const _tierOptions = ['\$', '\$\$', '\$\$\$'];

  Widget _tiers() {
    return _segments(
      labels: _tierOptions,
      mono: true,
      isActive: (i) => _draft.priceLevels.contains(_tierOptions[i]),
      onTap: (i) {
        final tier = _tierOptions[i];
        final next = {..._draft.priceLevels};
        next.contains(tier) ? next.remove(tier) : next.add(tier);
        _update(_draft.copyWith(priceLevels: next));
      },
    );
  }

  /// Segmented control in the bundle's style: white pill on a soft track.
  Widget _segments({
    required List<String> labels,
    required bool Function(int index) isActive,
    required ValueChanged<int> onTap,
    bool mono = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.ink.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: isActive(i),
                child: GestureDetector(
                  onTap: () => onTap(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isActive(i) ? Colors.white : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: isActive(i)
                          ? [
                              BoxShadow(
                                color: AppColors.ink.withValues(alpha: 0.12),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        labels[i],
                        style: mono
                            ? AppType.mono(
                                size: 13.5,
                                weight: FontWeight.w600,
                                color: isActive(i) ? AppColors.ink : AppColors.inkA(0.4))
                            : AppType.sans(
                                size: 12.5,
                                weight: FontWeight.w700,
                                color: isActive(i) ? AppColors.ink : AppColors.inkA(0.45)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── budget (PKR range) ──
  RangeValues get _budgetValues =>
      _budgetDrag ??
      RangeValues(
        (_draft.minPrice ?? 0).toDouble(),
        (_draft.maxPrice ?? BudgetRange.max).toDouble(),
      );

  String _budgetText() {
    final v = _budgetValues;
    final min = v.start <= 0 ? null : v.start.round();
    final max = v.end >= BudgetRange.max ? null : v.end.round();
    return SearchFilters.budgetLabel(min, max);
  }

  Widget _budget() {
    return SliderTheme(
      data: _sliderTheme(context),
      child: RangeSlider(
        values: _budgetValues,
        min: 0,
        max: BudgetRange.max.toDouble(),
        divisions: BudgetRange.max ~/ BudgetRange.step,
        onChanged: (v) => setState(() => _budgetDrag = v),
        onChangeEnd: (v) {
          setState(() => _budgetDrag = null);
          _update(_draft.copyWith(
            minPrice: () => v.start <= 0 ? null : v.start.round(),
            maxPrice: () => v.end >= BudgetRange.max ? null : v.end.round(),
          ));
        },
      ),
    );
  }

  // ── rating (single choice, one line) ──
  Widget _rating() {
    return _segments(
      labels: [for (final r in _ratings) r == null ? 'Any' : '★ ${_ratingLabel(r)}+'],
      isActive: (i) => _draft.minRating == _ratings[i],
      onTap: (i) => _update(_draft.copyWith(minRating: () => _ratings[i])),
    );
  }

  static String _ratingLabel(double r) =>
      r == r.roundToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);

  // ── distance ──
  double get _radiusValue => _radiusDrag ?? (_draft.radiusKm ?? _anyDistance);

  String _distanceText(bool hasFix) {
    if (!hasFix) return 'needs your location';
    final v = _radiusValue;
    return v >= _anyDistance ? 'any distance' : 'under ${v.round()} km';
  }

  Widget _distance(LocationState location) {
    if (!location.hasFix) {
      final notifier = ref.read(locationControllerProvider.notifier);
      return LocationPromptCard(
        status: location.status,
        onEnable: () => notifier.refresh(prompt: true),
        onOpenSettings: notifier.openSettings,
      );
    }
    return SliderTheme(
      data: _sliderTheme(context),
      child: Slider(
        value: _radiusValue,
        min: 1,
        max: _anyDistance,
        divisions: (_anyDistance - 1).round(),
        onChanged: (v) => setState(() => _radiusDrag = v),
        onChangeEnd: (v) {
          setState(() => _radiusDrag = null);
          _update(_draft.copyWith(radiusKm: () => v >= _anyDistance ? null : v.roundToDouble()));
        },
      ),
    );
  }

  Widget _toggle(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return MergeSemantics(
      child: Semantics(
        toggled: value,
        label: title,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: _toggleRow(title, subtitle, value, onChanged),
        ),
      ),
    );
  }

  Widget _toggleRow(String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppType.sans(size: 14, weight: FontWeight.w600)),
                Text(subtitle,
                    style: AppType.sans(size: 11.5, color: AppColors.inkA(0.5))),
              ],
            ),
          ),
          KhojloToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }

  static SliderThemeData _sliderTheme(BuildContext context) => SliderTheme.of(context).copyWith(
        trackHeight: 6,
        activeTrackColor: AppColors.gold,
        inactiveTrackColor: AppColors.ink.withValues(alpha: 0.08),
        thumbColor: Colors.white,
        overlayColor: AppColors.gold.withValues(alpha: 0.16),
        activeTickMarkColor: Colors.transparent,
        inactiveTickMarkColor: Colors.transparent,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
        rangeThumbShape: const RoundRangeSliderThumbShape(enabledThumbRadius: 10, elevation: 3),
        showValueIndicator: ShowValueIndicator.never,
      );
}
