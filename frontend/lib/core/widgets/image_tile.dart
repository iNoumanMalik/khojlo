import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Image surface used throughout the design. When no URL is supplied it renders
/// the signature tone gradient + diagonal stripe overlay (as the mockups do);
/// with a URL it shows the cached photo, falling back to the gradient.
class ImageTile extends StatelessWidget {
  const ImageTile({
    super.key,
    this.height,
    this.tone = 'gold',
    this.radius = 20,
    this.label,
    this.imageUrl,
    this.width,
  });

  final double? height;
  final double? width;
  final String tone;
  final double radius;
  final String? label;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        height: height,
        width: width,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _gradient(),
            if (imageUrl != null && imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 250),
                errorWidget: (_, __, ___) => _gradient(),
                placeholder: (_, __) => _gradient(),
              ),
            // diagonal stripe texture overlay
            const _StripeOverlay(),
            if (label != null && label!.isNotEmpty)
              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    label!.toUpperCase(),
                    style: AppType.mono(
                        size: 9,
                        color: AppColors.whiteA(0.85),
                        letterSpacing: 0.6),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _gradient() => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.gradientFor(tone),
          ),
        ),
      );
}

class _StripeOverlay extends StatelessWidget {
  const _StripeOverlay();

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: 0.5,
      child: CustomPaint(painter: _StripePainter()),
    );
  }
}

class _StripePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 2;
    const gap = 14.0;
    // 115deg diagonal lines
    for (double x = -size.height; x < size.width; x += gap) {
      canvas.drawLine(
        Offset(x, size.height),
        Offset(x + size.height * 0.47, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
