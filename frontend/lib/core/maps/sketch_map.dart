import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'map_types.dart';
import 'pin_icons.dart';

/// A drawn stand-in for Google Maps: same pins, panning, zooming and camera events,
/// but no street data. Used when no API key is configured, when Google Maps can't load,
/// and in widget tests.
class SketchMap extends StatefulWidget {
  const SketchMap({
    super.key,
    required this.center,
    required this.zoom,
    required this.pins,
    this.interactive = true,
    this.notice,
    this.onPinTap,
    this.onInfoTap,
    this.onCameraIdle,
    this.onCreated,
    this.onMapTap,
  });

  final GeoPoint center;
  final double zoom;
  final List<MapPin> pins;
  final bool interactive;
  final String? notice;
  final ValueChanged<String>? onPinTap;
  final ValueChanged<String>? onInfoTap;
  final ValueChanged<MapCamera>? onCameraIdle;
  final ValueChanged<KhojloMapController>? onCreated;
  final VoidCallback? onMapTap;

  @override
  State<SketchMap> createState() => _SketchMapState();
}

class _SketchMapState extends State<SketchMap> implements KhojloMapController {
  late GeoPoint _center = widget.center;
  late double _zoom = widget.zoom;
  Size _size = Size.zero;
  String? _infoFor;

  // Gesture bookkeeping.
  double _startZoom = 0;
  Offset _lastFocal = Offset.zero;
  bool _reportedFirst = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCreated?.call(this);
    });
  }

  @override
  void didUpdateWidget(SketchMap old) {
    super.didUpdateWidget(old);
    if (!widget.interactive && old.center != widget.center) _center = widget.center;
  }

  Offset _toScreen(GeoPoint p) {
    final c = Mercator.project(_center, _zoom);
    final q = Mercator.project(p, _zoom);
    return Offset(q.x - c.x + _size.width / 2, q.y - c.y + _size.height / 2);
  }

  void _report() {
    if (_size.isEmpty) return;
    widget.onCameraIdle?.call(
      MapCamera(
        center: _center,
        zoom: _zoom,
        bounds: GeoBounds.fromCamera(_center, _zoom, _size.width, _size.height),
      ),
    );
  }

  @override
  Future<void> moveTo(GeoPoint point, {double? zoom}) async {
    if (!mounted) return;
    setState(() {
      _center = point;
      if (zoom != null) _zoom = zoom;
    });
    _report();
  }

  @override
  Future<void> fitBounds(GeoBounds bounds) async {
    if (!mounted || _size.isEmpty) return;
    setState(() {
      _center = bounds.center;
      _zoom = bounds.zoomToFit(_size.width - 96, _size.height - 96);
    });
    _report();
  }

  void _onScaleStart(ScaleStartDetails d) {
    _startZoom = _zoom;
    _lastFocal = d.localFocalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails d) {
    final delta = d.localFocalPoint - _lastFocal;
    _lastFocal = d.localFocalPoint;
    setState(() {
      if (d.scale != 1) {
        _zoom = (_startZoom + math.log(d.scale) / math.ln2).clamp(3.0, 19.0);
      }
      final c = Mercator.project(_center, _zoom);
      _center = Mercator.unproject(c.x - delta.dx, c.y - delta.dy, _zoom);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _size = constraints.biggest;
        if (!_reportedFirst && !_size.isEmpty) {
          _reportedFirst = true;
          scheduleMicrotask(() {
            if (mounted) _report();
          });
        }
        final pins = [...widget.pins]..sort((a, b) => _order(a.kind).compareTo(_order(b.kind)));
        final info = widget.pins.where((p) => p.id == _infoFor && p.title != null).firstOrNull;
        return ClipRect(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onScaleStart: widget.interactive ? _onScaleStart : null,
            onScaleUpdate: widget.interactive ? _onScaleUpdate : null,
            onScaleEnd: widget.interactive ? (_) => _report() : null,
            onDoubleTap: widget.interactive
                ? () {
                    setState(() => _zoom = math.min(_zoom + 1, 19));
                    _report();
                  }
                : null,
            onTap: () {
              if (_infoFor != null) setState(() => _infoFor = null);
              widget.onMapTap?.call();
            },
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _SketchPainter(_center, _zoom))),
                for (final pin in pins) _pin(pin),
                if (info != null) _infoWindow(info),
                if (widget.notice != null)
                  Positioned(
                    left: 12,
                    top: 12,
                    right: 64,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          widget.notice!,
                          style: AppType.mono(size: 9.5, color: AppColors.inkA(0.55)),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  static int _order(PinKind k) => switch (k) {
    PinKind.user => 0,
    PinKind.business => 1,
    PinKind.selected || PinKind.picked => 2,
  };

  Widget _pin(MapPin pin) {
    final size = pinSize(pin.kind);
    final at = _toScreen(pin.point);
    final isDot = pin.kind == PinKind.user;
    return Positioned(
      left: at.dx - size.width / 2,
      top: isDot ? at.dy - size.height / 2 : at.dy - size.height,
      width: size.width,
      height: size.height,
      child: GestureDetector(
        key: ValueKey('pin-${pin.id}'),
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (pin.title != null) setState(() => _infoFor = pin.id);
          widget.onPinTap?.call(pin.id);
        },
        child: CustomPaint(painter: _PinPainter(pin.kind)),
      ),
    );
  }

  Widget _infoWindow(MapPin pin) {
    final at = _toScreen(pin.point);
    final height = pinSize(pin.kind).height;
    return Positioned(
      left: at.dx - 110,
      top: at.dy - height - 62,
      width: 220,
      child: GestureDetector(
        onTap: () => widget.onInfoTap?.call(pin.id),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: AppColors.inkA(0.15), blurRadius: 10)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                pin.title!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.sans(size: 13, weight: FontWeight.w600),
              ),
              if (pin.snippet != null)
                Text(
                  pin.snippet!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.sans(size: 11, color: AppColors.inkA(0.55)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PinPainter extends CustomPainter {
  _PinPainter(this.kind);
  final PinKind kind;

  @override
  void paint(Canvas canvas, Size size) => paintPin(canvas, size, kind);

  @override
  bool shouldRepaint(_PinPainter old) => old.kind != kind;
}

/// Cream land, a soft grid of "streets" that moves with the camera, and a river.
class _SketchPainter extends CustomPainter {
  _SketchPainter(this.center, this.zoom);
  final GeoPoint center;
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFF3EEE4));
    final c = Mercator.project(center, zoom);
    final left = c.x - size.width / 2;
    final top = c.y - size.height / 2;

    // Streets every ~250 m of the world, drawn only when they're far enough apart.
    final spacing = Mercator.tileSize * math.pow(2, zoom) / math.pow(2, 16);
    if (spacing > 14) {
      final minor = Paint()
        ..color = Colors.white
        ..strokeWidth = math.min(6, spacing / 12);
      final major = Paint()
        ..color = const Color(0xFFF6E2B8)
        ..strokeWidth = math.min(10, spacing / 7);
      var i = (left / spacing).floor();
      for (var x = i * spacing - left; x < size.width; x += spacing, i++) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), i % 6 == 0 ? major : minor);
      }
      var j = (top / spacing).floor();
      for (var y = j * spacing - top; y < size.height; y += spacing, j++) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), j % 6 == 0 ? major : minor);
      }
    }

    // A river crossing the world diagonally, so panning feels like moving somewhere.
    final scale = Mercator.tileSize * math.pow(2, zoom);
    final river = Paint()
      ..color = const Color(0xFFC5DFD8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(8, scale / 4e4);
    final path = Path();
    for (var sx = -40.0; sx <= size.width + 40; sx += 20) {
      final wx = sx + left;
      final wy = wx * 0.35 + math.sin(wx / (scale / 3e3)) * scale / 6e3 + scale * 0.162;
      final sy = wy - top;
      sx == -40 ? path.moveTo(sx, sy) : path.lineTo(sx, sy);
    }
    canvas.drawPath(path, river);
  }

  @override
  bool shouldRepaint(_SketchPainter old) => old.center != center || old.zoom != zoom;
}
