import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

/// Oversized frosted search field whose placeholder cycles through ideas
/// ("Search cafés…", "Search tailors…") while it's empty and unfocused.
class ExploreSearchField extends StatefulWidget {
  const ExploreSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  static const hints = [
    'Search cafés…',
    'Search tailors…',
    'Search gyms…',
    'Search hidden gems…',
    'Search new businesses…',
  ];

  @override
  State<ExploreSearchField> createState() => _ExploreSearchFieldState();
}

class _ExploreSearchFieldState extends State<ExploreSearchField> {
  int _hint = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    widget.focusNode.addListener(_rebuild);
    _timer = Timer.periodic(const Duration(milliseconds: 2600), (_) {
      if (!mounted || widget.controller.text.isNotEmpty || widget.focusNode.hasFocus) {
        return;
      }
      setState(() => _hint = (_hint + 1) % ExploreSearchField.hints.length);
    });
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.controller.removeListener(_rebuild);
    widget.focusNode.removeListener(_rebuild);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final empty = widget.controller.text.isEmpty;
    final focused = widget.focusNode.hasFocus;
    final hint = focused
        ? 'Try “coffee”, “tailor” or “F-7”'
        : ExploreSearchField.hints[_hint];

    return AnimatedScale(
      scale: focused ? 1.02 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: GlassSurface(
        radius: 999,
        opacity: focused ? 0.85 : 0.65,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          children: [
            Icon(Icons.search_rounded,
                size: 21, color: focused ? AppColors.emerald : AppColors.inkA(0.45)),
            const SizedBox(width: 10),
            Expanded(
              child: Stack(
                alignment: Alignment.centerLeft,
                children: [
                  if (empty)
                    IgnorePointer(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 420),
                        // keep both hints left-aligned while they cross-fade
                        layoutBuilder: (current, previous) => Stack(
                          alignment: Alignment.centerLeft,
                          children: [...previous, if (current != null) current],
                        ),
                        // the new hint rises from below while the old one exits upward
                        transitionBuilder: (child, animation) {
                          final incoming = child.key == ValueKey(hint);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(
                                begin: Offset(0, incoming ? 0.45 : -0.45),
                                end: Offset.zero,
                              ).animate(animation),
                              child: child,
                            ),
                          );
                        },
                        child: Text(
                          hint,
                          key: ValueKey(hint),
                          style: AppType.sans(
                              size: 15.5,
                              weight: FontWeight.w500,
                              color: AppColors.inkA(0.42)),
                        ),
                      ),
                    ),
                  TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    textInputAction: TextInputAction.search,
                    onChanged: widget.onChanged,
                    onSubmitted: widget.onSubmitted,
                    style: AppType.sans(size: 15.5, weight: FontWeight.w600),
                    cursorColor: AppColors.emerald,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(vertical: 17),
                    ),
                  ),
                ],
              ),
            ),
            if (!empty)
              GestureDetector(
                onTap: widget.onClear,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.inkA(0.5)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
