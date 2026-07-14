import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';

class _Slide {
  const _Slide(this.eyebrow, this.title, this.body, this.tones);
  final String eyebrow;
  final String title;
  final String body;
  final List<Color> tones;
}

/// Module 1 — welcome carousel (3 pages) shown on first run.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  static const _slides = [
    _Slide('01 / 03', 'Your city has\nsecrets worth\nfinding.',
        'Khojlo surfaces the new, the unusual and the underrated — before everyone else finds them too.',
        [AppColors.plum, Color(0xFF58253F), AppColors.ink]),
    _Slide('02 / 03', 'Compare places\nlike a local\nwould.',
        'Prices, services and value, side by side — so you always choose well.',
        [AppColors.emerald, Color(0xFF1B5346), AppColors.ink]),
    _Slide('03 / 03', 'Save the gems.\nGet there\nfirst.',
        'Build collections, follow openings and let Kai plan your next outing.',
        [Color(0xFF6B4A1E), AppColors.gold, AppColors.ink]),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
          duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    } else {
      context.go('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];
    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 500),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: const Alignment(-0.4, -1),
            end: const Alignment(0.4, 1),
            colors: slide.tones,
          ),
        ),
        child: Stack(
          children: [
            // glow blobs
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0.9, -0.9),
                    radius: 0.9,
                    colors: [
                      AppColors.gold.withValues(alpha: 0.33),
                      Colors.transparent
                    ],
                  ),
                ),
              ),
            ),
            PageView.builder(
              controller: _controller,
              onPageChanged: (i) => setState(() => _page = i),
              itemCount: _slides.length,
              itemBuilder: (_, i) => const SizedBox.expand(),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('khojlo',
                        style: AppType.serif(
                            size: 15,
                            color: AppColors.coral,
                            letterSpacing: 1.2)),
                    const Spacer(),
                    Text(slide.eyebrow,
                            style: AppType.mono(
                                size: 10.5,
                                color: AppColors.gold,
                                letterSpacing: 1.6))
                        .animate(key: ValueKey('e$_page'))
                        .fadeIn(duration: 400.ms),
                    const SizedBox(height: 14),
                    Text(slide.title,
                            style: AppType.serif(
                                size: 38, color: Colors.white, height: 1.08))
                        .animate(key: ValueKey('t$_page'))
                        .fadeIn(duration: 500.ms)
                        .slideY(begin: 0.15, curve: Curves.easeOutCubic),
                    const SizedBox(height: 16),
                    Text(slide.body,
                        style: AppType.sans(
                            size: 14,
                            height: 1.5,
                            color: AppColors.whiteA(0.75))),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        for (var i = 0; i < _slides.length; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.only(right: 6),
                            width: i == _page ? 22 : 5,
                            height: 5,
                            decoration: BoxDecoration(
                              color: i == _page
                                  ? AppColors.gold
                                  : AppColors.whiteA(0.35),
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 34),
                    PrimaryButton(
                      label: _page == _slides.length - 1 ? 'Get started' : 'Next',
                      tone: ButtonTone.white,
                      onTap: _next,
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: GestureDetector(
                        onTap: () => context.go('/auth'),
                        child: Text('I already have an account',
                            style: AppType.sans(
                                size: 12.5,
                                weight: FontWeight.w600,
                                color: AppColors.whiteA(0.65))),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
