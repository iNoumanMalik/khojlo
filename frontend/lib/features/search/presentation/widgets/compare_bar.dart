import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../compare_controller.dart';

/// Sticky "Compare 2 businesses ›" bar (SDD Screen 2 "Compare Button"). Slides in once
/// something is selected and becomes tappable at two places.
class CompareBar extends ConsumerWidget {
  const CompareBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(compareSelectionProvider);
    final visible = selection.isNotEmpty;
    final ready = selection.length >= CompareController.min;
    final label = ready
        ? 'Compare ${selection.length} businesses'
        : 'Pick 1 more to compare';

    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1.5),
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 220),
          child: Semantics(
            button: true,
            enabled: ready,
            label: label,
            child: GestureDetector(
              onTap: ready ? () => context.push('/compare') : null,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: ready
                        ? const [AppColors.emerald, Color(0xFF2B8C73)]
                        : [AppColors.inkA(0.78), AppColors.inkA(0.7)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: (ready ? AppColors.emerald : AppColors.ink)
                          .withValues(alpha: 0.35),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    _Stack(tones: [for (final b in selection) b.tone]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(label,
                          style: AppType.sans(
                              size: 14.5, weight: FontWeight.w700, color: Colors.white)),
                    ),
                    GestureDetector(
                      onTap: () => ref.read(compareSelectionProvider.notifier).clear(),
                      behavior: HitTestBehavior.opaque,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Icon(Icons.close_rounded,
                            size: 18, color: AppColors.whiteA(0.75)),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded,
                        color: AppColors.whiteA(ready ? 1 : 0.4)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Overlapping tone dots, one per selected place.
class _Stack extends StatelessWidget {
  const _Stack({required this.tones});
  final List<String> tones;

  @override
  Widget build(BuildContext context) {
    const size = 26.0;
    return SizedBox(
      width: size + (tones.length - 1).clamp(0, 2) * 14,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < tones.length; i++)
            Positioned(
              left: i * 14,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(colors: AppColors.gradientFor(tones[i])),
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
