import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/chat/chat_providers.dart';
import '../../features/notifications/notifications_providers.dart';
import '../../features/notifications/push_controller.dart';
import '../providers.dart';
import '../realtime/realtime_service.dart';

/// Runs the signed-in services around the whole app (Module 9):
/// * the live-events socket, open while signed in and in the foreground (it
///   closes in the background, so the server sends push notifications instead);
/// * push notifications for this device;
/// * the chat and notification badges, loaded on sign-in and cleared on sign-out.
class SessionServices extends ConsumerStatefulWidget {
  const SessionServices({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<SessionServices> createState() => _SessionServicesState();
}

class _SessionServicesState extends ConsumerState<SessionServices> with WidgetsBindingObserver {
  bool get _signedIn => ref.read(authControllerProvider).isAuthenticated;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_signedIn) Future.microtask(_onSignedIn);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSignedIn() {
    ref.read(realtimeProvider).start();
    ref.read(conversationsControllerProvider.notifier).load();
    ref.read(unreadNotificationsProvider.notifier).refresh();
    ref.read(pushControllerProvider.notifier).onSignedIn();
  }

  void _onSignedOut() {
    ref.read(realtimeProvider).stop();
    ref.read(conversationsControllerProvider.notifier).reset();
    ref.read(unreadNotificationsProvider.notifier).set(0);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_signedIn) return;
        ref.read(realtimeProvider).start();
        ref.read(unreadNotificationsProvider.notifier).refresh();
        ref.read(appResumedProvider.notifier).state++;
      case AppLifecycleState.paused || AppLifecycleState.hidden || AppLifecycleState.detached:
        ref.read(realtimeProvider).stop();
      case AppLifecycleState.inactive:
        break; // e.g. the notification shade or a permission dialog: stay connected
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authControllerProvider.select((s) => s.status), (previous, next) {
      if (next == AuthStatus.authenticated && previous != AuthStatus.authenticated) {
        _onSignedIn();
      } else if (next == AuthStatus.unauthenticated) {
        _onSignedOut();
      }
    });
    return widget.child;
  }
}
