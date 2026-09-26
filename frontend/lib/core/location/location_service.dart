import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

/// A device position (WGS84).
class LocationFix {
  const LocationFix(this.latitude, this.longitude);
  final double latitude;
  final double longitude;

  @override
  String toString() =>
      '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';
}

enum LocationStatus {
  /// Not checked yet.
  unknown,
  locating,
  available,

  /// Not granted (or not asked yet — Android reports both the same way).
  denied,

  /// Blocked; only the system settings can change it.
  deniedForever,
  serviceDisabled,

  /// No location support on this platform/device.
  unsupported,
  error,
}

class LocationResult {
  const LocationResult(this.status, [this.fix]);
  final LocationStatus status;
  final LocationFix? fix;
}

/// Thin wrapper over `geolocator` so screens (and tests) don't touch the plugin directly.
class LocationService {
  /// Longest wait for a position fix. Enforced here in Dart because plugins don't all
  /// honour `LocationSettings.timeLimit` — geolocator_web hands it to the browser in the
  /// wrong unit (15 s becomes ~4 h), so a stalled request would otherwise never end.
  static const fixTimeout = Duration(seconds: 15);

  /// Longest wait for the user to answer a permission prompt.
  static const promptTimeout = Duration(seconds: 60);

  /// Resolve the device location.
  ///
  /// With [prompt] false this never shows a permission dialog — it only reads a location
  /// the user already allowed. [fresh] skips the cached last-known position (used when an
  /// owner pins their business, where accuracy matters).
  Future<LocationResult> locate({bool prompt = false, bool fresh = false}) async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult(LocationStatus.serviceDisabled);
      }
      var permission = await Geolocator.checkPermission();
      if (prompt &&
          (permission == LocationPermission.denied ||
              permission == LocationPermission.unableToDetermine)) {
        permission = await Geolocator.requestPermission()
            .timeout(promptTimeout, onTimeout: () => LocationPermission.denied);
      }
      switch (permission) {
        case LocationPermission.denied:
        case LocationPermission.unableToDetermine:
          return const LocationResult(LocationStatus.denied);
        case LocationPermission.deniedForever:
          return const LocationResult(LocationStatus.deniedForever);
        case LocationPermission.whileInUse:
        case LocationPermission.always:
          break;
      }

      Position? position;
      if (!fresh && !kIsWeb) {
        // Not available on web; a cached fix is fine for "how far away is it".
        try {
          position = await Geolocator.getLastKnownPosition();
        } catch (_) {}
      }
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(
          accuracy: fresh ? LocationAccuracy.high : LocationAccuracy.medium,
          timeLimit: fixTimeout,
        ),
      ).timeout(fixTimeout);
      return LocationResult(
        LocationStatus.available,
        LocationFix(position.latitude, position.longitude),
      );
    } on LocationServiceDisabledException {
      return const LocationResult(LocationStatus.serviceDisabled);
    } on PermissionDeniedException {
      return const LocationResult(LocationStatus.denied);
    } on TimeoutException {
      return const LocationResult(LocationStatus.error);
    } on MissingPluginException {
      return const LocationResult(LocationStatus.unsupported);
    } on UnimplementedError {
      return const LocationResult(LocationStatus.unsupported);
    } catch (_) {
      return const LocationResult(LocationStatus.error);
    }
  }

  Future<void> openSettings() async {
    if (kIsWeb) return;
    try {
      await Geolocator.openAppSettings();
    } catch (_) {}
  }
}

class LocationState {
  const LocationState({this.status = LocationStatus.unknown, this.fix});
  final LocationStatus status;
  final LocationFix? fix;

  bool get hasFix => fix != null;
  bool get isLocating => status == LocationStatus.locating;
}

/// The searcher's location for the session: checked once silently, requested on demand.
class LocationController extends StateNotifier<LocationState> {
  LocationController(this._service) : super(const LocationState());
  final LocationService _service;

  Future<LocationFix?> refresh({bool prompt = false}) async {
    if (state.isLocating) return state.fix;
    final previous = state.fix;
    state = LocationState(status: LocationStatus.locating, fix: previous);
    final result = await _service.locate(prompt: prompt);
    if (!mounted) return result.fix;
    // Keep an earlier fix if a later attempt fails (e.g. a timeout indoors).
    state = LocationState(status: result.status, fix: result.fix ?? previous);
    return state.fix;
  }

  /// Check without prompting, only if nothing is known yet.
  Future<void> ensureChecked() async {
    if (state.status == LocationStatus.unknown) await refresh();
  }

  Future<void> openSettings() => _service.openSettings();
}

final locationServiceProvider = Provider<LocationService>((ref) => LocationService());

final locationControllerProvider =
    StateNotifierProvider<LocationController, LocationState>((ref) {
  return LocationController(ref.watch(locationServiceProvider));
});
