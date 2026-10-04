import 'dart:math' as math;

/// A point on the map (WGS 84).
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  /// SRS BR-7: in range and not (0, 0), which is what a failed GPS fix reports.
  bool get isValid =>
      latitude.abs() <= 90 && longitude.abs() <= 180 && !(latitude == 0 && longitude == 0);

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);

  @override
  String toString() => '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

/// Great-circle distance between two points, in metres.
double distanceMeters(GeoPoint a, GeoPoint b) {
  const earthRadius = 6371000.0;
  double rad(double deg) => deg * math.pi / 180;
  final dLat = rad(b.latitude - a.latitude);
  final dLng = rad(b.longitude - a.longitude);
  final h =
      math.pow(math.sin(dLat / 2), 2) +
      math.cos(rad(a.latitude)) * math.cos(rad(b.latitude)) * math.pow(math.sin(dLng / 2), 2);
  return 2 * earthRadius * math.asin(math.sqrt(h));
}

/// The visible map area.
class GeoBounds {
  const GeoBounds({
    required this.south,
    required this.west,
    required this.north,
    required this.east,
  });

  final double south;
  final double west;
  final double north;
  final double east;

  GeoPoint get center => GeoPoint((south + north) / 2, (west + east) / 2);

  bool contains(GeoPoint p) =>
      p.latitude >= south && p.latitude <= north && p.longitude >= west && p.longitude <= east;

  /// The smallest area holding every point, padded by [padding] of its size.
  static GeoBounds? around(Iterable<GeoPoint> points, {double padding = 0.15}) {
    if (points.isEmpty) return null;
    var s = 90.0, n = -90.0, w = 180.0, e = -180.0;
    for (final p in points) {
      s = math.min(s, p.latitude);
      n = math.max(n, p.latitude);
      w = math.min(w, p.longitude);
      e = math.max(e, p.longitude);
    }
    // A single point still needs an area around it (~1 km).
    final dLat = math.max(n - s, 0.01) * padding + (n == s ? 0.005 : 0);
    final dLng = math.max(e - w, 0.01) * padding + (e == w ? 0.005 : 0);
    return GeoBounds(south: s - dLat, west: w - dLng, north: n + dLat, east: e + dLng);
  }

  /// The area a map of [widthPx] × [heightPx] shows at [zoom] around [center].
  factory GeoBounds.fromCamera(GeoPoint center, double zoom, double widthPx, double heightPx) {
    final c = Mercator.project(center, zoom);
    final sw = Mercator.unproject(c.x - widthPx / 2, c.y + heightPx / 2, zoom);
    final ne = Mercator.unproject(c.x + widthPx / 2, c.y - heightPx / 2, zoom);
    return GeoBounds(
      south: sw.latitude,
      west: sw.longitude.clamp(-180.0, 180.0),
      north: ne.latitude,
      east: ne.longitude.clamp(-180.0, 180.0),
    );
  }

  /// The zoom at which this area just fits in [widthPx] × [heightPx].
  double zoomToFit(double widthPx, double heightPx, {double maxZoom = 17}) {
    final sw = Mercator.project(GeoPoint(south, west), 0);
    final ne = Mercator.project(GeoPoint(north, east), 0);
    final dx = math.max((ne.x - sw.x).abs(), 1e-9);
    final dy = math.max((sw.y - ne.y).abs(), 1e-9);
    final zoom = math.log(math.min(widthPx / dx, heightPx / dy)) / math.ln2;
    return zoom.clamp(2.0, maxZoom);
  }

  /// Query parameters for `GET /search` (Module 6 map area).
  Map<String, double> toQuery() => {'north': north, 'south': south, 'east': east, 'west': west};

  /// Rounded, so tiny camera jitters don't count as a new area.
  GeoBounds rounded([int decimals = 3]) {
    double r(double v) => double.parse(v.toStringAsFixed(decimals));
    return GeoBounds(south: r(south), west: r(west), north: r(north), east: r(east));
  }

  @override
  bool operator ==(Object other) =>
      other is GeoBounds &&
      other.south == south &&
      other.west == west &&
      other.north == north &&
      other.east == east;

  @override
  int get hashCode => Object.hash(south, west, north, east);
}

/// Web-mercator projection (what Google Maps uses): world pixels at a zoom level.
class Mercator {
  Mercator._();

  static const tileSize = 256.0;

  static ({double x, double y}) project(GeoPoint p, double zoom) {
    final scale = tileSize * math.pow(2, zoom);
    final lat = p.latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
    final x = (p.longitude + 180) / 360 * scale;
    final y = (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * scale;
    return (x: x, y: y);
  }

  static GeoPoint unproject(double x, double y, double zoom) {
    final scale = tileSize * math.pow(2, zoom);
    final lng = x / scale * 360 - 180;
    final n = math.pi - 2 * math.pi * y / scale;
    final lat = 180 / math.pi * math.atan(0.5 * (math.exp(n) - math.exp(-n)));
    return GeoPoint(lat, lng);
  }
}

/// Where the map camera settled after the user moved it.
class MapCamera {
  const MapCamera({required this.center, required this.zoom, required this.bounds});
  final GeoPoint center;
  final double zoom;
  final GeoBounds bounds;
}

enum PinKind { business, selected, user, picked }

/// A marker on the map.
class MapPin {
  const MapPin({
    required this.id,
    required this.point,
    this.kind = PinKind.business,
    this.title,
    this.snippet,
  });

  final String id;
  final GeoPoint point;
  final PinKind kind;

  /// Shown in the info window above the pin.
  final String? title;
  final String? snippet;
}

/// Moves a map shown by a [MapService].
abstract class KhojloMapController {
  Future<void> moveTo(GeoPoint point, {double? zoom});
  Future<void> fitBounds(GeoBounds bounds);
}

/// Islamabad city centre: the starting view before the user's location is known.
const defaultMapCenter = GeoPoint(33.6938, 73.0652);
const defaultMapZoom = 12.0;
