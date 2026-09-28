import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether Firebase started, so push notifications can work. Overridden in
/// main(); false in tests and whenever Firebase isn't configured.
final firebaseReadyProvider = Provider<bool>((ref) => false);

/// Firebase's web app config, from dart_defines.json (Firebase console →
/// Project settings → Your apps → the web app → SDK setup and configuration).
/// Android reads its config from android/app/google-services.json instead.
class FirebaseWebConfig {
  FirebaseWebConfig._();

  static const apiKey = String.fromEnvironment('FIREBASE_API_KEY');
  static const appId = String.fromEnvironment('FIREBASE_APP_ID');
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const messagingSenderId = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
  static const authDomain = String.fromEnvironment('FIREBASE_AUTH_DOMAIN');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');

  /// The public "Web Push certificate" key (Cloud Messaging → Web configuration).
  static const vapidKey = String.fromEnvironment('FIREBASE_WEB_VAPID_KEY');

  static bool _filled(String value) => value.isNotEmpty && !value.startsWith('your-');

  static FirebaseOptions? get options {
    if (![apiKey, appId, projectId, messagingSenderId].every(_filled)) return null;
    return FirebaseOptions(
      apiKey: apiKey,
      appId: appId,
      projectId: projectId,
      messagingSenderId: messagingSenderId,
      authDomain: _filled(authDomain) ? authDomain : null,
      storageBucket: _filled(storageBucket) ? storageBucket : null,
    );
  }
}

/// Starts Firebase for push notifications. Returns false (push off, the app
/// otherwise unaffected) when it isn't configured for this platform.
Future<bool> initFirebase() async {
  try {
    if (kIsWeb) {
      final options = FirebaseWebConfig.options;
      if (options == null) return false;
      await Firebase.initializeApp(options: options).timeout(const Duration(seconds: 8));
      return true;
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp().timeout(const Duration(seconds: 8));
      return true;
    }
    return false; // iOS push is out of scope (SRS CO-11)
  } catch (e) {
    debugPrint('Push notifications are off: Firebase did not start ($e).');
    return false;
  }
}
