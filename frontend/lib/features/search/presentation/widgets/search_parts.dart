import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../../core/location/location_service.dart';
import '../../../../core/models/search.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

/// Glass chip for recent / popular searches.
class QueryChip extends StatelessWidget {
  const QueryChip({super.key, required this.label, required this.onTap, this.icon});
  final String label;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.whiteA(0.62),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.whiteA(0.75)),
          boxShadow: [
            BoxShadow(
                color: AppColors.ink.withValues(alpha: 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: AppColors.inkA(0.45)),
              const SizedBox(width: 6),
            ],
            Text(label, style: AppType.sans(size: 13, weight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

/// Removable active-filter chips ("Open now ×") plus "Clear all".
class ActiveFilterChips extends StatelessWidget {
  const ActiveFilterChips({
    super.key,
    required this.chips,
    required this.onRemove,
    required this.onClearAll,
  });

  final List<ActiveFilter> chips;
  final ValueChanged<ActiveFilter> onRemove;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final chip in chips) ...[
            GestureDetector(
              onTap: () => onRemove(chip),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 7, 10, 7),
                decoration: BoxDecoration(
                  color: AppColors.emerald,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.emerald.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(chip.label,
                        style: AppType.sans(
                            size: 12.5, weight: FontWeight.w700, color: Colors.white)),
                    const SizedBox(width: 5),
                    Icon(Icons.close_rounded, size: 14, color: AppColors.whiteA(0.85)),
                  ],
                ),
              ),
            ).animate().fadeIn(duration: 200.ms).scaleXY(begin: 0.9, end: 1),
            const SizedBox(width: 8),
          ],
          if (chips.length > 1)
            Center(
              child: GestureDetector(
                onTap: onClearAll,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Text('Clear all',
                      style: AppType.sans(
                          size: 12.5, weight: FontWeight.w700, color: AppColors.plum)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Best match ▾" menu.
class SortMenuButton extends StatelessWidget {
  const SortMenuButton({
    super.key,
    required this.value,
    required this.onSelected,
    required this.hasLocation,
  });

  final SearchSort value;
  final ValueChanged<SearchSort> onSelected;
  final bool hasLocation;

  @override
  Widget build(BuildContext context) {
    final shown = value == SearchSort.distance && !hasLocation ? SearchSort.relevance : value;
    return PopupMenuButton<SearchSort>(
      initialValue: shown,
      onSelected: onSelected,
      color: AppColors.cream,
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      tooltip: 'Sort results',
      itemBuilder: (_) => [
        for (final sort in SearchSort.values)
          PopupMenuItem(
            value: sort,
            enabled: sort != SearchSort.distance || hasLocation,
            child: Row(
              children: [
                Expanded(
                  child: Text(sort.label,
                      style: AppType.sans(
                          size: 13.5,
                          weight: sort == shown ? FontWeight.w700 : FontWeight.w500,
                          color: sort != SearchSort.distance || hasLocation
                              ? AppColors.ink
                              : AppColors.inkA(0.35))),
                ),
                if (sort == SearchSort.distance && !hasLocation)
                  Text('needs location',
                      style: AppType.mono(size: 9.5, color: AppColors.inkA(0.4)))
                else if (sort == shown)
                  const Icon(Icons.check_rounded, size: 16, color: AppColors.emerald),
              ],
            ),
          ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_vert_rounded, size: 16, color: AppColors.inkA(0.6)),
            const SizedBox(width: 4),
            Text(shown.label,
                style: AppType.sans(
                    size: 12.5, weight: FontWeight.w700, color: AppColors.inkA(0.7))),
            Icon(Icons.expand_more_rounded, size: 16, color: AppColors.inkA(0.6)),
          ],
        ),
      ),
    );
  }
}

/// The results digest in the design's "AI summary" slot (rule-based for now).
class ResultsSummaryCard extends StatelessWidget {
  const ResultsSummaryCard({super.key, required this.summary, required this.relaxed});
  final String summary;
  final bool relaxed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.emerald.withValues(alpha: 0.12),
          AppColors.emerald.withValues(alpha: 0.03),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.emerald.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.emerald, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (relaxed) ...[
                  Text('No place matched every word, so here are the closest matches.',
                      style: AppType.sans(
                          size: 12.5, weight: FontWeight.w700, color: AppColors.emerald)),
                  const SizedBox(height: 4),
                ],
                Text(summary,
                    style: AppType.sans(size: 12.5, height: 1.45, color: AppColors.inkA(0.72))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Friendly "nothing found" state with a gently swaying compass.
class SearchEmptyState extends StatelessWidget {
  const SearchEmptyState({
    super.key,
    required this.hasFilters,
    required this.onClearFilters,
    required this.ideas,
    required this.onIdea,
  });

  final bool hasFilters;
  final VoidCallback onClearFilters;
  final List<String> ideas;
  final ValueChanged<String> onIdea;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.explore_outlined, size: 52, color: AppColors.gold)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .rotate(begin: -0.04, end: 0.04, duration: 1400.ms, curve: Curves.easeInOut),
          const SizedBox(height: 16),
          Text('Nothing here yet', style: AppType.serif(size: 22)),
          const SizedBox(height: 8),
          Text(
            hasFilters
                ? 'No places match all of your filters. Try removing one.'
                : 'No places match that search. Try a broader word.',
            textAlign: TextAlign.center,
            style: AppType.sans(size: 13, height: 1.5, color: AppColors.inkA(0.55)),
          ),
          if (hasFilters) ...[
            const SizedBox(height: 18),
            PrimaryButton(
                label: 'Clear filters',
                small: true,
                expand: false,
                tone: ButtonTone.emerald,
                onTap: onClearFilters),
          ],
          if (ideas.isNotEmpty) ...[
            const SizedBox(height: 26),
            Text('PEOPLE ARE SEARCHING FOR', style: AppType.label()),
            const SizedBox(height: 12),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final idea in ideas.take(6))
                  QueryChip(label: idea, onTap: () => onIdea(idea)),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class SearchErrorState extends StatelessWidget {
  const SearchErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.inkA(0.3)),
          const SizedBox(height: 14),
          Text('Search is taking a break', style: AppType.serif(size: 20)),
          const SizedBox(height: 6),
          Text(message,
              textAlign: TextAlign.center,
              style: AppType.sans(size: 13, color: AppColors.inkA(0.55))),
          const SizedBox(height: 18),
          PrimaryButton(label: 'Try again', small: true, expand: false, onTap: onRetry),
        ],
      ),
    );
  }
}

/// Invites the user to share their location (for distances and "near me").
class LocationPromptCard extends StatelessWidget {
  const LocationPromptCard({
    super.key,
    required this.status,
    required this.onEnable,
    required this.onOpenSettings,
  });

  final LocationStatus status;
  final VoidCallback onEnable;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final blocked = status == LocationStatus.deniedForever;
    final off = status == LocationStatus.serviceDisabled;
    final locating = status == LocationStatus.locating;
    final text = blocked
        ? 'Location is blocked for Khojlo. Allow it in Settings to see distances.'
        : off
            ? 'Turn on location services to see how far places are.'
            : 'Share your location to see distances and places near you.';

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.gold.withValues(alpha: 0.16),
          AppColors.gold.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.near_me_rounded, color: Color(0xFF8A5B15), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text,
                style: AppType.sans(size: 12.5, height: 1.4, weight: FontWeight.w600)),
          ),
          const SizedBox(width: 8),
          PrimaryButton(
            label: blocked ? 'Settings' : (locating ? 'Locating…' : 'Use location'),
            small: true,
            expand: false,
            tone: ButtonTone.gold,
            loading: locating,
            onTap: blocked ? onOpenSettings : onEnable,
          ),
        ],
      ),
    );
  }
}

/// Typeahead suggestions under the search field.
class SuggestionList extends StatelessWidget {
  const SuggestionList({super.key, required this.suggestions, required this.onTap});
  final List<SearchSuggestion> suggestions;
  final ValueChanged<SearchSuggestion> onTap;

  IconData _icon(SuggestionType type) => switch (type) {
        SuggestionType.business => Icons.storefront_rounded,
        SuggestionType.category => Icons.category_rounded,
        SuggestionType.service => Icons.sell_outlined,
      };

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 20,
      opacity: 0.85,
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        children: [
          for (var i = 0; i < suggestions.length; i++)
            GestureDetector(
              onTap: () => onTap(suggestions[i]),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(_icon(suggestions[i].type), size: 17, color: AppColors.emerald),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(suggestions[i].label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.sans(size: 14, weight: FontWeight.w600)),
                    ),
                    if (suggestions[i].sublabel != null)
                      Text(suggestions[i].sublabel!,
                          style: AppType.mono(size: 10.5, color: AppColors.inkA(0.45))),
                  ],
                ),
              ),
            )
                .animate(delay: (30 * i).ms)
                .fadeIn(duration: 180.ms)
                .slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }
}
