import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/location/location_service.dart';
import '../../../core/models/business.dart';
import '../../../core/models/search.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../business/business_providers.dart';
import '../compare_controller.dart';
import '../data/search_repository.dart';
import '../search_providers.dart';
import 'filter_sheet.dart';
import 'widgets/compare_bar.dart';
import 'widgets/explore_search_field.dart';
import 'widgets/search_parts.dart';
import 'widgets/search_result_row.dart';

/// Module 4 — the Explore tab: search, filter, sort and pick places to compare
/// (SRS UC-4, UC-5, FR-3, FR-4; SDD Screen 2).
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  SearchNotifier get _search => ref.read(searchControllerProvider.notifier);

  @override
  void initState() {
    super.initState();
    _text.text = ref.read(searchControllerProvider).input;
    _scroll.addListener(_onScroll);
    _focus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(locationControllerProvider.notifier).ensureChecked();
      // Home's search pill may have asked for focus before this tab was first built.
      if (ref.read(searchFocusRequestProvider) > 0) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    final position = _scroll.position;
    if (position.pixels > position.maxScrollExtent - 400) _search.loadMore();
  }

  void _submit(String query) {
    _focus.unfocus();
    _search.submit(query);
  }

  Future<void> _openFilters(SearchFilters current) async {
    _focus.unfocus();
    final result = await showFilterSheet(context, current);
    if (result != null) _search.applyFilters(result);
  }

  void _toggleCompare(BusinessCard business) {
    final outcome = ref.read(compareSelectionProvider.notifier).toggle(business);
    if (outcome == CompareToggle.full) {
      _snack('You can compare up to ${CompareController.max} places. Remove one first.');
    }
  }

  void _onSuggestion(SearchSuggestion s) {
    _focus.unfocus();
    switch (s.type) {
      case SuggestionType.business:
        if (s.businessId != null) context.push('/business/${s.businessId}');
      case SuggestionType.category:
        if (s.categorySlug != null) _search.browseCategory(s.categorySlug!);
      case SuggestionType.service:
        _search.submit(s.label);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 170),
        backgroundColor: AppColors.ink,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Text(message, style: AppType.sans(size: 13, color: Colors.white)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(searchFocusRequestProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    });
    // Keep the field in sync when the query changes from elsewhere (chips, Home).
    ref.listen(searchControllerProvider.select((s) => s.input), (_, next) {
      if (_text.text != next) {
        _text.value = TextEditingValue(
            text: next, selection: TextSelection.collapsed(offset: next.length));
      }
    });
    // First location fix → re-run the search so distances appear.
    ref.listen(locationControllerProvider.select((s) => s.fix), (previous, next) {
      if (previous == null && next != null) _search.refresh();
    });

    final state = ref.watch(searchControllerProvider);
    final location = ref.watch(locationControllerProvider);
    // Watched in every mode so they stay cached while this tab lives (no refetch or
    // flicker when going back from results to the idle view).
    final history = ref.watch(searchHistoryProvider).valueOrNull ?? const <String>[];
    final popular = ref.watch(popularSearchesProvider).valueOrNull ?? const <String>[];
    final showSuggestions = _focus.hasFocus && state.input.trim().isNotEmpty;
    final suggestions = showSuggestions
        ? ref.watch(suggestionsProvider(state.suggestQuery)).valueOrNull ?? const []
        : const <SearchSuggestion>[];

    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          ListView(
            controller: _scroll,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(22, 64, 22, 190),
            children: [
              Text('Explore', style: AppType.serif(size: 30)),
              const SizedBox(height: 4),
              Text('Search, filter and compare local finds',
                  style: AppType.sans(size: 13, color: AppColors.inkA(0.5))),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ExploreSearchField(
                      controller: _text,
                      focusNode: _focus,
                      onChanged: _search.onInputChanged,
                      onSubmitted: _submit,
                      onClear: _search.clearQuery,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _FilterButton(
                    count: state.filters.activeCount,
                    onTap: () => _openFilters(state.filters),
                  ),
                ],
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                child: suggestions.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: SuggestionList(
                            suggestions: suggestions, onTap: _onSuggestion),
                      ),
              ),
              const SizedBox(height: 20),
              if (state.showResults)
                ..._results(state, location, popular)
              else
                ..._idle(location, history, popular),
            ],
          ),
          const Positioned(left: 16, right: 16, bottom: 96, child: CompareBar()),
        ],
      ),
    );
  }

  // ─────────────── idle: recent · popular · categories ───────────────
  /// Fades a section in once; the key keeps it from replaying when others appear.
  Widget _section(String key, int order, List<Widget> children) => Column(
        key: ValueKey('idle-$key'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      )
          .animate(delay: (40 * order).ms)
          .fadeIn(duration: 260.ms)
          .slideY(begin: 0.06, end: 0);

  List<Widget> _idle(LocationState location, List<String> history, List<String> popular) {
    final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
    final askLocation = const {
      LocationStatus.denied,
      LocationStatus.deniedForever,
      LocationStatus.serviceDisabled,
    }.contains(location.status);
    final notifier = ref.read(locationControllerProvider.notifier);

    return [
      if (askLocation)
        _section('location', 0, [
          LocationPromptCard(
            status: location.status,
            onEnable: () => notifier.refresh(prompt: true),
            onOpenSettings: notifier.openSettings,
          ),
          const SizedBox(height: 24),
        ]),
      if (history.isNotEmpty)
        _section('recent', 1, [
          Row(
            children: [
              Text('RECENT', style: AppType.label()),
              const Spacer(),
              GestureDetector(
                onTap: () async {
                  await ref.read(searchRepositoryProvider).clearHistory();
                  ref.invalidate(searchHistoryProvider);
                },
                child: Text('Clear',
                    style: AppType.sans(
                        size: 12, weight: FontWeight.w700, color: AppColors.plum)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in history)
                QueryChip(label: q, icon: Icons.history_rounded, onTap: () => _submit(q)),
            ],
          ),
          const SizedBox(height: 24),
        ]),
      if (popular.isNotEmpty)
        _section('popular', 2, [
          Text('POPULAR NOW', style: AppType.label()),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final q in popular)
                QueryChip(
                    label: q, icon: Icons.trending_up_rounded, onTap: () => _submit(q)),
            ],
          ),
          const SizedBox(height: 24),
        ]),
      if (categories.isNotEmpty)
        _section('categories', 3, [
          Text('BROWSE BY CATEGORY', style: AppType.label()),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in categories)
                KhojloChip(label: c.name, onTap: () => _search.browseCategory(c.slug)),
            ],
          ),
          const SizedBox(height: 28),
        ]),
      _section('kai', 4, [
        GestureDetector(
          onTap: () => context.push('/kai'),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                AppColors.emerald.withValues(alpha: 0.12),
                AppColors.emerald.withValues(alpha: 0.03),
              ]),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: AppColors.emerald, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Not sure what you want? Ask Kai for ideas',
                      style: AppType.sans(size: 13, weight: FontWeight.w600)),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColors.inkA(0.4)),
              ],
            ),
          ),
        ),
      ]),
    ];
  }

  // ─────────────── results ───────────────
  List<Widget> _results(SearchState state, LocationState location, List<String> popular) {
    final categoryNames = {
      for (final c in ref.watch(categoriesProvider).valueOrNull ?? const <Category>[])
        c.slug: c.name,
    };
    final chips = state.filters.chips(categoryNames);
    final selection = ref.watch(compareSelectionProvider);
    final loading = state.status == SearchStatus.loading;
    final countLabel = loading
        ? 'Searching…'
        : '${state.total} place${state.total == 1 ? '' : 's'} match';

    Widget body;
    if (state.status == SearchStatus.error) {
      body = SearchErrorState(message: state.error ?? '', onRetry: _search.retry);
    } else if (loading && state.items.isEmpty) {
      body = const SearchResultsSkeleton();
    } else if (state.status == SearchStatus.ready && state.items.isEmpty) {
      body = SearchEmptyState(
        hasFilters: state.filters.hasFilters,
        onClearFilters: _search.clearFilters,
        ideas: popular,
        onIdea: _submit,
      );
    } else {
      body = AnimatedOpacity(
        opacity: loading ? 0.45 : 1,
        duration: const Duration(milliseconds: 150),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.summary.isNotEmpty) ...[
              ResultsSummaryCard(summary: state.summary, relaxed: state.relaxed),
              const SizedBox(height: 6),
            ],
            for (var i = 0; i < state.items.length; i++)
              SearchResultRow(
                key: ValueKey(state.items[i].id),
                business: state.items[i],
                showDivider: i != 0,
                selected: selection.any((b) => b.id == state.items[i].id),
                onTap: () {
                  _focus.unfocus();
                  context.push('/business/${state.items[i].id}');
                },
                onToggleCompare: () => _toggleCompare(state.items[i]),
              )
                  .animate(delay: ((i % SearchNotifier.pageSize).clamp(0, 8) * 35).ms)
                  .fadeIn(duration: 240.ms)
                  .slideY(begin: 0.08, end: 0),
            if (state.loadingMore)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: SearchResultsSkeleton(rows: 2),
              ),
            if (!state.hasMore && state.items.length > 6)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Center(
                  child: Text('That’s every match',
                      style: AppType.mono(size: 10.5, color: AppColors.inkA(0.4))),
                ),
              ),
          ],
        ),
      );
    }

    return [
      if (chips.isNotEmpty) ...[
        ActiveFilterChips(
          chips: chips,
          onRemove: _search.removeFilter,
          onClearAll: _search.clearFilters,
        ),
        const SizedBox(height: 14),
      ],
      Row(
        children: [
          Expanded(
            child: Text(countLabel,
                style: AppType.mono(size: 11, color: AppColors.inkA(0.5))),
          ),
          SortMenuButton(
            value: state.filters.sort,
            hasLocation: location.hasFix,
            onSelected: _search.setSort,
          ),
        ],
      ),
      SizedBox(
        height: 3,
        child: loading && state.items.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  backgroundColor: AppColors.gold.withValues(alpha: 0.12),
                  valueColor: const AlwaysStoppedAnimation(AppColors.gold),
                ),
              )
            : null,
      ),
      const SizedBox(height: 8),
      body,
    ];
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: count > 0 ? 'Filters, $count active' : 'Filters',
      child: SizedBox(
        width: 56,
        height: 56,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GlassIconButton(icon: Icons.tune_rounded, size: 56, onTap: onTap),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.emerald,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Text('$count',
                      style: AppType.sans(
                          size: 10.5, weight: FontWeight.w800, color: Colors.white)),
                ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack),
              ),
          ],
        ),
      ),
    );
  }
}
