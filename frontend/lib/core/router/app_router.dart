import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/account/presentation/profile_screen.dart';
import '../../features/account/presentation/saved_screen.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/interests_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/business/presentation/business_tab_screen.dart';
import '../../features/business/presentation/offers_screen.dart';
import '../../features/business/presentation/registration_stepper.dart';
import '../../features/discovery/presentation/business_detail_screen.dart';
import '../../features/discovery/presentation/home_screen.dart';
import '../../features/prototype/admin_screen.dart';
import '../../features/prototype/chat_screens.dart';
import '../../features/prototype/compare_screen.dart';
import '../../features/prototype/map_screen.dart';
import '../../features/prototype/notifications_screen.dart';
import '../../features/prototype/reviews_screen.dart';
import '../../features/prototype/search_screen.dart';
import '../../features/prototype/surprise_screen.dart';
import '../theme/app_colors.dart';
import 'shell_scaffold.dart';

final _rootKey = GlobalKey<NavigatorState>();
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod auth changes into a Listenable the router can refresh on.
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider.select((s) => s.status), (_, __) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final loc = state.matchedLocation;
      final onboarding = loc == '/onboarding' ||
          loc == '/auth' ||
          loc == '/splash' ||
          loc == '/forgot-password';

      if (status == AuthStatus.unknown) {
        return loc == '/splash' ? null : '/splash';
      }
      if (status == AuthStatus.unauthenticated) {
        return onboarding && loc != '/splash' ? null : '/onboarding';
      }
      // authenticated
      if (onboarding) return '/home';
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const _Splash()),
      GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
      GoRoute(path: '/auth', builder: (_, __) => const AuthScreen()),
      GoRoute(
          path: '/forgot-password',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const ForgotPasswordScreen()),
      GoRoute(path: '/interests', builder: (_, __) => const InterestsScreen()),

      // ── primary tab shell ──
      StatefulShellRoute.indexedStack(
        parentNavigatorKey: _rootKey,
        builder: (_, __, shell) => ShellScaffold(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellKey,
            routes: [GoRoute(path: '/home', builder: (_, __) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/explore', builder: (_, __) => const SearchScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/map', builder: (_, __) => const MapScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/chat', builder: (_, __) => const MessagesScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: '/business', builder: (_, __) => const BusinessTabScreen())],
          ),
        ],
      ),

      // ── pushed detail routes (above the shell) ──
      GoRoute(
        path: '/business/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            BusinessDetailScreen(id: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/register-business',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const RegistrationStepper(),
      ),
      GoRoute(
        path: '/offers/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            OffersScreen(businessId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
          path: '/profile',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const ProfileScreen()),
      GoRoute(
          path: '/saved',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const SavedScreen()),
      GoRoute(
          path: '/notifications',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(
          path: '/surprise',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const SurpriseScreen()),
      GoRoute(
          path: '/kai',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const KaiScreen()),
      GoRoute(
          path: '/conversation',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const ConversationScreen()),
      GoRoute(
          path: '/compare',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const CompareScreen()),
      GoRoute(
          path: '/reviews',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const ReviewsScreen()),
      GoRoute(
          path: '/admin',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const AdminScreen()),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.emerald),
      ),
    );
  }
}
