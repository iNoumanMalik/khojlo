import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pinput/pinput.dart';

import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_typography.dart';
import '../auth_controller.dart';
import '../data/auth_repository.dart';

/// Opens the "verify your email" OTP flow as a bottom sheet. Sends a code as
/// soon as it opens.
Future<void> showEmailVerificationSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _EmailVerificationSheet(),
  );
}

class _EmailVerificationSheet extends ConsumerStatefulWidget {
  const _EmailVerificationSheet();

  @override
  ConsumerState<_EmailVerificationSheet> createState() => _EmailVerificationSheetState();
}

class _EmailVerificationSheetState extends ConsumerState<_EmailVerificationSheet> {
  final _pin = TextEditingController();
  Timer? _timer;

  bool _sending = true;
  bool _verifying = false;
  bool _success = false;
  String? _error;
  int _cooldown = 0;

  @override
  void initState() {
    super.initState();
    _send();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pin.dispose();
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

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final info = await ref.read(authRepositoryProvider).sendVerificationEmail();
      _startCooldown(info.resendCooldownSeconds);
    } catch (e) {
      setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify(String code) async {
    if (code.length != 6 || _verifying) return;
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).verifyEmailCode(code);
      _timer?.cancel();
      setState(() {
        _verifying = false;
        _success = true;
      });
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      setState(() {
        _verifying = false;
        _error = describeApiError(e);
      });
      _pin.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(authControllerProvider).user?.email ?? '';

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

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.inkA(0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 22),
            if (_success) ...[
              _SuccessMark(),
              const SizedBox(height: 16),
              Text('Email verified', style: AppType.serif(size: 22)),
              const SizedBox(height: 6),
              Text('Your account is now fully verified.',
                  style: AppType.sans(size: 13, color: AppColors.inkA(0.53))),
            ] else ...[
              Text('Verify your email', style: AppType.serif(size: 22)),
              const SizedBox(height: 6),
              Text(
                _sending
                    ? 'Sending a code to $email…'
                    : 'Enter the 6-digit code we sent to $email',
                style: AppType.sans(size: 13, height: 1.5, color: AppColors.inkA(0.53)),
              ),
              const SizedBox(height: 22),
              if (_sending)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: CircularProgressIndicator(color: AppColors.emerald),
                  ),
                )
              else
                Center(
                  child: Pinput(
                    length: 6,
                    controller: _pin,
                    autofocus: true,
                    enabled: !_verifying,
                    defaultPinTheme: defaultTheme,
                    focusedPinTheme: defaultTheme.copyDecorationWith(
                      border: Border.all(
                          color: AppColors.emerald.withValues(alpha: 0.7), width: 1.5),
                    ),
                    submittedPinTheme: defaultTheme.copyDecorationWith(
                      color: AppColors.emerald.withValues(alpha: 0.08),
                      border: Border.all(
                          color: AppColors.emerald.withValues(alpha: 0.5), width: 1.5),
                    ),
                    errorPinTheme: defaultTheme.copyDecorationWith(
                      border: Border.all(
                          color: AppColors.plum.withValues(alpha: 0.7), width: 1.5),
                    ),
                    forceErrorState: _error != null,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onCompleted: _verify,
                  ),
                ),
              if (_verifying) ...[
                const SizedBox(height: 16),
                const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 16),
                _ErrorText(_error!),
              ],
              const SizedBox(height: 22),
              Center(
                child: _cooldown > 0
                    ? Text(
                        'Resend code in 0:${_cooldown.toString().padLeft(2, '0')}',
                        style: AppType.mono(size: 11.5, color: AppColors.inkA(0.4)),
                      )
                    : GestureDetector(
                        onTap: _sending ? null : _send,
                        child: Text(
                          'Resend code',
                          style: AppType.sans(
                              size: 13, weight: FontWeight.w700, color: AppColors.emerald),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SuccessMark extends StatelessWidget {
  const _SuccessMark();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.emerald, Color(0xFF123F34)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: AppShadows.glow(AppColors.emerald),
        ),
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 32),
      ),
    )
        .animate()
        .scale(
          begin: const Offset(0.4, 0.4),
          end: const Offset(1, 1),
          curve: Curves.elasticOut,
          duration: 550.ms,
        )
        .fadeIn(duration: 200.ms);
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: AppType.sans(size: 12.5, color: AppColors.plum),
      ),
    );
  }
}
