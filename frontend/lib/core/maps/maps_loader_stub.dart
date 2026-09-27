import 'package:flutter/foundation.dart';

/// Android loads the Maps SDK natively (key in AndroidManifest.xml); nothing to do here.
Future<bool> loadGoogleMaps(String apiKey) async => true;

final mapsKeyRejected = ValueNotifier<bool>(false);
