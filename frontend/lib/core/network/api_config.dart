import 'package:flutter/foundation.dart';

/// Resolves the backend base URL for the current platform.
/// Android emulators reach the host loopback via 10.0.2.2.
class ApiConfig {
  ApiConfig._();

  static String get baseUrl {
    const override = String.fromEnvironment('KHOJLO_API');
    if (override.isNotEmpty) return override;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000/api/v1';
    }
    return 'http://localhost:8000/api/v1';
  }

  /// Turns a path the API returns (e.g. `/api/v1/media/abc`) into a full URL on
  /// the same host. Absolute URLs pass through unchanged.
  static String resolve(String path) => Uri.parse(baseUrl).resolve(path).toString();
}
