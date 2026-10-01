import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/moderation.dart';
import '../../features/account/presentation/edit_profile_screen.dart';
import '../../features/account/presentation/guidelines_screen.dart';
import '../../features/admin/presentation/admin_business_screen.dart';
import '../../features/admin/presentation/admin_report_screen.dart';
import '../../features/admin/presentation/admin_screen.dart';
import '../../features/admin/presentation/admin_user_screen.dart';
import '../../features/account/presentation/profile_screen.dart';
import '../../features/account/presentation/saved_screen.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/auth/presentation/auth_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/interests_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/business/presentation/business_tab_screen.dart';
import '../../features/business/presentation/edit_business_screen.dart';
import '../../features/business/presentation/edit_hours_screen.dart';
import '../../features/business/presentation/edit_photos_screen.dart';
import '../../features/business/presentation/registration_stepper.dart';
import '../../features/business/presentation/verification_screen.dart';
import '../../features/chat/presentation/conversation_screen.dart';
import '../../features/chat/presentation/messages_screen.dart';
import '../../features/discovery/presentation/business_detail_screen.dart';
import '../../features/discovery/presentation/home_screen.dart';
import '../../features/legal/presentation/privacy_consent_screen.dart';
import '../../features/legal/presentation/privacy_policy_screen.dart';
import '../../features/maps/presentation/map_screen.dart';
import '../../features/promotions/presentation/campaign_screen.dart';
import '../../features/promotions/presentation/promotions_screen.dart';
import '../../features/notifications/presentation/notification_settings_screen.dart';
import '../../features/notifications/presentation/notifications_screen.dart';
import '../../features/reviews/presentation/my_reviews_screen.dart';
import '../../features/reviews/presentation/reviews_screen.dart';
import '../../features/prototype/kai_screen.dart';
import '../../features/prototype/surprise_screen.dart';
import '../../features/search/presentation/compare_screen.dart';
import '../../features/search/presentation/search_screen.dart';
import '../theme/app_colors.dart';
import '../ui/messenger.dart';
import 'shell_scaffold.dart';

final _rootKey = rootNavigatorKey;
final _shellKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod auth changes into a Listenable the router can refresh on.
  final refresh = ValueNotifier(0);
  ref.listen(authControllerProvider.select((s) => s.status), (_, __) {
    refresh.value++;
  });
  ref.listen(authControllerProvider.select((s) => s.user?.needsPrivacyConsent), (_, __) {
    refresh.value++;
  });
  ref.onDispose(refresh.dispose);

  // A page opened directly (a link, or refreshing the browser on /admin) while the
  // session is still being restored: shown once sign-in is confirmed, not lost.
  String? pendingLocation;

  return GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final status = auth.status;
      final loc = state.matchedLocation;
      // The policy itself is readable by anyone, signed in or not.
      if (loc == '/privacy' && status != AuthStatus.unknown) return null;
      final onboarding = loc == '/onboarding' ||
          loc == '/auth' ||
          loc == '/splash' ||
          loc == '/forgot-password';

      if (status == AuthStatus.unknown) {
        if (loc != '/splash' && !onboarding) pendingLocation = state.uri.toString();
        return loc == '/splash' ? null : '/splash';
      }
      if (status == AuthStatus.unauthenticated) {
        pendingLocation = null;
        return onboarding && loc != '/splash' ? null : '/onboarding';
      }
      // authenticated: agree to the privacy policy before anything else (SRS FR-31)
      if (auth.user?.needsPrivacyConsent ?? false) {
        return loc == '/privacy-consent' ? null : '/privacy-consent';
      }
      if (onboarding || loc == '/privacy-consent') {
        final next = pendingLocation;
        pendingLocation = null;
        return next ?? '/home';
      }
      // SEC-3: the admin panel is for admins only (the API refuses everyone else too).
      if (loc.startsWith('/admin') && !(auth.user?.isAdmin ?? false)) {
        return '/home';
      }
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
      GoRoute(
          path: '/privacy-consent',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const PrivacyConsentScreen()),
      GoRoute(
          path: '/privacy',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const PrivacyPolicyScreen()),

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
        path: '/campaign/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => CampaignScreen(campaignId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/business/:id/reviews',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => ReviewsScreen(
          businessId: int.parse(s.pathParameters['id']!),
          businessName: s.uri.queryParameters['name'] ?? '',
        ),
      ),
      GoRoute(
        path: '/register-business',
        parentNavigatorKey: _rootKey,
        builder: (_, __) => const RegistrationStepper(),
      ),
      GoRoute(
        path: '/edit-business/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            EditBusinessScreen(businessId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/edit-hours/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            EditHoursScreen(businessId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/edit-photos/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            EditPhotosScreen(businessId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/offers/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            PromotionsScreen(businessId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
          path: '/profile',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const ProfileScreen()),
      GoRoute(
          path: '/edit-profile',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const EditProfileScreen()),
      GoRoute(
          path: '/saved',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const SavedScreen()),
      GoRoute(
          path: '/notifications',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const NotificationsScreen()),
      GoRoute(
          path: '/notification-settings',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(
          path: '/surprise',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const SurpriseScreen()),
      GoRoute(
          path: '/kai',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const KaiScreen()),
      GoRoute(
        path: '/conversations/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) =>
            ConversationScreen(conversationId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
          path: '/compare',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const CompareScreen()),
      GoRoute(
          path: '/my-reviews',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const MyReviewsScreen()),
      // ── Module 8: admin and moderation ──
      GoRoute(
          path: '/admin',
          parentNavigatorKey: _rootKey,
          builder: (_, s) =>
              AdminScreen(initial: AdminSection.fromName(s.uri.queryParameters['section']))),
      GoRoute(
        path: '/admin/business/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => AdminBusinessScreen(businessId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/admin/report/:kind/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => AdminReportScreen(
          kind: ReportKind.fromApi(s.pathParameters['kind']),
          targetId: int.parse(s.pathParameters['id']!),
        ),
      ),
      GoRoute(
        path: '/admin/user/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => AdminUserScreen(userId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
        path: '/verification/:id',
        parentNavigatorKey: _rootKey,
        builder: (_, s) => VerificationScreen(businessId: int.parse(s.pathParameters['id']!)),
      ),
      GoRoute(
          path: '/guidelines',
          parentNavigatorKey: _rootKey,
          builder: (_, __) => const GuidelinesScreen()),
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
