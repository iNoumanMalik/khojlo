import 'package:flutter/foundation.dart';

/// Google Maps API keys, passed at build/run time so they never live in git:
///
///     flutter run --dart-define-from-file=dart_defines.json
///
/// `dart_defines.json` (gitignored; see `dart_defines.example.json`) holds
/// `MAPS_API_KEY_WEB` and `MAPS_API_KEY_ANDROID`. The Android build also reads its key
/// from there into `AndroidManifest.xml`.
class MapsConfig {
  MapsConfig._();

  static const webKey = String.fromEnvironment('MAPS_API_KEY_WEB');
  static const androidKey = String.fromEnvironment('MAPS_API_KEY_ANDROID');

  /// The key for the platform we're running on, or '' when maps aren't configured.
  static String get currentKey {
    if (kIsWeb) return webKey;
    if (defaultTargetPlatform == TargetPlatform.android) return androidKey;
    return ''; // iOS and desktop aren't configured for Google Maps.
  }

  static bool get isConfigured => currentKey.isNotEmpty;
}
