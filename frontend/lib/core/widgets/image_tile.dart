import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/photo.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Image surface used throughout the design.
///
/// With a [photo] it fills whatever frame it's given (wide banner, square
/// thumbnail, tall card) by cropping around the photo's focal point, and picks
/// the thumbnail or the large variant from the size it's drawn at. Large photos
/// load over their thumbnail, so they sharpen in place instead of popping in.
/// Without one it renders the signature tone gradient + diagonal stripes, as
/// the mockups do.
class ImageTile extends StatelessWidget {
  const ImageTile({
    super.key,
    this.height,
    this.tone = 'gold',
    this.radius = 20,
    this.label,
    this.imageUrl,
    this.photo,
    this.width,
  });

  final double? height;
  final double? width;
  final String tone;
  final double radius;
  final String? label;

  /// A plain URL (no focal point or variants). Prefer [photo].
  final String? imageUrl;
  final Photo? photo;

  bool get _hasImage => photo != null || (imageUrl?.isNotEmpty ?? false);

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
            if (photo != null)
              LayoutBuilder(
                builder: (context, box) => _PhotoFill(photo: photo!, box: box, tone: tone),
              )
            else if (imageUrl != null && imageUrl!.isNotEmpty)
              CachedNetworkImage(
                imageUrl: imageUrl!,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 250),
                errorWidget: (_, __, ___) => _gradient(),
                placeholder: (_, __) => _gradient(),
              ),
            // The stripe texture belongs to the placeholder look, not to real photos.
            if (!_hasImage) const _StripeOverlay(),
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

  Widget _gradient() => _ToneGradient(tone: tone);
}

/// Thumbnails are stored up to this many pixels on their long edge.
const _thumbEdge = 480.0;

/// Whether a `BoxFit.cover` crop of [photo] into [box] needs more pixels than
/// the thumbnail has.
bool needsLargeVariant(Photo photo, BoxConstraints box, double devicePixelRatio) {
  final w = box.maxWidth.isFinite ? box.maxWidth : 400.0;
  final h = box.maxHeight.isFinite ? box.maxHeight : w / photo.aspectRatio;
  final aspect = photo.aspectRatio;
  // Width the photo is drawn at once scaled to cover the frame.
  final drawnWidth = math.max(w, h * aspect) * devicePixelRatio;
  final thumbWidth = aspect >= 1 ? _thumbEdge : _thumbEdge * aspect;
  return drawnWidth > thumbWidth * 1.15;
}

class _PhotoFill extends StatelessWidget {
  const _PhotoFill({required this.photo, required this.box, required this.tone});
  final Photo photo;
  final BoxConstraints box;
  final String tone;

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final large = needsLargeVariant(photo, box, dpr);
    // Decode at the size it's drawn at, not the file's full size: less memory and
    // no decoding hitches while scrolling.
    final w = box.maxWidth.isFinite ? box.maxWidth : 400.0;
    final h = box.maxHeight.isFinite ? box.maxHeight : w / photo.aspectRatio;
    final decodeWidth = (math.max(w, h * photo.aspectRatio) * dpr).ceil();
    final alignment = box.hasBoundedWidth && box.hasBoundedHeight && box.maxHeight > 0
        ? photo.alignmentFor(box.maxWidth / box.maxHeight)
        : photo.alignment;
    Widget image(String url, {Widget Function(BuildContext, String)? placeholder}) =>
        CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          alignment: alignment,
          fadeInDuration: const Duration(milliseconds: 250),
          placeholder: placeholder,
          memCacheWidth: decodeWidth,
          errorWidget: (_, __, ___) => _ToneGradient(tone: tone),
        );
    if (!large) return image(photo.thumbUrl);
    return image(photo.url, placeholder: (_, __) => image(photo.thumbUrl));
  }
}

class _ToneGradient extends StatelessWidget {
  const _ToneGradient({required this.tone});
  final String tone;

  @override
  Widget build(BuildContext context) => DecoratedBox(
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

  // The stripes are drawn faint directly, rather than through an Opacity widget,
  // which would render every placeholder tile off-screen on each frame.
  @override
  Widget build(BuildContext context) =>
      const RepaintBoundary(child: CustomPaint(painter: _StripePainter()));
}

class _StripePainter extends CustomPainter {
  const _StripePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
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
