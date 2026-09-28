import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_setup.dart';
import 'sw_messages_stub.dart' if (dart.library.js_interop) 'sw_messages_web.dart';

enum PushPermission { unsupported, notDetermined, granted, denied }

/// A push that arrived while the app was open.
class ForegroundPush {
  const ForegroundPush({required this.title, required this.body, this.route, this.kind});
  final String title;
  final String body;
  final String? route;
  final String? kind;
}

/// The device side of push notifications (Firebase Cloud Messaging). A
/// provider so tests can substitute a fake.
abstract class PushPlatform {
  bool get available;

  /// "android" or "web", as the backend expects.
  String get platform;
  Future<PushPermission> permission();
  Future<PushPermission> requestPermission();

  /// This device's FCM registration token, or null if there isn't one.
  Future<String?> token();
  Future<void> deleteToken();
  Stream<String> get tokenRefreshes;

  /// Routes of notifications tapped while the app was in the background.
  Stream<String> get openedRoutes;

  /// The route of the notification that launched the app, if any.
  Future<String?> launchRoute();
  Stream<ForegroundPush> get foreground;
}

final pushPlatformProvider = Provider<PushPlatform>((ref) =>
    ref.watch(firebaseReadyProvider) ? FirebasePushPlatform() : const NoPushPlatform());

/// Used when Firebase isn't configured, and in tests.
class NoPushPlatform implements PushPlatform {
  const NoPushPlatform();
  @override
  bool get available => false;
  @override
  String get platform => kIsWeb ? 'web' : 'android';
  @override
  Future<PushPermission> permission() async => PushPermission.unsupported;
  @override
  Future<PushPermission> requestPermission() async => PushPermission.unsupported;
  @override
  Future<String?> token() async => null;
  @override
  Future<void> deleteToken() async {}
  @override
  Stream<String> get tokenRefreshes => const Stream.empty();
  @override
  Stream<String> get openedRoutes => const Stream.empty();
  @override
  Future<String?> launchRoute() async => null;
  @override
  Stream<ForegroundPush> get foreground => const Stream.empty();
}

class FirebasePushPlatform implements PushPlatform {
  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  @override
  bool get available => true;

  @override
  String get platform => kIsWeb ? 'web' : 'android';

  static PushPermission _map(AuthorizationStatus status) => switch (status) {
        AuthorizationStatus.authorized || AuthorizationStatus.provisional =>
          PushPermission.granted,
        AuthorizationStatus.denied || AuthorizationStatus.deniedPermanently =>
          PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };

  @override
  Future<PushPermission> permission() async {
    try {
      return _map((await _messaging.getNotificationSettings()).authorizationStatus);
    } catch (_) {
      return PushPermission.unsupported;
    }
  }

  @override
  Future<PushPermission> requestPermission() async {
    try {
      return _map((await _messaging.requestPermission()).authorizationStatus);
    } catch (_) {
      return PushPermission.unsupported;
    }
  }

  @override
  Future<String?> token() async {
    // The web needs the project's public Web Push key; without it, no token.
    if (kIsWeb && FirebaseWebConfig.vapidKey.isEmpty) return null;
    try {
      return await _messaging.getToken(vapidKey: kIsWeb ? FirebaseWebConfig.vapidKey : null);
    } catch (e) {
      debugPrint('Could not get a push token: $e');
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
    } catch (_) {}
  }

  @override
  Stream<String> get tokenRefreshes => _messaging.onTokenRefresh;

  @override
  Stream<String> get openedRoutes {
    final routes = StreamController<String>.broadcast();
    FirebaseMessaging.onMessageOpenedApp.listen((m) {
      final route = m.data['route'];
      if (route is String && route.isNotEmpty) routes.add(route);
    });
    // Web: web/firebase-messaging-sw.js forwards notification clicks.
    serviceWorkerOpenedRoutes().listen(routes.add);
    return routes.stream;
  }

  @override
  Future<String?> launchRoute() async {
    try {
      final route = (await _messaging.getInitialMessage())?.data['route'];
      return route is String && route.isNotEmpty ? route : null;
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<ForegroundPush> get foreground => FirebaseMessaging.onMessage.map((m) => ForegroundPush(
        title: m.notification?.title ?? '',
        body: m.notification?.body ?? '',
        route: m.data['route'] as String?,
        kind: m.data['kind'] as String?,
      ));
}
