import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../theme/app_colors.dart';
import 'map_types.dart';

/// Pin colours shared by the Google map and the sketch map.
Color pinColor(PinKind kind) => switch (kind) {
  PinKind.business => AppColors.gold,
  PinKind.selected => AppColors.emerald,
  PinKind.picked => AppColors.plum,
  PinKind.user => const Color(0xFF3D7BF2), // "you are here" blue, as people expect
};

/// Logical size of each pin.
Size pinSize(PinKind kind) => switch (kind) {
  PinKind.business => const Size(28, 36),
  PinKind.selected || PinKind.picked => const Size(38, 48),
  PinKind.user => const Size(22, 22),
};

/// Draws the teardrop pin (or the round "you" dot) onto [canvas] within [size].
void paintPin(Canvas canvas, Size size, PinKind kind) {
  final color = pinColor(kind);
  if (kind == PinKind.user) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = color.withValues(alpha: 0.22));
    canvas.drawCircle(c, r * 0.55, Paint()..color = Colors.white);
    canvas.drawCircle(c, r * 0.4, Paint()..color = color);
    return;
  }
  final w = size.width;
  final r = w / 2;
  final head = Offset(r, r);
  final path = Path()
    ..moveTo(r, size.height)
    ..quadraticBezierTo(w * 0.12, size.height * 0.62, w * 0.04, r * 1.05)
    ..arcTo(Rect.fromCircle(center: head, radius: r * 0.98), 3.3, 2.82 + 0.33, false)
    ..quadraticBezierTo(w * 0.88, size.height * 0.62, r, size.height)
    ..close();
  canvas.drawShadow(path, Colors.black, 3, false);
  canvas.drawPath(path, Paint()..color = color);
  canvas.drawCircle(head, r * 0.38, Paint()..color = Colors.white);
}

/// Google map marker bitmaps, drawn once per screen density.
class PinIcons {
  PinIcons._(this._icons);
  final Map<PinKind, BitmapDescriptor> _icons;

  static final _cache = <double, Future<PinIcons>>{};

  static Future<PinIcons> load(double devicePixelRatio) =>
      _cache[devicePixelRatio] ??= _draw(devicePixelRatio);

  BitmapDescriptor of(PinKind kind) => _icons[kind]!;

  static Future<PinIcons> _draw(double dpr) async {
    final icons = <PinKind, BitmapDescriptor>{};
    for (final kind in PinKind.values) {
      final size = pinSize(kind);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..scale(dpr);
      paintPin(canvas, size, kind);
      final image = await recorder.endRecording().toImage(
        (size.width * dpr).ceil(),
        (size.height * dpr).ceil(),
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      icons[kind] = BitmapDescriptor.bytes(
        png!.buffer.asUint8List(),
        imagePixelRatio: dpr,
        width: size.width,
        height: size.height,
      );
    }
    return PinIcons._(icons);
  }
}
