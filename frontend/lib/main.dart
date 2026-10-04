import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/push/firebase_setup.dart';
import 'core/router/app_router.dart';
import 'core/router/session_services.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';
import 'core/ui/messenger.dart';
import 'core/ui/splash_overlay.dart';
import 'features/auth/auth_controller.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  warmUpSplashFonts();
  // Push notifications need Firebase; the app works without it (push stays off).
  // It starts while the launch animation plays, not before the first frame.
  runApp(KhojloRoot(firebaseReady: initFirebase()));
}

/// The launch animation over the app. The app is built once Firebase has started
/// (push needs to know whether it did) — the animation covers that wait, and the
/// session restore after it.
class KhojloRoot extends StatefulWidget {
  const KhojloRoot({super.key, required this.firebaseReady});
  final Future<bool> firebaseReady;

  @override
  State<KhojloRoot> createState() => _KhojloRootState();
}

class _KhojloRootState extends State<KhojloRoot> {
  ProviderContainer? _container;
  bool _sessionKnown = false;

  @override
  void initState() {
    super.initState();
    widget.firebaseReady.then((ready) {
      if (!mounted) return;
      final container = ProviderContainer(
          overrides: [firebaseReadyProvider.overrideWithValue(ready)]);
      container.listen(
        authControllerProvider.select((s) => s.status != AuthStatus.unknown),
        (_, known) => setState(() => _sessionKnown = known),
        fireImmediately: true,
      );
      setState(() => _container = container);
    });
  }

  @override
  void dispose() {
    _container?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final container = _container;
    return MediaQuery.fromView(
      view: View.of(context),
      child: SplashOverlay(
        ready: _sessionKnown,
        child: container == null
            ? const ColoredBox(color: AppColors.cream)
            : UncontrolledProviderScope(container: container, child: const KhojloApp()),
      ),
    );
  }
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
