import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/widgets.dart';

/// Loading placeholder for the owner's edit screens.
class OwnerFormSkeleton extends StatelessWidget {
  const OwnerFormSkeleton({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TopBar(title: title, onBack: () => context.pop()),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            children: [
              for (var i = 0; i < 5; i++) ...[
                const SkeletonBox(height: 48, radius: 16),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Load failure with a retry, for the owner's edit screens.
class OwnerLoadError extends StatelessWidget {
  const OwnerLoadError({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TopBar(title: title, onBack: () => context.pop()),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Couldn’t load your business', style: AppType.serif(size: 20)),
                  const SizedBox(height: 8),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: AppType.sans(size: 13, color: AppColors.inkA(0.55))),
                  const SizedBox(height: 16),
                  PrimaryButton(label: 'Retry', small: true, expand: false, onTap: onRetry),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
