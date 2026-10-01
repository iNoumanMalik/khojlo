import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/models/user.dart';
import '../../core/network/api_client.dart';
import '../notifications/push_controller.dart';
import 'data/auth_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.loading = false,
    this.googleLoading = false,
    this.error,
  });

  final AuthStatus status;
  final AppUser? user;
  final bool loading;
  final bool googleLoading;
  final String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  AuthState copyWith({
    AuthStatus? status,
    AppUser? user,
    bool? loading,
    bool? googleLoading,
    String? error,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      loading: loading ?? this.loading,
      googleLoading: googleLoading ?? this.googleLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.watch(authRepositoryProvider),
    // While still signed in: stop push notifications to this device.
    beforeLogout: () => ref.read(pushControllerProvider.notifier).unregister(),
  )..bootstrap();
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._repo, {Future<void> Function()? beforeLogout})
      : _beforeLogout = beforeLogout,
        super(const AuthState());

  final AuthRepository _repo;
  final Future<void> Function()? _beforeLogout;

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

  /// Mobile: runs Google's account picker, then signs in to Khojlo.
  Future<bool> loginWithGoogle() => _loginWithGoogle(_repo.signInWithGoogle);

  /// Web: signs in to Khojlo with an account Google's rendered button already
  /// signed in (delivered on [googleSignInEvents]).
  Future<bool> loginWithGoogleAccount(GoogleSignInAccount account) =>
      _loginWithGoogle(() => _repo.signInWithGoogleAccount(account));

  /// Must complete before Google's web button can render.
  Future<void> prepareGoogleSignIn() => _repo.ensureGoogleSignInReady();

  Stream<GoogleSignInAuthenticationEvent> get googleSignInEvents =>
      _repo.googleAuthEvents;

  Future<bool> _loginWithGoogle(Future<AppUser> Function() signIn) async {
    state = state.copyWith(googleLoading: true, clearError: true);
    try {
      final user = await signIn();
      state = state.copyWith(
          status: AuthStatus.authenticated, user: user, googleLoading: false);
      return true;
    } catch (e) {
      googleSignInFailed(e);
      return false;
    }
  }

  void googleSignInFailed(Object error) {
    if (error is GoogleSignInException) {
      final canceled = error.code == GoogleSignInExceptionCode.canceled;
      state = state.copyWith(
        googleLoading: false,
        error: canceled ? null : 'Google sign-in failed. Please try again.',
      );
    } else {
      state = state.copyWith(googleLoading: false, error: describeApiError(error));
    }
  }

  /// Verifies the current user's email with an OTP. Throws on failure (the
  /// caller shows the specific error inline); on success syncs [state.user].
  Future<void> verifyEmailCode(String code) async {
    final user = await _repo.verifyEmail(code);
    state = state.copyWith(user: user);
  }

  /// Records agreement to the current privacy policy; throws so the consent
  /// screen can show what went wrong.
  Future<void> acceptPrivacyPolicy() async {
    final user = await _repo.acceptPrivacyPolicy();
    state = state.copyWith(user: user);
  }

  /// Deletes the account for good, then signs out. Throws (e.g. wrong
  /// password) so the confirmation sheet can show the error.
  Future<void> deleteAccount({String? password}) async {
    await _repo.deleteAccount(password: password);
    try {
      // The server already forgot this device; this also drops its push token.
      await _beforeLogout?.call();
    } catch (_) {}
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> setInterests(List<String> interests) async {
    try {
      final user = await _repo.setInterests(interests);
      state = state.copyWith(user: user);
    } catch (_) {/* non-fatal */}
  }

  /// Saves the edit-profile screen; throws so the screen can show what went wrong.
  Future<void> saveProfile({
    required String fullName,
    required String avatarTone,
    required String? phone,
    required String? avatarKey,
    required List<String> interests,
  }) async {
    var user = await _repo.saveProfile(
      fullName: fullName,
      avatarTone: avatarTone,
      phone: phone,
      avatarKey: avatarKey,
    );
    if (!_sameItems(user.interests, interests)) {
      user = await _repo.setInterests(interests);
    }
    state = state.copyWith(user: user);
  }

  static bool _sameItems(List<String> a, List<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);

  Future<void> logout() async {
    try {
      await _beforeLogout?.call();
    } catch (_) {/* never block signing out */}
    await _repo.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}
