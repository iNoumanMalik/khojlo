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
      scaffoldMessengerKey: rootMessengerKey,
      builder: (context, child) => SessionServices(child: child!),
    );
  }
}
