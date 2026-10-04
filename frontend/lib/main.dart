import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/firebase_setup.dart';
import 'core/router/app_router.dart';
import 'core/router/session_services.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/messenger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Push notifications need Firebase; the app works without it (push stays off).
  final firebaseReady = await initFirebase();
  runApp(ProviderScope(
    overrides: [firebaseReadyProvider.overrideWithValue(firebaseReady)],
    child: const KhojloApp(),
  ));
}

/// Smooth, consistent scrolling on every platform: bounce at the ends (no stretch or
/// glow), and mouse/trackpad drags on the web.
class KhojloScrollBehavior extends MaterialScrollBehavior {
  const KhojloScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildOverscrollIndicator(
          BuildContext context, Widget child, ScrollableDetails details) =>
      child;

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class KhojloApp extends ConsumerWidget {
  const KhojloApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Khojlo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
      scrollBehavior: const KhojloScrollBehavior(),
      scaffoldMessengerKey: rootMessengerKey,
      // BackdropGroup: the glass blurs on a screen share one backdrop capture.
      builder: (context, child) => BackdropGroup(child: SessionServices(child: child!)),
    );
  }
}
