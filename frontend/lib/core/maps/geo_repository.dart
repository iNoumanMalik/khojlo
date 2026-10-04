import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location/location_service.dart';
import '../providers.dart';
import 'map_types.dart';

/// An address from the backend's `/geo/*` lookup (OpenStreetMap or Google, behind our server).
class GeoPlace {
  const GeoPlace({
    required this.address,
    required this.label,
    required this.point,
    this.area,
    this.city,
  });

  final String address;

  /// Short name: "F-7 Markaz, Islamabad".
  final String label;
  final GeoPoint point;
  final String? area;
  final String? city;

  factory GeoPlace.fromJson(Map<String, dynamic> j) => GeoPlace(
    address: j['address'] as String? ?? '',
    label: j['label'] as String? ?? '',
    area: j['area'] as String?,
    city: j['city'] as String?,
    point: GeoPoint((j['latitude'] as num).toDouble(), (j['longitude'] as num).toDouble()),
  );
}

enum TravelMode { car, walk }

/// A route preview from the backend's `/geo/route` (openrouteservice behind our server).
class RouteResult {
  const RouteResult({
    required this.mode,
    required this.distanceMeters,
    required this.duration,
    required this.points,
  });

  final TravelMode mode;
  final double distanceMeters;
  final Duration duration;
  final List<GeoPoint> points;

  factory RouteResult.fromJson(Map<String, dynamic> j) => RouteResult(
    mode: TravelMode.values.byName(j['mode'] as String),
    distanceMeters: (j['distance_m'] as num).toDouble(),
    duration: Duration(seconds: (j['duration_s'] as num).round()),
    points: [
      for (final p in j['points'] as List)
        GeoPoint(((p as List)[0] as num).toDouble(), (p[1] as num).toDouble()),
    ],
  );
}

/// Why an address lookup gave nothing.
enum GeoLookupFailure {
  /// Address lookup is off on the server (503): the app hides lookup features.
  unavailable,
  notFound,
  failed,
}

class GeoLookupException implements Exception {
  const GeoLookupException(this.reason);
  final GeoLookupFailure reason;
}

class GeoRepository {
  GeoRepository(this._dio);
  final Dio _dio;

  Future<GeoPlace> reverse(GeoPoint p) async {
    try {
      final res = await _dio.get(
        '/geo/reverse',
        queryParameters: {'lat': p.latitude, 'lng': p.longitude},
      );
      return GeoPlace.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw GeoLookupException(_reason(e));
    }
  }

  /// Places matching [query]; [near] ranks places close to it first.
  Future<List<GeoPlace>> search(String query, {GeoPoint? near}) async {
    try {
      final res = await _dio.get(
        '/geo/search',
        queryParameters: {
          'q': query,
          if (near != null && near.isValid) ...{'lat': near.latitude, 'lng': near.longitude},
        },
      );
      return (res.data as List).map((e) => GeoPlace.fromJson(e as Map<String, dynamic>)).toList();
    } on DioException catch (e) {
      throw GeoLookupException(_reason(e));
    }
  }

  /// The route from [from] to [to]. Fails with [GeoLookupFailure.unavailable] when the
  /// server has no routing key, and [GeoLookupFailure.notFound] when no road connects them.
  Future<RouteResult> route(GeoPoint from, GeoPoint to, TravelMode mode) async {
    try {
      final res = await _dio.get(
        '/geo/route',
        queryParameters: {
          'from_lat': from.latitude,
          'from_lng': from.longitude,
          'to_lat': to.latitude,
          'to_lng': to.longitude,
          'mode': mode.name,
        },
      );
      return RouteResult.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw GeoLookupException(_reason(e));
    }
  }

  static GeoLookupFailure _reason(DioException e) => switch (e.response?.statusCode) {
    503 => GeoLookupFailure.unavailable,
    404 => GeoLookupFailure.notFound,
    _ => GeoLookupFailure.failed,
  };
}

final geoRepositoryProvider = Provider<GeoRepository>((ref) {
  return GeoRepository(ref.watch(dioProvider));
});

/// SDD Screen 1 "Location Indicator": the name of the area the user is in, e.g.
/// "F-7 Markaz, Islamabad". null while unknown; '' when we have a fix but can't name it
/// (no geocoding on the server, or offline), so Home shows a generic label.
final locationLabelProvider = FutureProvider<String?>((ref) async {
  final fix = ref.watch(locationControllerProvider.select((s) => s.fix));
  if (fix == null) return null;
  // ~1 km grid: small GPS drift doesn't trigger a new lookup.
  final point = GeoPoint(
    double.parse(fix.latitude.toStringAsFixed(2)),
    double.parse(fix.longitude.toStringAsFixed(2)),
  );
  try {
    return (await ref.read(geoRepositoryProvider).reverse(point)).label;
  } catch (_) {
    return '';
  }
});

extension LocationFixPoint on LocationFix {
  GeoPoint get point => GeoPoint(latitude, longitude);
}
