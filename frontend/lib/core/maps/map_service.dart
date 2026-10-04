import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';
import 'package:url_launcher/url_launcher.dart';

import 'google_map_view.dart';
import 'map_types.dart';
import 'maplibre_map_view.dart';
import 'maps_config.dart';
import 'sketch_map.dart';

/// SDD `MapService` (class diagram §4.1): the app talks to this interface, so the
/// map provider can change without touching screens.
/// - [MapLibreService] (default): OpenStreetMap vector maps, no API key needed.
/// - [GoogleMapsService]: the SDD's `GoogleMapsService`, opt-in with `MAP_PROVIDER=google`.
/// - [SketchMapService]: a drawn stand-in on platforms without a real map (and in tests).
abstract class MapService {
  const MapService();

  /// Whether this service draws real Google maps.
  bool get isGoogle;

  /// An interactive map. [route] is drawn as a line under the pins (a route preview).
  Widget buildMap({
    Key? key,
    required GeoPoint center,
    double zoom = defaultMapZoom,
    List<MapPin> pins = const [],
    List<GeoPoint> route = const [],
    bool interactive = true,
    ValueChanged<String>? onPinTap,
    ValueChanged<String>? onInfoTap,
    ValueChanged<MapCamera>? onCameraIdle,
    ValueChanged<KhojloMapController>? onCreated,
    VoidCallback? onMapTap,
  });

  /// SDD Algorithm 12 `displayLocation()`: a small, still map centred on one place.
  Widget displayLocation(GeoPoint point, {double zoom = 15, VoidCallback? onTap}) {
    return Stack(
      fit: StackFit.expand,
      children: [
        buildMap(
          center: point,
          zoom: zoom,
          interactive: false,
          pins: [MapPin(id: 'here', point: point, kind: PinKind.selected)],
        ),
        // Taps go to the caller (e.g. "open the big map"), not to the map itself. The
        // interceptor lets Flutter get those taps over a Google map on web.
        if (onTap != null)
          Positioned.fill(
            child: PointerInterceptor(
              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap),
            ),
          ),
      ],
    );
  }

  /// UC-9 alternative flow "get directions": Google Maps navigation to [destination]
  /// (the Google Maps app on Android when installed, the website otherwise). [walking]
  /// asks for walking directions instead of Google's default.
  Uri directionsUri(GeoPoint destination, {bool? walking}) =>
      Uri.https('www.google.com', '/maps/dir/', {
        'api': '1',
        'destination': '${destination.latitude},${destination.longitude}',
        if (walking != null) 'travelmode': walking ? 'walking' : 'driving',
      });

  Future<bool> openDirections(GeoPoint destination, {bool? walking}) async {
    try {
      return await launchUrl(
        directionsUri(destination, walking: walking),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {
      return false;
    }
  }
}

class GoogleMapsService extends MapService {
  const GoogleMapsService(this.apiKey);
  final String apiKey;

  @override
  bool get isGoogle => true;

  @override
  Widget buildMap({
    Key? key,
    required GeoPoint center,
    double zoom = defaultMapZoom,
    List<MapPin> pins = const [],
    List<GeoPoint> route = const [],
    bool interactive = true,
    ValueChanged<String>? onPinTap,
    ValueChanged<String>? onInfoTap,
    ValueChanged<MapCamera>? onCameraIdle,
    ValueChanged<KhojloMapController>? onCreated,
    VoidCallback? onMapTap,
  }) => GoogleMapView(
    key: key,
    apiKey: apiKey,
    center: center,
    zoom: zoom,
    pins: pins,
    route: route,
    interactive: interactive,
    onPinTap: onPinTap,
    onInfoTap: onInfoTap,
    onCameraIdle: onCameraIdle,
    onCreated: onCreated,
    onMapTap: onMapTap,
  );
}

class MapLibreService extends MapService {
  const MapLibreService();

  @override
  bool get isGoogle => false;

  @override
  Widget buildMap({
    Key? key,
    required GeoPoint center,
    double zoom = defaultMapZoom,
    List<MapPin> pins = const [],
    List<GeoPoint> route = const [],
    bool interactive = true,
    ValueChanged<String>? onPinTap,
    ValueChanged<String>? onInfoTap,
    ValueChanged<MapCamera>? onCameraIdle,
    ValueChanged<KhojloMapController>? onCreated,
    VoidCallback? onMapTap,
  }) => MapLibreMapView(
    key: key,
    center: center,
    zoom: zoom,
    pins: pins,
    route: route,
    interactive: interactive,
    onPinTap: onPinTap,
    onCameraIdle: onCameraIdle,
    onCreated: onCreated,
    onMapTap: onMapTap,
  );
}

class SketchMapService extends MapService {
  const SketchMapService({this.notice});

  /// A small note on the map explaining why it isn't Google Maps.
  final String? notice;

  @override
  bool get isGoogle => false;

  @override
  Widget buildMap({
    Key? key,
    required GeoPoint center,
    double zoom = defaultMapZoom,
    List<MapPin> pins = const [],
    List<GeoPoint> route = const [],
    bool interactive = true,
    ValueChanged<String>? onPinTap,
    ValueChanged<String>? onInfoTap,
    ValueChanged<MapCamera>? onCameraIdle,
    ValueChanged<KhojloMapController>? onCreated,
    VoidCallback? onMapTap,
  }) => SketchMap(
    key: key,
    center: center,
    zoom: zoom,
    pins: pins,
    route: route,
    interactive: interactive,
    notice: interactive ? notice : null,
    onPinTap: onPinTap,
    onInfoTap: onInfoTap,
    onCameraIdle: onCameraIdle,
    onCreated: onCreated,
    onMapTap: onMapTap,
  );
}

final mapServiceProvider = Provider<MapService>((ref) {
  if (MapsConfig.useGoogle) {
    if (MapsConfig.isConfigured) return GoogleMapsService(MapsConfig.currentKey);
    return const SketchMapService(notice: 'Map preview · add a Google Maps key to see real maps');
  }
  if (MapsConfig.mapLibreSupported) return const MapLibreService();
  return const SketchMapService(notice: 'Map preview · real maps run on Android, iOS and web');
});
