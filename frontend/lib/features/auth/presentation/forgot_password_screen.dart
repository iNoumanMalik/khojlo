import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pinput/pinput.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../data/auth_repository.dart';

enum _Step { email, otp, password, done }

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pin = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();

  _Step _step = _Step.email;
  bool _loading = false;
  String? _error;
  String? _resetToken;
  int _cooldown = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _pin.dispose();
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_cooldown <= 1) {
        t.cancel();
        setState(() => _cooldown = 0);
      } else {
        setState(() => _cooldown--);
      }
    });
  }

  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info =
          await ref.read(authRepositoryProvider).forgotPassword(_email.text.trim());
      setState(() {
        _loading = false;
        _step = _Step.otp;
      });
      _startCooldown(info.resendCooldownSeconds);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = describeApiError(e);
      });
    }
  }

  Future<void> _verifyCode(String code) async {
    if (code.length != 6 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final info = await ref.read(authRepositoryProvider).verifyResetOtp(
            email: _email.text.trim(),
            code: code,
          );
      _timer?.cancel();
      setState(() {
        _loading = false;
        _resetToken = info.token;
        _step = _Step.password;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = describeApiError(e);
      });
      _pin.clear();
    }
  }

  Future<void> _submitNewPassword() async {
    if (!_passwordFormKey.currentState!.validate() || _resetToken == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).resetPassword(
            resetToken: _resetToken!,
            newPassword: _newPassword.text,
          );
      setState(() {
        _loading = false;
        _step = _Step.done;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = describeApiError(e);
      });
    }
  }

  void _goBack() {
    switch (_step) {
      case _Step.email:
        context.pop();
      case _Step.otp:
        setState(() {
          _step = _Step.email;
          _error = null;
        });
      case _Step.password:
        setState(() {
          _step = _Step.otp;
          _error = null;
        });
      case _Step.done:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            if (_step != _Step.done) TopBar(title: _titleFor(_step), onBack: _goBack),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 280),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.06, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: switch (_step) {
                    _Step.email => _EmailStep(
                        key: const ValueKey('email'),
                        formKey: _emailFormKey,
                        controller: _email,
                        loading: _loading,
                        error: _error,
                        onSubmit: _sendCode,
                      ),
                    _Step.otp => _OtpStep(
                        key: const ValueKey('otp'),
                        email: _email.text.trim(),
                        controller: _pin,
                        loading: _loading,
                        error: _error,
                        cooldown: _cooldown,
                        onCompleted: _verifyCode,
                        onResend: _cooldown == 0 ? _sendCode : null,
                      ),
                    _Step.password => _NewPasswordStep(
                        key: const ValueKey('password'),
                        formKey: _passwordFormKey,
                        newPassword: _newPassword,
                        confirmPassword: _confirmPassword,
                        loading: _loading,
                        error: _error,
                        onSubmit: _submitNewPassword,
                      ),
                    _Step.done => _DoneStep(key: const ValueKey('done')),
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _titleFor(_Step step) => switch (step) {
        _Step.email => 'Reset password',
        _Step.otp => 'Enter code',
        _Step.password => 'New password',
        _Step.done => '',
      };
}

class _EmailStep extends StatelessWidget {
  const _EmailStep({
    super.key,
    required this.formKey,
    required this.controller,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Forgot your password?', style: AppType.serif(size: 26)),
          const SizedBox(height: 8),
          Text(
            'Enter the email on your account and we\'ll send you a code to reset it.',
            style: AppType.sans(size: 13, height: 1.5, color: AppColors.inkA(0.53)),
          ),
          const SizedBox(height: 24),
          AppField(
            label: 'Email',
            controller: controller,
            hint: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Enter your email';
              if (!v.contains('@') || !v.contains('.')) return 'Enter a valid email';
              return null;
            },
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(error!),
          ],
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Send code',
            tone: ButtonTone.emerald,
            loading: loading,
            onTap: onSubmit,
          ),
        ],
      ),
    );
  }
}

class _OtpStep extends StatelessWidget {
  const _OtpStep({
    super.key,
    required this.email,
    required this.controller,
    required this.loading,
    required this.error,
    required this.cooldown,
    required this.onCompleted,
    required this.onResend,
  });

  final String email;
  final TextEditingController controller;
  final bool loading;
  final String? error;
  final int cooldown;
  final ValueChanged<String> onCompleted;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    final defaultTheme = PinTheme(
      width: 44,
      height: 52,
      textStyle: AppType.sans(size: 19, weight: FontWeight.w700),
      decoration: BoxDecoration(
        color: AppColors.whiteA(0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.inkA(0.1), width: 1.5),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Text('Check your inbox', style: AppType.serif(size: 26)),
        const SizedBox(height: 8),
        Text(
          'Enter the 6-digit code we sent to $email',
          style: AppType.sans(size: 13, height: 1.5, color: AppColors.inkA(0.53)),
        ),
        const SizedBox(height: 24),
        Center(
          child: Pinput(
            length: 6,
            controller: controller,
            autofocus: true,
            enabled: !loading,
            defaultPinTheme: defaultTheme,
            focusedPinTheme: defaultTheme.copyDecorationWith(
              border: Border.all(color: AppColors.emerald.withValues(alpha: 0.7), width: 1.5),
            ),
            submittedPinTheme: defaultTheme.copyDecorationWith(
              color: AppColors.emerald.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.emerald.withValues(alpha: 0.5), width: 1.5),
            ),
            errorPinTheme: defaultTheme.copyDecorationWith(
              border: Border.all(color: AppColors.plum.withValues(alpha: 0.7), width: 1.5),
            ),
            forceErrorState: error != null,
            onCompleted: onCompleted,
          ),
        ),
        if (loading) ...[
          const SizedBox(height: 16),
          const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
            ),
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 16),
          Center(
            child: Text(error!,
                textAlign: TextAlign.center,
                style: AppType.sans(size: 12.5, color: AppColors.plum)),
          ),
        ],
        const SizedBox(height: 22),
        Center(
          child: cooldown > 0
              ? Text('Resend code in 0:${cooldown.toString().padLeft(2, '0')}',
                  style: AppType.mono(size: 11.5, color: AppColors.inkA(0.4)))
              : GestureDetector(
                  onTap: onResend,
                  child: Text('Resend code',
                      style: AppType.sans(
                          size: 13, weight: FontWeight.w700, color: AppColors.emerald)),
                ),
        ),
      ],
    );
  }
}

class _NewPasswordStep extends StatefulWidget {
  const _NewPasswordStep({
    super.key,
    required this.formKey,
    required this.newPassword,
    required this.confirmPassword,
    required this.loading,
    required this.error,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController newPassword;
  final TextEditingController confirmPassword;
  final bool loading;
  final String? error;
  final VoidCallback onSubmit;

  @override
  State<_NewPasswordStep> createState() => _NewPasswordStepState();
}

class _NewPasswordStepState extends State<_NewPasswordStep> {
  @override
  Widget build(BuildContext context) {
    return Form(
      key: widget.formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text('Set a new password', style: AppType.serif(size: 26)),
          const SizedBox(height: 8),
          Text(
            'Make it something you\'ll remember but others won\'t guess.',
            style: AppType.sans(size: 13, height: 1.5, color: AppColors.inkA(0.53)),
          ),
          const SizedBox(height: 24),
          AppField(
            label: 'New password',
            controller: widget.newPassword,
            hint: '••••••••',
            obscure: true,
            onChanged: (_) => setState(() {}),
            validator: (v) {
              if (v == null || v.isEmpty) return 'Enter a password';
              if (v.length < 8) return 'At least 8 characters';
              return null;
            },
          ),
          const SizedBox(height: 10),
          _PasswordStrengthMeter(password: widget.newPassword.text),
          const SizedBox(height: 16),
          AppField(
            label: 'Confirm password',
            controller: widget.confirmPassword,
            hint: '••••••••',
            obscure: true,
            validator: (v) {
              if (v != widget.newPassword.text) return 'Passwords don\'t match';
              return null;
            },
          ),
          if (widget.error != null) ...[
            const SizedBox(height: 14),
            _ErrorBanner(widget.error!),
          ],
          const SizedBox(height: 22),
          PrimaryButton(
            label: 'Reset password',
            tone: ButtonTone.emerald,
            loading: widget.loading,
            onTap: widget.onSubmit,
          ),
        ],
      ),
    );
  }
}

class _PasswordStrengthMeter extends StatelessWidget {
  const _PasswordStrengthMeter({required this.password});
  final String password;

  int get _score {
    var s = 0;
    if (password.length >= 8) s++;
    if (RegExp(r'[A-Z]').hasMatch(password) && RegExp(r'[a-z]').hasMatch(password)) s++;
    if (RegExp(r'[0-9]').hasMatch(password)) s++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) s++;
    return s;
  }

  (Color, String) get _style => switch (_score) {
        0 || 1 => (AppColors.plum, 'Weak'),
        2 => (AppColors.gold, 'Medium'),
        _ => (AppColors.emerald, 'Strong'),
      };

  @override
  Widget build(BuildContext context) {
    if (password.isEmpty) return const SizedBox.shrink();
    final (color, label) = _style;
    return Row(
      children: [
        for (var i = 0; i < 4; i++) ...[
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 4,
              decoration: BoxDecoration(
                color: i < _score ? color : AppColors.inkA(0.08),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          if (i != 3) const SizedBox(width: 4),
        ],
        const SizedBox(width: 10),
        Text(label, style: AppType.mono(size: 10, color: color)),
      ],
    );
  }
}

class _DoneStep extends StatelessWidget {
  const _DoneStep({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.emerald, Color(0xFF123F34)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: AppShadows.glow(AppColors.emerald),
          ),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 36),
        )
            .animate()
            .scale(
              begin: const Offset(0.4, 0.4),
              end: const Offset(1, 1),
              curve: Curves.elasticOut,
              duration: 600.ms,
            )
            .fadeIn(duration: 250.ms),
        const SizedBox(height: 22),
        Text('Password updated', style: AppType.serif(size: 24)),
        const SizedBox(height: 8),
        Text(
          'You can now sign in with your new password.',
          textAlign: TextAlign.center,
          style: AppType.sans(size: 13, height: 1.5, color: AppColors.inkA(0.53)),
        ),
        const SizedBox(height: 28),
        PrimaryButton(
          label: 'Back to sign in',
          tone: ButtonTone.emerald,
          onTap: () => context.go('/auth'),
        ),
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
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
            child: Text(message, style: AppType.sans(size: 12.5, color: AppColors.plum)),
          ),
        ],
      ),
    );
  }
}
