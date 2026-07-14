import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/user.dart';
import '../../core/network/api_client.dart';
import 'data/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.loading = false,
    this.error,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool loading;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? loading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      loading: loading ?? this.loading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(ref.watch(authRepositoryProvider))..bootstrap();
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo) : super(const AuthState());

  final AuthRepository _repo;

  /// Restore a session from a stored token on launch.
  Future<void> bootstrap() async {
    if (!await _repo.hasToken()) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }
    try {
      final user = await _repo.me();
      state = state.copyWith(status: AuthStatus.authenticated, user: user);
    } catch (_) {
      await _repo.logout();
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  Future<bool> login(String email, String password) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final user = await _repo.login(email: email, password: password);
      state = state.copyWith(
          status: AuthStatus.authenticated, user: user, loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: describeApiError(e));
      return false;
    }
  }

  Future<bool> register({
    required String fullName,
    required String email,
    required String password,
    required UserRole role,
    List<String> interests = const [],
  }) async {
    state = state.copyWith(loading: true, clearError: true);
    try {
      final user = await _repo.register(
        fullName: fullName,
        email: email,
        password: password,
        role: role,
        interests: interests,
      );
      state = state.copyWith(
          status: AuthStatus.authenticated, user: user, loading: false);
      return true;
    } catch (e) {
      state = state.copyWith(loading: false, error: describeApiError(e));
      return false;
    }
  }

  Future<void> setInterests(List<String> interests) async {
    try {
      final user = await _repo.setInterests(interests);
      state = state.copyWith(user: user);
    } catch (_) {/* non-fatal */}
  }

  Future<void> updateProfile({String? fullName, String? avatarTone}) async {
    final user = await _repo.updateProfile(fullName: fullName, avatarTone: avatarTone);
    state = state.copyWith(user: user);
  }

  Future<void> logout() async {
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
