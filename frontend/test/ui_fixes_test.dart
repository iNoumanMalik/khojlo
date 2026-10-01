// Home search bar, home card rows and the "Surprise me" deck.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khojlo/core/models/business.dart';
import 'package:khojlo/core/models/feed.dart';
import 'package:khojlo/core/models/user.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/core/widgets/search_pill.dart';
import 'package:khojlo/features/auth/auth_controller.dart';
import 'package:khojlo/features/auth/data/auth_repository.dart';
import 'package:khojlo/features/discovery/discovery_providers.dart';
import 'package:khojlo/features/discovery/presentation/home_screen.dart';
import 'package:khojlo/features/prototype/surprise_screen.dart';

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

Map<String, dynamic> cardJson(int id, String name, {bool promo = false}) => {
      'id': id,
      'name': name,
      'tagline': 'A new place',
      'tone': 'emerald',
      'rating': 4.6,
      'review_count': 12,
      'is_verified': true,
      if (promo) 'active_campaign': {'id': 3, 'name': 'Grand Opening'},
    };

final _feed = Feed.fromJson({
  'greeting': 'Good evening, explorer',
  'headline': '12 hidden gems',
  'categories': [],
  'sections': [
    {
      'key': 'interest',
      'title': 'Because you like cafés',
      'layout': 'horizontal',
      'businesses': [cardJson(1, 'Brew & Bloom', promo: true), cardJson(2, 'Mornings Café')],
    }
  ],
});

void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

void main() {
  testWidgets('the whole home search bar opens Explore, including its top edge',
      (tester) async {
    _phone(tester);
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/explore', builder: (_, __) => const Text('Explore page')),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => _SignedIn()),
        feedProvider.overrideWith((ref) async => _feed),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ));
    await _settle(tester);

    // The cards under the featured card fit, promotion badge included (no overflow).
    expect(find.text('Promotion'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // It used to take taps only in its bottom strip (it was shifted with a Transform).
    final pill = tester.getRect(find.byType(SearchPill));
    await tester.tapAt(pill.topCenter + const Offset(0, 4));
    await _settle(tester);
    expect(find.text('Explore page'), findsOneWidget);
  });

  testWidgets('Surprise me deals every business once, then offers a reshuffle',
      (tester) async {
    _phone(tester);
    var deals = 0;
    final deck = [for (var i = 1; i <= 3; i++) BusinessCard.fromJson(cardJson(i, 'Place $i'))];
    await tester.pumpWidget(ProviderScope(
      overrides: [
        surpriseProvider.overrideWith((ref) async {
          deals++;
          return deck;
        }),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const SurpriseScreen()),
    ));
    await _settle(tester);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(find.text('Place 1'), findsOneWidget);

    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Skip'));
      await _settle(tester);
    }
    expect(find.text('You’ve seen all 3 places'), findsOneWidget); // no wrapping around

    await tester.tap(find.text('Shuffle again'));
    await _settle(tester);
    expect(find.text('1 of 3'), findsOneWidget);
    expect(deals, 2);
  });
}
