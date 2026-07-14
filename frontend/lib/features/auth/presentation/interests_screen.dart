import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_controller.dart';

class InterestsScreen extends ConsumerStatefulWidget {
  const InterestsScreen({super.key});

  @override
  ConsumerState<InterestsScreen> createState() => _InterestsScreenState();
}

class _InterestsScreenState extends ConsumerState<InterestsScreen> {
  final _selected = <String>{};
  bool _saving = false;

  // (label, emoji, backend category slug)
  static const _interests = [
    ('Food', '🍜', 'restaurants'),
    ('Cafés', '☕', 'cafes'),
    ('Bars', '🍸', 'bars'),
    ('Gym', '💪', 'gym'),
    ('Healthcare', '🏥', 'healthcare'),
    ('Gaming', '🎮', 'gaming'),
    ('Beauty', '💄', 'beauty'),
    ('Education', '🎓', 'education'),
  ];

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
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (final (label, emoji, slug) in _interests)
                            _InterestChip(
                              label: label,
                              emoji: emoji,
                              selected: _selected.contains(slug),
                              onTap: () => setState(() {
                                _selected.contains(slug)
                                    ? _selected.remove(slug)
                                    : _selected.add(slug);
                              }),
                            ),
                        ],
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
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
