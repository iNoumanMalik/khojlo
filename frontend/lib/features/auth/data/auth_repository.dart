import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/user.dart';
import '../../../core/providers.dart';
import '../../../core/storage/token_storage.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    ref.watch(dioProvider),
    ref.watch(tokenStorageProvider),
  );
});

class AuthRepository {
  AuthRepository(this._dio, this._tokens);

  final Dio _dio;
  final TokenStorage _tokens;

  Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    List<String> interests = const [],
  }) async {
    await _dio.post('/auth/register', data: {
      'full_name': fullName,
      'email': email,
      'password': password,
      'role': roleToString(role),
      'interests': interests,
    });
    return login(email: email, password: password);
  }

  Future<AppUser> login({required String email, required String password}) async {
    final res = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
      options: Options(extra: {'skipAuth': true}),
    );
    await _tokens.save(
      access: res.data['access_token'] as String,
      refresh: res.data['refresh_token'] as String,
    );
    return me();
  }

  Future<AppUser> me() async {
    final res = await _dio.get('/users/me');
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AppUser> updateProfile({String? fullName, String? avatarTone}) async {
    final res = await _dio.patch('/users/me', data: {
      if (fullName != null) 'full_name': fullName,
      if (avatarTone != null) 'avatar_tone': avatarTone,
    });
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AppUser> setInterests(List<String> interests) async {
    final res = await _dio.put('/users/me/interests', data: {'interests': interests});
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> logout() => _tokens.clear();

  Future<bool> hasToken() async => (await _tokens.accessToken) != null;
}
