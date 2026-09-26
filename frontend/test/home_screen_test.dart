import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khojlo/core/models/user.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/core/widgets/avatar.dart';
import 'package:khojlo/features/auth/auth_controller.dart';
import 'package:khojlo/features/auth/data/auth_repository.dart';
import 'package:khojlo/features/discovery/discovery_providers.dart';
import 'package:khojlo/features/discovery/presentation/home_screen.dart';

class _UnusedRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _SignedIn extends AuthController {
  _SignedIn() : super(_UnusedRepo()) {
    state = const AuthState(
      status: AuthStatus.authenticated,
      user: AppUser(
        id: 1,
        email: 'ali@khojlo.app',
        fullName: 'Ali Customer',
        role: UserRole.customer,
        avatarTone: 'gold',
        initials: 'AC',
        interests: [],
        isVerified: true,
      ),
    );
  }
}

void main() {
  testWidgets('a failed feed still shows the header, so Profile stays reachable',
      (tester) async {
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/profile', builder: (_, __) => const Text('Profile page')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => _SignedIn()),
        feedProvider.overrideWith(
            (ref) async => throw DioException(requestOptions: RequestOptions(path: '/feed'))),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Couldn’t load your feed'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text('AC'), findsOneWidget);

    await tester.tap(find.byType(KhojloAvatar));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Profile page'), findsOneWidget);
  });
}
