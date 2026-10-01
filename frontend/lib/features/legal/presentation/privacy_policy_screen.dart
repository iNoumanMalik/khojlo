import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../privacy_policy.dart';

/// The full privacy policy. Open to everyone, signed in or not.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Column(
        children: [
          TopBar(
            title: 'Privacy policy',
            subtitle: 'Effective $kPrivacyPolicyEffective',
            onBack: () => context.canPop() ? context.pop() : context.go('/onboarding'),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 0, 22, 48),
              children: [
                for (final section in kPrivacyPolicy) ...[
                  Text(section.title.toUpperCase(), style: AppType.label()),
                  const SizedBox(height: 8),
                  for (final paragraph in section.paragraphs)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(paragraph,
                          style: AppType.sans(
                              size: 13.5, height: 1.55, color: AppColors.inkA(0.78))),
                    ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
