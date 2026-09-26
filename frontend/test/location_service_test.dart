import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:khojlo/core/location/location_service.dart';

/// A platform whose position request never answers (what a browser does when its
/// location provider stalls or the user ignores the prompt).
class StalledGeolocator extends GeolocatorPlatform {
  StalledGeolocator({this.permission = LocationPermission.whileInUse});
  final LocationPermission permission;
  var positionRequests = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => true;

  @override
  Future<LocationPermission> checkPermission() async => permission;

  @override
  Future<LocationPermission> requestPermission() => Completer<LocationPermission>().future;

  @override
  Future<Position?> getLastKnownPosition({bool forceLocationManager = false}) async => null;

  @override
  Future<Position> getCurrentPosition({LocationSettings? locationSettings}) {
    positionRequests++;
    return Completer<Position>().future;
  }
}

void main() {
  late GeolocatorPlatform original;
  setUp(() => original = GeolocatorPlatform.instance);
  tearDown(() => GeolocatorPlatform.instance = original);

  testWidgets('a stalled position request ends in an error instead of hanging',
      (tester) async {
    final platform = StalledGeolocator();
    GeolocatorPlatform.instance = platform;

    LocationResult? result;
    LocationService().locate(fresh: true).then((r) => result = r);
    await tester.pump(LocationService.fixTimeout - const Duration(seconds: 1));
    expect(result, isNull); // still waiting

    await tester.pump(const Duration(seconds: 2));
    expect(result?.status, LocationStatus.error);
    expect(platform.positionRequests, 1);
  });

  testWidgets('an unanswered permission prompt counts as "denied"', (tester) async {
    GeolocatorPlatform.instance = StalledGeolocator(permission: LocationPermission.denied);

    LocationResult? result;
    LocationService().locate(prompt: true).then((r) => result = r);
    await tester.pump(LocationService.promptTimeout + const Duration(seconds: 1));
    expect(result?.status, LocationStatus.denied);
  });

  testWidgets('the controller leaves "locating" once the request gives up', (tester) async {
    GeolocatorPlatform.instance = StalledGeolocator();
    final controller = LocationController(LocationService());
    addTearDown(controller.dispose);

    controller.refresh();
    expect(controller.state.status, LocationStatus.locating);
    await tester.pump(LocationService.fixTimeout + const Duration(seconds: 1));
    expect(controller.state.status, LocationStatus.error);
    expect(controller.state.hasFix, isFalse);
  });
}
