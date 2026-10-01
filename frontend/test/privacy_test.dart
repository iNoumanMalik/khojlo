import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khojlo/core/models/user.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/features/account/presentation/delete_account_sheet.dart';
import 'package:khojlo/features/auth/auth_controller.dart';
import 'package:khojlo/features/auth/data/auth_repository.dart';
import 'package:khojlo/features/auth/presentation/auth_screen.dart';
import 'package:khojlo/features/legal/presentation/privacy_consent_screen.dart';

class _UnusedRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

AppUser _user({bool hasPassword = true, bool needsConsent = false}) => AppUser(
      id: 1,
      email: 'ali@khojlo.app',
      fullName: 'Ali Customer',
      role: UserRole.customer,
      avatarTone: 'gold',
      initials: 'AC',
      interests: const ['cafes'],
      isVerified: true,
      hasPassword: hasPassword,
      needsPrivacyConsent: needsConsent,
    );

class _RecordingAuth extends AuthController {
  _RecordingAuth([AppUser? user]) : super(_UnusedRepo()) {
    state = user == null
        ? const AuthState(status: AuthStatus.unauthenticated)
        : AuthState(status: AuthStatus.authenticated, user: user);
  }

  var registered = 0;
  var accepted = 0;
  final deletes = <String?>[];

  @override
  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    List<String> interests = const [],
  }) async {
    registered++;
    return false;
  }

  @override
  Future<void> acceptPrivacyPolicy() async => accepted++;

  @override
  Future<void> deleteAccount({String? password}) async => deletes.add(password);
}

Future<void> _pump(WidgetTester tester, _RecordingAuth auth, Widget screen) async {
  tester.view.physicalSize = const Size(1170, 2532);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [
    GoRoute(path: '/', builder: (_, __) => screen),
    GoRoute(path: '/privacy', builder: (_, __) => const Scaffold(body: Text('POLICY'))),
    GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [authControllerProvider.overrideWith((_) => auth)],
    child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('the user says whether consent is needed and whether it has a password', () {
    final user = AppUser.fromJson({
      'id': 1,
      'email': 'g@khojlo.app',
      'full_name': 'Gul',
      'role': 'customer',
      'has_password': false,
      'needs_privacy_consent': true,
    });
    expect(user.needsPrivacyConsent, isTrue);
    expect(user.hasPassword, isFalse);
  });

  testWidgets('signing up needs the privacy policy ticked', (tester) async {
    final auth = _RecordingAuth();
    await _pump(tester, auth, const AuthScreen());

    await tester.enterText(find.byType(TextFormField).at(0), 'Ali Customer');
    await tester.enterText(find.byType(TextFormField).at(1), 'ali@khojlo.app');
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Please agree to the privacy policy to create an account.'), findsOneWidget);
    expect(auth.registered, 0);

    await tester.tap(find.byType(Checkbox));
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(auth.registered, 1);
  });

  testWidgets('the consent screen records agreement', (tester) async {
    final auth = _RecordingAuth(_user(needsConsent: true));
    await _pump(tester, auth, const PrivacyConsentScreen());

    expect(find.text('Before you start, Ali'), findsOneWidget);
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    expect(auth.accepted, 1);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('deleting an account asks for the password', (tester) async {
    final auth = _RecordingAuth(_user());
    await _pump(tester, auth, Builder(
      builder: (context) => Scaffold(
        body: TextButton(
            onPressed: () => showDeleteAccountSheet(context), child: const Text('open')),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your password to confirm.'), findsOneWidget);
    expect(auth.deletes, isEmpty);

    await tester.enterText(find.byType(TextFormField), 'password123');
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    expect(auth.deletes, ['password123']);
  });

  testWidgets('Google-only accounts delete without a password', (tester) async {
    final auth = _RecordingAuth(_user(hasPassword: false));
    await _pump(tester, auth, Builder(
      builder: (context) => Scaffold(
        body: TextButton(
            onPressed: () => showDeleteAccountSheet(context), child: const Text('open')),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(TextFormField), findsNothing);
    await tester.tap(find.text('Delete my account'));
    await tester.pumpAndSettle();
    expect(auth.deletes, [null]);
  });
}
