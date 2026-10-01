import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/user.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../../auth/auth_controller.dart';
import '../privacy_policy.dart';

/// Shown after sign-in until the user agrees to the current privacy policy: Google
/// sign-ups, accounts from before consent was recorded, and everyone after the policy
/// changes (SRS FR-31). The router keeps the rest of the app behind it.
class PrivacyConsentScreen extends ConsumerStatefulWidget {
  const PrivacyConsentScreen({super.key});

  @override
  ConsumerState<PrivacyConsentScreen> createState() => _PrivacyConsentScreenState();
}

class _PrivacyConsentScreenState extends ConsumerState<PrivacyConsentScreen> {
  bool _saving = false;
  String? _error;

  Future<void> _agree() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(authControllerProvider.notifier).acceptPrivacyPolicy();
      if (!mounted) return;
      final user = ref.read(authControllerProvider).user;
      // New Google customers still pick their interests.
      context.go(user != null && user.role == UserRole.customer && user.interests.isEmpty
          ? '/interests'
          : '/home');
    } catch (e) {
      if (mounted) setState(() => _error = describeApiError(e));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _signOut() async {
    await ref.read(authControllerProvider.notifier).logout();
    if (mounted) context.go('/onboarding');
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(authControllerProvider.select((s) => s.user?.fullName)) ?? '';
    final first = name.split(' ').first;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
          children: [
            const Icon(Icons.privacy_tip_outlined, size: 34, color: AppColors.emerald),
            const SizedBox(height: 16),
            Text(first.isEmpty ? 'Your privacy' : 'Before you start, $first',
                style: AppType.serif(size: 28)),
            const SizedBox(height: 6),
            Text(
              'Here’s what Khojlo does with your data. Please read it and agree to continue.',
              style: AppType.sans(size: 13, height: 1.5, color: AppColors.inkA(0.55)),
            ),
            const SizedBox(height: 22),
            for (final (title, detail) in kPrivacyHighlights)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 2),
                      child: Icon(Icons.check_circle_outline_rounded,
                          size: 18, color: AppColors.emerald),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppType.sans(size: 14, weight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          Text(detail,
                              style: AppType.sans(
                                  size: 12.5, height: 1.45, color: AppColors.inkA(0.6))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => context.push('/privacy'),
              child: Text('Read the full privacy policy',
                  style: AppType.sans(
                      size: 13, weight: FontWeight.w700, color: AppColors.emerald)),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: AppType.sans(size: 12.5, color: AppColors.plum)),
            ],
            const SizedBox(height: 28),
            PrimaryButton(
              label: 'I agree',
              tone: ButtonTone.emerald,
              loading: _saving,
              onTap: _saving ? null : _agree,
            ),
            const SizedBox(height: 12),
            GhostButton(label: 'Not now — sign out', onTap: _saving ? null : _signOut),
          ],
        ),
      ),
    );
  }
}
