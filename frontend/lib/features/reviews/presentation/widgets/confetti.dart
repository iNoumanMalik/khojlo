import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// "Review submitted → confetti burst" (design microinteraction). A short, self-removing
/// overlay; it ignores touches, so the screen stays usable underneath.
void showConfetti(BuildContext context) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(builder: (_) => _ConfettiBurst(onDone: () => entry.remove()));
  overlay.insert(entry);
}

class _ConfettiBurst extends StatefulWidget {
  const _ConfettiBurst({required this.onDone});
  final VoidCallback onDone;

  @override
  State<_ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<_ConfettiBurst> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..forward().whenComplete(widget.onDone);

  late final List<_Piece> _pieces = _makePieces();

  static const _colors = [AppColors.gold, AppColors.emerald, AppColors.plum, AppColors.coral];

  List<_Piece> _makePieces() {
    final rng = math.Random();
    return [
      for (var i = 0; i < 70; i++)
        _Piece(
          angle: -math.pi / 2 + (rng.nextDouble() - 0.5) * math.pi * 0.9,
          speed: 0.55 + rng.nextDouble() * 0.6,
          spin: (rng.nextDouble() - 0.5) * 12,
          size: 5 + rng.nextDouble() * 6,
          color: _colors[i % _colors.length],
          round: rng.nextBool(),
        ),
    ];
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _controller.value),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });

  final double angle;
  final double speed;
  final double spin;
  final double size;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);
  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final origin = Offset(size.width / 2, size.height * 0.62);
    final reach = size.height * 0.75;
    final fade = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
    for (final p in pieces) {
      final d = reach * p.speed * t;
      final gravity = size.height * 0.9 * t * t;
      final pos = origin + Offset(math.cos(p.angle) * d, math.sin(p.angle) * d + gravity);
      final paint = Paint()..color = p.color.withValues(alpha: fade.clamp(0.0, 1.0));
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
            Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.5), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
