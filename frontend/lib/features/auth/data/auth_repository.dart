import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/models/otp.dart';
import '../../../core/models/user.dart';
import '../../../core/network/google_auth_config.dart';
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
  bool _googleSignInReady = false;

  Future<void> _ensureGoogleSignInReady() async {
    if (_googleSignInReady) return;
    await GoogleSignIn.instance.initialize(
      serverClientId: GoogleAuthConfig.serverClientId,
    );
    _googleSignInReady = true;
  }

  /// Signs in with Google, then exchanges the ID token for our own session
  /// tokens (the backend finds-or-creates the user and issues a [TokenPair]).
  Future<AppUser> signInWithGoogle() async {
    await _ensureGoogleSignInReady();
    final account = await GoogleSignIn.instance.authenticate();
    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google sign-in did not return an ID token.');
    }
    final res = await _dio.post(
      '/auth/google',
      data: {'id_token': idToken},
      options: Options(extra: {'skipAuth': true}),
    );
    await _tokens.save(
      access: res.data['access_token'] as String,
      refresh: res.data['refresh_token'] as String,
    );
    return me();
  }

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

  // ── email verification ──

  Future<OtpSentInfo> sendVerificationEmail() async {
    final res = await _dio.post('/auth/email/verify/send');
    return OtpSentInfo.fromJson(res.data as Map<String, dynamic>);
  }

  Future<AppUser> verifyEmail(String code) async {
    final res = await _dio.post('/auth/email/verify', data: {'code': code});
    return AppUser.fromJson(res.data as Map<String, dynamic>);
  }

  // ── forgot / reset password ──

  Future<OtpSentInfo> forgotPassword(String email) async {
    final res = await _dio.post(
      '/auth/password/forgot',
      data: {'email': email},
      options: Options(extra: {'skipAuth': true}),
    );
    return OtpSentInfo.fromJson(res.data as Map<String, dynamic>);
  }

  Future<ResetTokenInfo> verifyResetOtp({required String email, required String code}) async {
    final res = await _dio.post(
      '/auth/password/forgot/verify',
      data: {'email': email, 'code': code},
      options: Options(extra: {'skipAuth': true}),
    );
    return ResetTokenInfo.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> resetPassword({required String resetToken, required String newPassword}) async {
    await _dio.post(
      '/auth/password/reset',
      data: {'reset_token': resetToken, 'new_password': newPassword},
      options: Options(extra: {'skipAuth': true}),
    );
  }
}
