import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_platform.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/widgets.dart';
import '../push_controller.dart';

/// Offers to turn on push notifications while they're off for this device.
/// Nothing shows when push isn't available (e.g. Firebase not configured).
class PushPromptCard extends ConsumerWidget {
  const PushPromptCard({super.key, this.reason = 'Hear about replies, offers and new places'});
  final String reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(pushControllerProvider);
    if (permission == PushPermission.unsupported || permission == PushPermission.granted) {
      return const SizedBox.shrink();
    }
    final blocked = permission == PushPermission.denied;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          AppColors.gold.withValues(alpha: 0.18),
          AppColors.gold.withValues(alpha: 0.05),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications_active_outlined, color: AppColors.gold),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(blocked ? 'Notifications are blocked' : 'Turn on notifications',
                    style: AppType.sans(size: 13.5, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                    blocked
                        ? 'Allow them for Khojlo in your device or browser settings.'
                        : reason,
                    style: AppType.sans(size: 11.5, color: AppColors.inkA(0.55))),
              ],
            ),
          ),
          if (!blocked) ...[
            const SizedBox(width: 10),
            PrimaryButton(
              label: 'Turn on',
              small: true,
              expand: false,
              onTap: () => ref.read(pushControllerProvider.notifier).enable(),
            ),
          ],
        ],
      ),
    );
  }
}
