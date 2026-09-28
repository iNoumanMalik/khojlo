import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/push/push_platform.dart';
import '../../core/router/app_router.dart';
import '../../core/ui/messenger.dart';
import 'data/notifications_repository.dart';
import 'notifications_providers.dart';

/// Push notifications on this device (SRS FR-21, UC-15): permission, the
/// device's registration with the backend, and what happens when one arrives
/// or is tapped. The state is the device's notification permission.
class PushController extends StateNotifier<PushPermission> {
  PushController(this._ref) : super(PushPermission.unsupported) {
    if (_platform.available) {
      _platform.permission().then((p) {
        if (mounted) state = p;
      });
    }
  }

  final Ref _ref;
  String? _token;
  bool _listening = false;
  bool _askedAfterFirstMessage = false;
  final _subscriptions = <StreamSubscription<Object?>>[];

  PushPlatform get _platform => _ref.read(pushPlatformProvider);
  NotificationsRepository get _repo => _ref.read(notificationsRepositoryProvider);

  bool get supported => _platform.available;

  /// After sign-in (or on launch when already signed in).
  Future<void> onSignedIn() async {
    if (!_platform.available) return;
    state = await _platform.permission();
    _listen();
    if (state == PushPermission.granted) await _register();
    final route = await _platform.launchRoute();
    if (route != null) _open(route);
  }

  /// Asks for permission (from a button tap) and registers the device.
  Future<bool> enable() async {
    if (!_platform.available) return false;
    state = await _platform.requestPermission();
    _listen();
    if (state != PushPermission.granted) return false;
    await _register();
    return true;
  }

  /// Offer notifications once, right after the user's first message, so they
  /// hear about the reply.
  Future<void> maybeAskAfterFirstMessage() async {
    if (_askedAfterFirstMessage || state != PushPermission.notDetermined) return;
    _askedAfterFirstMessage = true;
    await enable();
  }

  /// Before signing out: stop pushes to this device for this account.
  Future<void> unregister() async {
    if (!_platform.available) return;
    final token = _token ?? await _platform.token();
    _token = null;
    if (token != null) {
      try {
        await _repo.unregisterDevice(token);
      } catch (_) {}
    }
    await _platform.deleteToken();
  }

  Future<void> _register() async {
    final token = await _platform.token();
    if (token == null) return;
    _token = token;
    try {
      await _repo.registerDevice(token, _platform.platform);
    } catch (_) {}
  }

  void _listen() {
    if (_listening) return;
    _listening = true;
    _subscriptions
      ..add(_platform.tokenRefreshes.listen((token) async {
        _token = token;
        try {
          await _repo.registerDevice(token, _platform.platform);
        } catch (_) {}
      }))
      ..add(_platform.openedRoutes.listen(_open))
      ..add(_platform.foreground.listen(_onForeground));
  }

  void _open(String route) {
    _ref.read(unreadNotificationsProvider.notifier).refresh();
    _ref.read(routerProvider).push(route);
  }

  void _onForeground(ForegroundPush push) {
    _ref.read(unreadNotificationsProvider.notifier).refresh();
    final route = push.route;
    showInAppBanner(push.title, push.body,
        onOpen: route == null || route.isEmpty ? null : () => _open(route));
  }

  @override
  void dispose() {
    for (final s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }
}

final pushControllerProvider =
    StateNotifierProvider<PushController, PushPermission>((ref) => PushController(ref));
