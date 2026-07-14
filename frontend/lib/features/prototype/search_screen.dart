import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/widgets/widgets.dart';
import 'mock_data.dart';

/// Module 4 — Search, filtering & comparison (high-fidelity prototype).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  bool get _searching => _controller.text.isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      floatingActionButton: _searching
          ? Padding(
              padding: const EdgeInsets.only(bottom: 90),
              child: FloatingActionButton.extended(
                backgroundColor: AppColors.ink,
                onPressed: () => context.push('/compare'),
                icon: const Icon(Icons.compare_arrows_rounded, color: Colors.white),
                label: Text('Compare',
                    style: AppType.sans(
                        size: 13, weight: FontWeight.w700, color: Colors.white)),
              ),
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 64, 22, 120),
        children: [
          Text('Explore', style: AppType.serif(size: 30)),
          const SizedBox(height: 16),
          _SearchField(
              controller: _controller,
              onChanged: (_) => setState(() {}),
              onFilter: _openFilters),
          const SizedBox(height: 24),
          if (!_searching) ..._idle() else ..._results(),
        ],
      ),
    );
  }

  List<Widget> _idle() => [
        Text('RECENT', style: AppType.label()),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final s in Mock.recentSearches)
              _SearchChip(label: s, onTap: () => _fill(s)),
          ],
        ),
        const SizedBox(height: 24),
        Text('POPULAR', style: AppType.label()),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final s in Mock.popularSearches)
              _SearchChip(label: s, onTap: () => _fill(s)),
          ],
        ),
        const SizedBox(height: 28),
        Container(
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
                child: Text('Ask Kai to find the perfect spot for tonight',
                    style: AppType.sans(size: 13, weight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ];

  List<Widget> _results() => [
        Row(
          children: [
            Text('${Mock.places.length} results',
                style: AppType.sans(size: 13, weight: FontWeight.w700)),
            const Spacer(),
            const _FilterChipRow(),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.whiteA(0.7),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.emerald.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              const Icon(Icons.auto_awesome, color: AppColors.emerald, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                    'AI summary: mostly highly-rated, mid-priced spots within 1 km.',
                    style: AppType.sans(size: 12.5, color: AppColors.inkA(0.7))),
              ),
            ],
          ),
        ),
        for (var i = 0; i < Mock.places.length; i++)
          BusinessListRow(
            business: Mock.places[i],
            showDivider: i != 0,
            onTap: () => context.push('/business/${Mock.places[i].id}'),
          ),
      ];

  void _fill(String s) {
    _controller.text = s;
    setState(() {});
  }

  void _openFilters() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                    color: AppColors.inkA(0.2),
                    borderRadius: BorderRadius.circular(2)),
              ),
            ),
            Text('Filters', style: AppType.serif(size: 22)),
            const SizedBox(height: 18),
            Text('PRICE', style: AppType.label()),
            const SizedBox(height: 10),
            Row(children: [
              for (final p in ['\$', '\$\$', '\$\$\$'])
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: KhojloChip(label: p),
                ),
            ]),
            const SizedBox(height: 18),
            Text('OPEN NOW', style: AppType.label()),
            const SizedBox(height: 10),
            Row(children: [
              Text('Show only open places',
                  style: AppType.sans(size: 14, weight: FontWeight.w600)),
              const Spacer(),
              const KhojloToggle(value: true),
            ]),
            const SizedBox(height: 22),
            PrimaryButton(
              label: 'Apply filters',
              tone: ButtonTone.emerald,
              onTap: () => Navigator.of(context).pop(),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onFilter,
  });
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onFilter;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GlassSurface(
            radius: 999,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.search_rounded, size: 20, color: AppColors.inkA(0.4)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: controller,
                    onChanged: onChanged,
                    style: AppType.sans(size: 14),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search cafés, gyms, hidden gems...',
                      hintStyle: AppType.sans(
                          size: 14, color: AppColors.inkA(0.45)),
                    ),
                  ),
                ),
                if (controller.text.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      controller.clear();
                      onChanged('');
                    },
                    child: Icon(Icons.close_rounded,
                        size: 18, color: AppColors.inkA(0.5)),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        GlassIconButton(icon: Icons.tune_rounded, size: 48, onTap: onFilter),
      ],
    );
  }
}

class _SearchChip extends StatelessWidget {
  const _SearchChip({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.whiteA(0.6),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.whiteA(0.7)),
        ),
        child: Text(label,
            style: AppType.sans(size: 13, weight: FontWeight.w600)),
      ),
    );
  }
}

class _FilterChipRow extends StatelessWidget {
  const _FilterChipRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.tune_rounded, size: 15, color: AppColors.inkA(0.6)),
        const SizedBox(width: 4),
        Text('Filters',
            style: AppType.sans(
                size: 12.5, weight: FontWeight.w600, color: AppColors.inkA(0.6))),
      ],
    );
  }
}
