import 'dart:async';
import 'dart:math' show Point;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:maplibre_gl/maplibre_gl.dart';

import 'map_types.dart';
import 'pin_icons.dart';
import 'sketch_map.dart';

/// OpenFreeMap vector tiles (OpenStreetMap data) recoloured in Khojlo's palette.
/// Regenerate with `python3 tool/build_map_style.py`.
const khojloStyleAsset = 'assets/maps/khojlo_style.json';

const _pinSource = 'khojlo-pins';
const _pinLayer = 'khojlo-pins';
const _routeSource = 'khojlo-route';

/// A MapLibre vector map in Khojlo's style with the app's own pins. Pins are a GeoJSON
/// source drawn by one symbol layer, so hundreds of them stay smooth. If the style can't
/// load (offline, no WebGL), it falls back to the sketch map so the screen keeps working.
class MapLibreMapView extends StatefulWidget {
  const MapLibreMapView({
    super.key,
    required this.center,
    required this.zoom,
    required this.pins,
    required this.interactive,
    this.route = const [],
    this.onPinTap,
    this.onCameraIdle,
    this.onCreated,
    this.onMapTap,
  });

  final GeoPoint center;
  final double zoom;
  final List<MapPin> pins;
  final List<GeoPoint> route;
  final bool interactive;
  final ValueChanged<String>? onPinTap;
  final ValueChanged<MapCamera>? onCameraIdle;
  final ValueChanged<KhojloMapController>? onCreated;
  final VoidCallback? onMapTap;

  @override
  State<MapLibreMapView> createState() => _MapLibreMapViewState();
}

class _MapLibreMapViewState extends State<MapLibreMapView> {
  MapLibreMapController? _controller;
  bool _styleReady = false;
  bool _failed = false;
  Timer? _loadTimeout;
  double _dpr = 1;
  late CameraPosition _camera = CameraPosition(target: _latLng(widget.center), zoom: widget.zoom);

  static LatLng _latLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

  @override
  void initState() {
    super.initState();
    _loadTimeout = Timer(const Duration(seconds: 20), () {
      if (mounted && !_styleReady) setState(() => _failed = true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _dpr = MediaQuery.devicePixelRatioOf(context);
  }

  @override
  void didUpdateWidget(MapLibreMapView old) {
    super.didUpdateWidget(old);
    if (!_styleReady) return;
    if (!listEquals(old.pins, widget.pins)) _syncPins();
    if (!listEquals(old.route, widget.route)) _syncRoute();
    // A still map (business page) follows its point; interactive maps are moved
    // explicitly through the controller.
    if (!widget.interactive && old.center != widget.center) {
      _controller?.moveCamera(CameraUpdate.newLatLng(_latLng(widget.center)));
    }
  }

  @override
  void dispose() {
    _loadTimeout?.cancel();
    _controller?.onFeatureTapped.remove(_onFeatureTapped);
    super.dispose();
  }

  Map<String, dynamic> _pinsGeoJson() => {
    'type': 'FeatureCollection',
    'features': [
      for (final pin in widget.pins)
        {
          'type': 'Feature',
          // Android and iOS read the top-level id; web reads the promoted property.
          'id': pin.id,
          'properties': {
            'id': pin.id,
            'kind': pin.kind.name,
            'title': pin.title ?? '',
            'order': switch (pin.kind) {
              PinKind.user => 1,
              PinKind.business => 2,
              PinKind.selected || PinKind.picked => 3,
            },
          },
          'geometry': {
            'type': 'Point',
            'coordinates': [pin.point.longitude, pin.point.latitude],
          },
        },
    ],
  };

  Map<String, dynamic> _routeGeoJson() => {
    'type': 'FeatureCollection',
    'features': [
      if (widget.route.length >= 2)
        {
          'type': 'Feature',
          'properties': <String, dynamic>{},
          'geometry': {
            'type': 'LineString',
            'coordinates': [
              for (final p in widget.route) [p.longitude, p.latitude],
            ],
          },
        },
    ],
  };

  Future<void> _syncRoute() async {
    try {
      await _controller?.setGeoJsonSource(_routeSource, _routeGeoJson());
    } catch (_) {
      // The map was disposed mid-call.
    }
  }

  Future<void> _syncPins() async {
    try {
      await _controller?.setGeoJsonSource(_pinSource, _pinsGeoJson());
    } catch (_) {
      // The map was disposed mid-call.
    }
  }

  /// The pins are drawn with the same painter as the sketch map, at screen density.
  /// Android and iOS read these images as screen-density bitmaps; the web plugin reads
  /// them as 1x, so there [_iconScale] draws them at 1/dpr to keep their logical size.
  double get _iconScale => kIsWeb ? 1 / _dpr : 1;

  Future<void> _addPinImages(MapLibreMapController controller) async {
    for (final kind in PinKind.values) {
      final size = pinSize(kind);
      final recorder = ui.PictureRecorder();
      paintPin(Canvas(recorder)..scale(_dpr), size, kind);
      final image = await recorder.endRecording().toImage(
        (size.width * _dpr).ceil(),
        (size.height * _dpr).ceil(),
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      await controller.addImage('khojlo-pin-${kind.name}', png!.buffer.asUint8List());
    }
  }

  Future<void> _onStyleLoaded() async {
    final controller = _controller;
    if (controller == null) return;
    _loadTimeout?.cancel();
    try {
      await _addPinImages(controller);
      // The route goes in first so the pins draw on top of it: a white casing under an
      // emerald line (AppColors.emerald), like the selected pin.
      await controller.addGeoJsonSource(_routeSource, _routeGeoJson());
      await controller.addLineLayer(
        _routeSource,
        'khojlo-route-casing',
        const LineLayerProperties(
          lineColor: '#ffffff',
          lineWidth: 9,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await controller.addLineLayer(
        _routeSource,
        'khojlo-route',
        const LineLayerProperties(
          lineColor: '#1D6D5A',
          lineWidth: 5,
          lineCap: 'round',
          lineJoin: 'round',
        ),
        enableInteraction: false,
      );
      await controller.addGeoJsonSource(_pinSource, _pinsGeoJson(), promoteId: 'id');
      await controller.addSymbolLayer(
        _pinSource,
        _pinLayer,
        SymbolLayerProperties(
          iconImage: [
            'concat',
            'khojlo-pin-',
            ['get', 'kind'],
          ],
          iconSize: _iconScale,
          iconAnchor: [
            'match',
            ['get', 'kind'],
            'user',
            'center',
            'bottom',
          ],
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          symbolSortKey: ['get', 'order'],
          textField: ['get', 'title'],
          textFont: ['Noto Sans Regular'],
          textSize: 12,
          textAnchor: 'top',
          textOffset: [0, 0.2],
          textOptional: true,
          textColor: '#3f3a33',
          textHaloColor: '#fbf6ee',
          textHaloWidth: 1.4,
        ),
        enableInteraction: widget.interactive,
      );
    } catch (_) {
      if (mounted) setState(() => _failed = true);
      return;
    }
    if (!mounted) return;
    setState(() => _styleReady = true);
    // Pins and the route may have changed while the style loaded.
    unawaited(_syncPins());
    unawaited(_syncRoute());
    // Report the first view too, so results load without the user touching the map.
    unawaited(_onIdle());
  }

  void _onFeatureTapped(Point<double> point, LatLng coordinates, String id, String layerId, _) {
    if (layerId == _pinLayer) widget.onPinTap?.call(id);
  }

  Future<void> _onIdle() async {
    final controller = _controller;
    final callback = widget.onCameraIdle;
    if (controller == null || callback == null || !_styleReady) return;
    try {
      final region = await controller.getVisibleRegion();
      final camera = controller.cameraPosition ?? _camera;
      if (!mounted) return;
      callback(
        MapCamera(
          center: GeoPoint(camera.target.latitude, camera.target.longitude),
          zoom: camera.zoom,
          bounds: GeoBounds(
            south: region.southwest.latitude,
            west: region.southwest.longitude,
            north: region.northeast.latitude,
            east: region.northeast.longitude,
          ),
        ),
      );
    } catch (_) {
      // The map was disposed mid-call; nothing to report.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return SketchMap(
        center: widget.center,
        zoom: widget.zoom,
        pins: widget.pins,
        route: widget.route,
        interactive: widget.interactive,
        notice: widget.interactive ? "Couldn't load the map · check your connection" : null,
        onPinTap: widget.onPinTap,
        onCameraIdle: widget.onCameraIdle,
        onCreated: widget.onCreated,
        onMapTap: widget.onMapTap,
      );
    }
    final interactive = widget.interactive;
    return ColoredBox(
      // The style's land colour, so there's no white flash while tiles load.
      color: const Color(0xFFF3EEE4),
      child: MapLibreMap(
        styleString: khojloStyleAsset,
        initialCameraPosition: _camera,
        trackCameraPosition: interactive,
        // The map claims every gesture on it, so no parent can take a pinch or a drag.
        gestureRecognizers: interactive
            ? {Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new)}
            : null,
        // Rotation and tilt stay off: the map-area search works on north-up bounds.
        rotateGesturesEnabled: false,
        tiltGesturesEnabled: false,
        scrollGesturesEnabled: interactive,
        zoomGesturesEnabled: interactive,
        doubleClickZoomEnabled: interactive,
        dragEnabled: false,
        compassEnabled: false,
        // Pins are our own layer, not plugin annotations.
        annotationOrder: const [],
        attributionButtonPosition: AttributionButtonPosition.bottomLeft,
        onMapCreated: (controller) {
          _controller = controller;
          controller.onFeatureTapped.add(_onFeatureTapped);
          widget.onCreated?.call(_MapLibreController(controller));
        },
        onStyleLoadedCallback: _onStyleLoaded,
        onCameraMove: (position) => _camera = position,
        onCameraIdle: _onIdle,
        onMapClick: widget.onMapTap == null ? null : (_, _) => widget.onMapTap!(),
      ),
    );
  }
}

class _MapLibreController implements KhojloMapController {
  _MapLibreController(this._c);
  final MapLibreMapController _c;

  @override
  Future<void> moveTo(GeoPoint point, {double? zoom}) => _c.animateCamera(
    zoom == null
        ? CameraUpdate.newLatLng(LatLng(point.latitude, point.longitude))
        : CameraUpdate.newLatLngZoom(LatLng(point.latitude, point.longitude), zoom),
  );

  @override
  Future<void> fitBounds(GeoBounds bounds) => _c.animateCamera(
    CameraUpdate.newLatLngBounds(
      LatLngBounds(
        southwest: LatLng(bounds.south, bounds.west),
        northeast: LatLng(bounds.north, bounds.east),
      ),
      left: 48,
      top: 48,
      right: 48,
      bottom: 48,
    ),
  );
}
