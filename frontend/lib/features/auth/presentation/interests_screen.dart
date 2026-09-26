import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/business.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../business/business_providers.dart';
import '../auth_controller.dart';

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  final _selected = <String>{};
  bool _saving = false;

  Widget _grouped(List<Category> categories) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (group, items) in groupCategories(categories.where((c) => !c.isOther))) ...[
          if (group.isNotEmpty) ...[
            Text(group.toUpperCase(), style: AppType.label()),
            const SizedBox(height: 10),
          ],
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final c in items)
                _InterestChip(
                  label: c.name,
                  emoji: c.emoji,
                  selected: _selected.contains(c.slug),
                  onTap: () => setState(() {
                    if (!_selected.remove(c.slug)) _selected.add(c.slug);
                  }),
                ),
            ],
          ),
          const SizedBox(height: 20),
        ],
      ],
    );
  }

  Future<void> _continue() async {
    setState(() => _saving = true);
    await ref.read(authControllerProvider.notifier).setInterests(_selected.toList());
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        children: [
          const Positioned.fill(child: MeshBackground()),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('CHOOSE YOUR INTERESTS', style: AppType.label()),
                  const SizedBox(height: 12),
                  Text('What are you\ninto?', style: AppType.serif(size: 34, height: 1.1)),
                  const SizedBox(height: 10),
                  Text(
                    'We’ll tune your feed and let Kai make sharper suggestions. Pick a few.',
                    style: AppType.sans(
                        size: 13.5, height: 1.5, color: AppColors.inkA(0.53)),
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: SingleChildScrollView(
                      // Categories come from the server, so new ones appear without an update.
                      child: ref.watch(categoriesProvider).when(
                            loading: () => Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                for (var i = 0; i < 9; i++)
                                  SkeletonBox(width: 110 + (i % 3) * 20.0, height: 50, radius: 18),
                              ],
                            ),
                            error: (_, __) => Row(
                              children: [
                                Expanded(
                                  child: Text('Couldn’t load interests. You can pick them later.',
                                      style: AppType.sans(size: 13, color: AppColors.inkA(0.6))),
                                ),
                                GhostButton(
                                  label: 'Retry',
                                  small: true,
                                  expand: false,
                                  onTap: () => ref.invalidate(categoriesProvider),
                                ),
                              ],
                            ),
                            data: (list) => _grouped(list),
                          ),
                    ),
                  ),
                  PrimaryButton(
                    label: _selected.isEmpty
                        ? 'Skip for now'
                        : 'Continue (${_selected.length})',
                    tone: ButtonTone.ink,
                    loading: _saving,
                    onTap: _continue,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InterestChip extends StatelessWidget {
  const _InterestChip({
    required this.label,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.emerald : AppColors.whiteA(0.6),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? AppColors.emerald : AppColors.whiteA(0.7),
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AppColors.emerald.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 7),
            Text(label,
                style: AppType.sans(
                    size: 14,
                    weight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.ink)),
          ],
        ),
      ),
    );
  }
}
