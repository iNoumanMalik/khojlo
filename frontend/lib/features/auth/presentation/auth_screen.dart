import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/models/user.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../auth_controller.dart';
import 'google_web_button_stub.dart'
    if (dart.library.js_interop) 'google_web_button_web.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  int _mode = 1; // 0 = sign in, 1 = sign up
  UserRole _role = UserRole.customer;
  // Sign-up needs agreement to the privacy policy (SRS FR-26); never pre-ticked.
  bool _agreed = false;
  bool _showAgreeError = false;

  bool get _isSignUp => _mode == 1;

  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEvents;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      // On web, Google's rendered button signs the user in and reports the
      // result on this stream instead of returning it from a call.
      final auth = ref.read(authControllerProvider.notifier);
      _googleEvents = auth.googleSignInEvents.listen(
        (event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            _finishGoogleSignIn(auth.loginWithGoogleAccount(event.user));
          }
        },
        onError: auth.googleSignInFailed,
      );
      auth.prepareGoogleSignIn();
    }
  }

  @override
  void dispose() {
    _googleEvents?.cancel();
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState!.validate();
    if (_isSignUp && !_agreed) setState(() => _showAgreeError = true);
    if (!valid || (_isSignUp && !_agreed)) return;
    final auth = ref.read(authControllerProvider.notifier);
    final ok = _isSignUp
        ? await auth.register(
            fullName: _name.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            role: _role,
          )
        : await auth.login(_email.text.trim(), _password.text);
    if (!ok || !mounted) return;
    // new customers pick interests; everyone else lands on home
    if (_isSignUp && _role == UserRole.customer) {
      context.go('/interests');
    } else {
      context.go('/home');
    }
  }

  void _continueWithGoogle() =>
      _finishGoogleSignIn(ref.read(authControllerProvider.notifier).loginWithGoogle());

  Future<void> _finishGoogleSignIn(Future<bool> signIn) async {
    final ok = await signIn;
    if (!ok || !mounted) return;
    final user = ref.read(authControllerProvider).user;
    // route brand-new customers (no interests picked yet) through onboarding
    if (user != null && user.role == UserRole.customer && user.interests.isEmpty) {
      context.go('/interests');
    } else {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 40),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_isSignUp ? 'Create your account' : 'Welcome back',
                    style: AppType.serif(size: 28)),
                const SizedBox(height: 6),
                Text(
                  _isSignUp
                      ? 'Join Khojlo to save hidden gems and get notified the moment new ones open nearby.'
                      : 'Sign in to pick up where you left off.',
                  style: AppType.sans(
                      size: 13, height: 1.5, color: AppColors.inkA(0.47)),
                ),
                const SizedBox(height: 22),
                Segmented(
                  options: const ['Sign in', 'Sign up'],
                  activeIndex: _mode,
                  onChanged: (i) => setState(() => _mode = i),
                ),
                if (_isSignUp) ...[
                  const SizedBox(height: 22),
                  Text("I'M HERE TO...", style: AppType.label()),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _RoleCard(
                          title: 'Find places',
                          subtitle: 'Discover & save hidden gems',
                          selected: _role == UserRole.customer,
                          onTap: () =>
                              setState(() => _role = UserRole.customer),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _RoleCard(
                          title: 'List my business',
                          subtitle: 'Get discovered by new customers',
                          selected: _role == UserRole.businessOwner,
                          onTap: () =>
                              setState(() => _role = UserRole.businessOwner),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 22),
                if (_isSignUp) ...[
                  AppField(
                    label: 'Full name',
                    controller: _name,
                    hint: 'Your name',
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Enter your name' : null,
                  ),
                  const SizedBox(height: 16),
                ],
                AppField(
                  label: 'Email',
                  controller: _email,
                  hint: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Enter your email';
                    if (!v.contains('@') || !v.contains('.')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppField(
                  label: 'Password',
                  controller: _password,
                  hint: '••••••••',
                  obscure: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a password';
                    if (_isSignUp && v.length < 8) {
                      return 'At least 8 characters';
                    }
                    return null;
                  },
                ),
                if (!_isSignUp) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: GestureDetector(
                      onTap: () => context.push('/forgot-password'),
                      child: Text('Forgot password?',
                          style: AppType.sans(
                              size: 12.5,
                              weight: FontWeight.w700,
                              color: AppColors.emerald)),
                    ),
                  ),
                ],
                if (_isSignUp) ...[
                  const SizedBox(height: 14),
                  _ConsentCheckbox(
                    value: _agreed,
                    showError: _showAgreeError && !_agreed,
                    onChanged: (v) => setState(() => _agreed = v),
                  ),
                ],
                if (state.error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(message: state.error!),
                ],
                const SizedBox(height: 22),
                PrimaryButton(
                  label: _isSignUp ? 'Create account' : 'Sign in',
                  tone: ButtonTone.emerald,
                  loading: state.loading,
                  onTap: _submit,
                ),
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(child: Hairline()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('OR',
                          style: AppType.mono(
                              size: 10.5, color: AppColors.inkA(0.4))),
                    ),
                    Expanded(child: Hairline()),
                  ],
                ),
                const SizedBox(height: 18),
                if (state.googleLoading)
                  const GhostButton(label: 'Signing in…', onTap: null)
                else if (kIsWeb)
                  LayoutBuilder(
                    builder: (_, constraints) => Center(
                      child: googleWebSignInButton(width: constraints.maxWidth),
                    ),
                  )
                else
                  GhostButton(
                    label: 'Continue with Google',
                    onTap: _continueWithGoogle,
                  ),
                const SizedBox(height: 12),
                // const GhostButton(label: 'Continue with Apple'),
                // const SizedBox(height: 22),
                const SizedBox(height: 22),
                Center(
                  child: GestureDetector(
                    onTap: () => context.push('/privacy'),
                    child: Text.rich(
                      TextSpan(children: [
                        const TextSpan(text: 'How Khojlo uses your data: '),
                        TextSpan(
                          text: 'Privacy Policy',
                          style: AppType.mono(
                              size: 10, weight: FontWeight.w500, color: AppColors.emerald),
                        ),
                      ]),
                      textAlign: TextAlign.center,
                      style: AppType.mono(
                          size: 10, height: 1.6, color: AppColors.inkA(0.4)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.emerald.withValues(alpha: 0.08)
              : AppColors.whiteA(0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.emerald : AppColors.inkA(0.08),
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: selected ? AppColors.emerald : AppColors.inkA(0.13),
                borderRadius: BorderRadius.circular(selected ? 15 : 9),
              ),
            ),
            const SizedBox(height: 10),
            Text(title, style: AppType.sans(size: 13.5, weight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: AppType.sans(
                    size: 11, height: 1.4, color: AppColors.inkA(0.47))),
          ],
        ),
      ),
    );
  }
}

/// "I agree to the Privacy Policy" — the link opens the full policy.
class _ConsentCheckbox extends StatelessWidget {
  const _ConsentCheckbox({
    required this.value,
    required this.showError,
    required this.onChanged,
  });

  final bool value;
  final bool showError;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final base = AppType.sans(size: 12.5, height: 1.45, color: AppColors.inkA(0.7));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                activeColor: AppColors.emerald,
                side: BorderSide(
                    color: showError ? AppColors.plum : AppColors.inkA(0.35), width: 1.5),
                onChanged: (v) => onChanged(v ?? false),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(!value),
                child: Text.rich(
                  TextSpan(style: base, children: [
                    const TextSpan(text: 'I have read and agree to Khojlo’s '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () => context.push('/privacy'),
                        child: Text('Privacy Policy',
                            style: base.copyWith(
                                fontWeight: FontWeight.w700, color: AppColors.emerald)),
                      ),
                    ),
                    const TextSpan(text: ', including how my location and messages are used.'),
                  ]),
                ),
              ),
            ),
          ],
        ),
        if (showError)
          Padding(
            padding: const EdgeInsets.only(left: 34, top: 4),
            child: Text('Please agree to the privacy policy to create an account.',
                style: AppType.sans(size: 11.5, color: AppColors.plum)),
          ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.plum.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.plum.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: AppColors.plum),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message,
                style: AppType.sans(size: 12.5, color: AppColors.plum)),
          ),
        ],
      ),
    );
  }
}
