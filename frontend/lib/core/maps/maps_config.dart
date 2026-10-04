import 'package:flutter/foundation.dart';

/// Map settings, passed at build/run time so keys never live in git:
///
///     flutter run --dart-define-from-file=dart_defines.json
///
/// The default map is MapLibre with OpenStreetMap tiles and needs no key. Google Maps
/// is opt-in: set `MAP_PROVIDER` to `google` in `dart_defines.json` (gitignored; see
/// `dart_defines.example.json`) along with `MAPS_API_KEY_WEB` and `MAPS_API_KEY_ANDROID`.
/// The Android build also reads its key from there into `AndroidManifest.xml`.
class MapsConfig {
  MapsConfig._();

  static const provider = String.fromEnvironment('MAP_PROVIDER', defaultValue: 'maplibre');
  static const webKey = String.fromEnvironment('MAPS_API_KEY_WEB');
  static const androidKey = String.fromEnvironment('MAPS_API_KEY_ANDROID');

  static bool get useGoogle => provider == 'google';

  /// MapLibre runs on web, Android and iOS (not desktop).
  static bool get mapLibreSupported =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  /// The Google key for the platform we're running on, or '' when it isn't configured.
  static String get currentKey {
    if (kIsWeb) return webKey;
    if (defaultTargetPlatform == TargetPlatform.android) return androidKey;
    return ''; // iOS and desktop aren't configured for Google Maps.
  }

  static bool get isConfigured => currentKey.isNotEmpty;
}
