import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/models/review.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'stars.dart';

/// Animated score circle ("ratings should not simply be stars"): the arc fills to the
/// average out of 5, with the number in the middle.
class RatingCircle extends StatelessWidget {
  const RatingCircle({super.key, required this.average, required this.count, this.size = 104});

  final double average;
  final int count;
  final double size;

  @override
  Widget build(BuildContext context) {
    final hasReviews = count > 0;
    return Semantics(
      label: hasReviews
          ? 'Rated ${average.toStringAsFixed(1)} out of 5 from $count reviews'
          : 'No reviews yet',
      excludeSemantics: true,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: hasReviews ? average / 5 : 0),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => SizedBox.square(
          dimension: size,
          child: CustomPaint(
            painter: _ArcPainter(value),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasReviews ? (value * 5).toStringAsFixed(1) : '–',
                    style: AppType.serif(size: size * 0.3),
                  ),
                  Text(hasReviews ? 'of 5' : 'new',
                      style: AppType.mono(size: 10, color: AppColors.inkA(0.5))),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter(this.progress);
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = (Offset.zero & size).deflate(stroke / 2);
    canvas.drawArc(
      rect,
      0,
      math.pi * 2,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = AppColors.inkA(0.07),
    );
    if (progress <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = const SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: math.pi * 1.5,
          colors: [AppColors.gold, AppColors.emerald],
          transform: GradientRotation(-math.pi / 2),
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) => old.progress != progress;
}

/// 5★ … 1★ bars. Tapping a bar filters by it when [onTap] is given.
class RatingDistribution extends StatelessWidget {
  const RatingDistribution({
    super.key,
    required this.summary,
    this.selected = const {},
    this.onTap,
  });

  final ReviewSummary summary;
  final Set<int> selected;
  final ValueChanged<int>? onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var stars = 5; stars >= 1; stars--)
          _Bar(
            stars: stars,
            share: summary.shareOf(stars),
            count: summary.countFor(stars),
            active: selected.contains(stars),
            dimmed: selected.isNotEmpty && !selected.contains(stars),
            onTap: onTap == null ? null : () => onTap!(stars),
          ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({
    required this.stars,
    required this.share,
    required this.count,
    required this.active,
    required this.dimmed,
    this.onTap,
  });

  final int stars;
  final double share;
  final int count;
  final bool active;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bar = Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Opacity(
        opacity: dimmed ? 0.4 : 1,
        child: Row(
          children: [
            SizedBox(
              width: 22,
              child: Text('$stars★',
                  style: AppType.mono(
                      size: 10.5,
                      weight: active ? FontWeight.w700 : FontWeight.w400,
                      color: AppColors.inkA(0.6))),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: share),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, value, __) => LinearProgressIndicator(
                    value: value,
                    minHeight: 7,
                    backgroundColor: AppColors.inkA(0.06),
                    valueColor: AlwaysStoppedAnimation(
                        active ? AppColors.emerald : AppColors.gold),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 24,
              child: Text('$count',
                  textAlign: TextAlign.right,
                  style: AppType.mono(size: 10.5, color: AppColors.inkA(0.5))),
            ),
          ],
        ),
      ),
    );
    if (onTap == null) return bar;
    return Semantics(
      button: true,
      selected: active,
      label: '$stars star reviews: $count',
      excludeSemantics: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: bar),
    );
  }
}

/// Score circle + distribution, used at the top of the reviews screen and on the
/// business page.
class ReviewSummaryCard extends StatelessWidget {
  const ReviewSummaryCard({
    super.key,
    required this.summary,
    this.selected = const {},
    this.onStarsTap,
  });

  final ReviewSummary summary;
  final Set<int> selected;
  final ValueChanged<int>? onStarsTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.whiteA(0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.inkA(0.06)),
      ),
      child: Row(
        children: [
          Column(
            children: [
              RatingCircle(average: summary.average, count: summary.count),
              const SizedBox(height: 8),
              StarRow(rating: summary.average, size: 13),
              const SizedBox(height: 4),
              Text(
                summary.count == 0
                    ? 'No reviews yet'
                    : '${summary.count} review${summary.count == 1 ? '' : 's'}',
                style: AppType.mono(size: 10.5, color: AppColors.inkA(0.55)),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: RatingDistribution(
                summary: summary, selected: selected, onTap: onStarsTap),
          ),
        ],
      ),
    );
  }
}
