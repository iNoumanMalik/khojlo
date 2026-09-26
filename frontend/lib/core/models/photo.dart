import 'package:flutter/widgets.dart';

import '../network/api_config.dart';

/// An uploaded photo (business cover/gallery or profile picture).
///
/// The backend stores a large variant and a thumbnail, plus a focal point: the
/// centre of the photo's detail, used to anchor crops so the subject stays in
/// view whatever the frame's shape.
class Photo {
  const Photo({
    required this.key,
    required this.url,
    required this.thumbUrl,
    required this.width,
    required this.height,
    this.focalX = 0.5,
    this.focalY = 0.5,
  });

  final String key;

  /// Absolute URLs, ready for an image widget.
  final String url;
  final String thumbUrl;
  final int width;
  final int height;
  final double focalX;
  final double focalY;

  double get aspectRatio => height == 0 ? 1 : width / height;

  /// Where to anchor a `BoxFit.cover` crop when the frame's shape is unknown.
  Alignment get alignment => Alignment(focalX * 2 - 1, focalY * 2 - 1);

  /// Alignment for a `BoxFit.cover` crop into a frame of [frameAspect]
  /// (width / height) that centres the focal point, as far as the photo's
  /// edges allow. So a storefront on the right of a wide photo stays whole in
  /// a square thumbnail instead of being sliced by the frame's edge.
  Alignment alignmentFor(double frameAspect) {
    if (!frameAspect.isFinite || frameAspect <= 0) return alignment;
    // Fraction of the photo visible along each axis once it covers the frame.
    final visibleX = frameAspect >= aspectRatio ? 1.0 : frameAspect / aspectRatio;
    final visibleY = frameAspect >= aspectRatio ? aspectRatio / frameAspect : 1.0;
    double axis(double focal, double visible) {
      if (visible >= 1) return 0;
      final start = (focal - visible / 2).clamp(0.0, 1.0 - visible);
      return start / (1 - visible) * 2 - 1;
    }

    return Alignment(axis(focalX, visibleX), axis(focalY, visibleY));
  }

  factory Photo.fromJson(Map<String, dynamic> j) => Photo(
        key: j['key'] as String,
        url: ApiConfig.resolve(j['url'] as String),
        thumbUrl: ApiConfig.resolve(j['thumb_url'] as String),
        width: j['width'] as int? ?? 0,
        height: j['height'] as int? ?? 0,
        focalX: (j['focal_x'] as num?)?.toDouble() ?? 0.5,
        focalY: (j['focal_y'] as num?)?.toDouble() ?? 0.5,
      );

  static Photo? maybe(Object? json) =>
      json is Map<String, dynamic> ? Photo.fromJson(json) : null;

  @override
  bool operator ==(Object other) => other is Photo && other.key == key;

  @override
  int get hashCode => key.hashCode;
}
