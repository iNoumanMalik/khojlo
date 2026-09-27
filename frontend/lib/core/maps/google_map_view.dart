import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'map_style.dart';
import 'map_types.dart';
import 'maps_loader_stub.dart' if (dart.library.js_interop) 'maps_loader_web.dart';
import 'pin_icons.dart';
import 'sketch_map.dart';

/// A Google map in Khojlo's style with custom pins. On web it first loads the Maps
/// JavaScript API; if that fails or Google rejects the key, it falls back to the sketch
/// map so the screen keeps working.
class GoogleMapView extends StatefulWidget {
  const GoogleMapView({
    super.key,
    required this.apiKey,
    required this.center,
    required this.zoom,
    required this.pins,
    required this.interactive,
    this.onPinTap,
    this.onInfoTap,
    this.onCameraIdle,
    this.onCreated,
    this.onMapTap,
  });

  final String apiKey;
  final GeoPoint center;
  final double zoom;
  final List<MapPin> pins;
  final bool interactive;
  final ValueChanged<String>? onPinTap;
  final ValueChanged<String>? onInfoTap;
  final ValueChanged<MapCamera>? onCameraIdle;
  final ValueChanged<KhojloMapController>? onCreated;
  final VoidCallback? onMapTap;

  @override
  State<GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<GoogleMapView> {
  late final Future<bool> _loaded = loadGoogleMaps(widget.apiKey);
  PinIcons? _icons;
  GoogleMapController? _controller;
  late CameraPosition _camera = CameraPosition(target: _latLng(widget.center), zoom: widget.zoom);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    PinIcons.load(MediaQuery.devicePixelRatioOf(context)).then((icons) {
      if (mounted && _icons != icons) setState(() => _icons = icons);
    });
  }

  @override
  void didUpdateWidget(GoogleMapView old) {
    super.didUpdateWidget(old);
    // A still map (business page) follows its point; interactive maps are moved
    // explicitly through the controller.
    if (!widget.interactive && old.center != widget.center) {
      _controller?.moveCamera(CameraUpdate.newLatLng(_latLng(widget.center)));
    }
  }

  static LatLng _latLng(GeoPoint p) => LatLng(p.latitude, p.longitude);

  Set<Marker> _markers() {
    final icons = _icons;
    if (icons == null) return const {};
    return {
      for (final pin in widget.pins)
        Marker(
          markerId: MarkerId(pin.id),
          position: _latLng(pin.point),
          icon: icons.of(pin.kind),
          anchor: pin.kind == PinKind.user ? const Offset(0.5, 0.5) : const Offset(0.5, 1),
          zIndexInt: switch (pin.kind) {
            PinKind.user => 1,
            PinKind.business => 2,
            PinKind.selected || PinKind.picked => 3,
          },
          // Without a title the app shows its own preview card instead of an info window.
          consumeTapEvents: pin.title == null,
          infoWindow: pin.title == null
              ? InfoWindow.noText
              : InfoWindow(
                  title: pin.title,
                  snippet: pin.snippet,
                  onTap: () => widget.onInfoTap?.call(pin.id),
                ),
          onTap: () => widget.onPinTap?.call(pin.id),
        ),
    };
  }

  Future<void> _onIdle() async {
    final controller = _controller;
    final callback = widget.onCameraIdle;
    if (controller == null || callback == null) return;
    try {
      final region = await controller.getVisibleRegion();
      if (!mounted) return;
      callback(
        MapCamera(
          center: GeoPoint(_camera.target.latitude, _camera.target.longitude),
          zoom: _camera.zoom,
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

  Widget _fallback(String notice) => SketchMap(
    center: widget.center,
    zoom: widget.zoom,
    pins: widget.pins,
    interactive: widget.interactive,
    notice: widget.interactive ? notice : null,
    onPinTap: widget.onPinTap,
    onInfoTap: widget.onInfoTap,
    onCameraIdle: widget.onCameraIdle,
    onCreated: widget.onCreated,
    onMapTap: widget.onMapTap,
  );

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _loaded,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const ColoredBox(color: Color(0xFFF3EEE4));
        }
        if (snap.data != true) {
          return _fallback("Couldn't load Google Maps. Check your connection.");
        }
        return ValueListenableBuilder<bool>(
          valueListenable: mapsKeyRejected,
          builder: (context, rejected, _) => rejected
              ? _fallback('Google Maps rejected the API key · showing a preview map')
              : _map(),
        );
      },
    );
  }

  Widget _map() {
    final interactive = widget.interactive;
    return GoogleMap(
      initialCameraPosition: _camera,
      style: khojloMapStyle,
      markers: _markers(),
      // The app draws its own "you are here" dot and locate button on every platform.
      myLocationEnabled: false,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: interactive,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      scrollGesturesEnabled: interactive,
      zoomGesturesEnabled: interactive,
      // A still map is a cheap bitmap on Android.
      liteModeEnabled: !interactive && defaultTargetPlatform == TargetPlatform.android && !kIsWeb,
      webGestureHandling: interactive ? WebGestureHandling.greedy : WebGestureHandling.none,
      webCameraControlEnabled: false,
      onMapCreated: (controller) {
        _controller = controller;
        widget.onCreated?.call(_GoogleController(controller));
        // Report the first view too, so results load without the user touching the map.
        _onIdle();
      },
      onCameraMove: (position) => _camera = position,
      onCameraIdle: _onIdle,
      onTap: widget.onMapTap == null ? null : (_) => widget.onMapTap!(),
    );
  }
}

class _GoogleController implements KhojloMapController {
  _GoogleController(this._c);
  final GoogleMapController _c;

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
      48,
    ),
  );
}
