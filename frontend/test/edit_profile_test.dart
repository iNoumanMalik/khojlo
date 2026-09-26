import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:khojlo/core/media/media_repository.dart';
import 'package:khojlo/core/media/photo_source.dart';
import 'package:khojlo/core/models/business.dart';
import 'package:khojlo/core/models/photo.dart';
import 'package:khojlo/core/models/user.dart';
import 'package:khojlo/core/theme/app_theme.dart';
import 'package:khojlo/features/account/presentation/edit_profile_screen.dart';
import 'package:khojlo/features/auth/auth_controller.dart';
import 'package:khojlo/features/auth/data/auth_repository.dart';
import 'package:khojlo/features/business/business_providers.dart';

class _UnusedRepo implements AuthRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

class _RecordingAuth extends AuthController {
  _RecordingAuth(AppUser user) : super(_UnusedRepo()) {
    state = AuthState(status: AuthStatus.authenticated, user: user);
  }

  Map<String, Object?>? saved;

  @override
  Future<void> saveProfile({
    required String fullName,
    required String avatarTone,
    required String? phone,
    required String? avatarKey,
    required List<String> interests,
  }) async {
    saved = {
      'fullName': fullName,
      'avatarTone': avatarTone,
      'phone': phone,
      'avatarKey': avatarKey,
      'interests': interests.toSet(),
    };
  }
}

class _OnePhoto implements PhotoSource {
  @override
  Future<List<PickedPhoto>> pickMany(int limit) async => const [];

  @override
  Future<PickedPhoto?> pickOne() async => PickedPhoto(bytes: Uint8List(0), name: 'me.jpg');
}

class _FakeMedia extends MediaRepository {
  _FakeMedia() : super(Dio());

  @override
  Future<Photo> upload(Uint8List bytes,
          {required String filename, void Function(double progress)? onProgress}) async =>
      const Photo(key: 'newface', url: 'http://t/newface', thumbUrl: 'http://t/newface/thumb',
          width: 900, height: 900);
}

void main() {
  testWidgets('edit profile: change photo, phone and interests, then save', (tester) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final auth = _RecordingAuth(const AppUser(
      id: 1,
      email: 'ali@khojlo.app',
      fullName: 'Ali Customer',
      role: UserRole.customer,
      avatarTone: 'gold',
      initials: 'AC',
      interests: ['cafes'],
      isVerified: true,
    ));
    final router = GoRouter(initialLocation: '/profile/edit', routes: [
      GoRoute(path: '/profile', builder: (_, __) => const Text('Profile page'), routes: [
        GoRoute(path: 'edit', builder: (_, __) => const EditProfileScreen()),
      ]),
    ]);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => auth),
        photoSourceProvider.overrideWithValue(_OnePhoto()),
        mediaRepositoryProvider.overrideWithValue(_FakeMedia()),
        categoriesProvider.overrideWith((ref) async => const [
              Category(id: 1, slug: 'cafes', name: 'Cafés', tone: 'emerald', emoji: '☕',
                  groupName: 'Food & Drink'),
              Category(id: 2, slug: 'tailors', name: 'Tailors & Fabric', tone: 'emerald',
                  emoji: '🧵', groupName: 'Shopping'),
              Category(id: 3, slug: 'other', name: 'Other', tone: 'ink', isOther: true),
            ]),
      ],
      child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    ));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Add photo'), findsOneWidget);
    expect(find.text('Other'), findsNothing); // not an interest

    await tester.tap(find.text('Add photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Change photo'), findsOneWidget);
    expect(find.text('Remove'), findsOneWidget);

    // Letters can't be typed at all; a too-short number is flagged.
    await tester.enterText(find.byType(TextFormField).at(1), '0300');
    await tester.pump();
    expect(find.textContaining('valid phone number'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(1), '0300 1234567');
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Tailors & Fabric'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Tailors & Fabric'));
    await tester.pump();

    await tester.tap(find.text('Save profile'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(auth.saved, {
      'fullName': 'Ali Customer',
      'avatarTone': 'gold',
      'phone': '0300 1234567',
      'avatarKey': 'newface',
      'interests': {'cafes', 'tailors'},
    });
    expect(find.text('Profile page'), findsOneWidget);
  });
}
