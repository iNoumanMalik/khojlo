import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../ui/messenger.dart';
import '../widgets/widgets.dart';

/// Explains what Khojlo does with the location before the system permission prompt.
/// Resolves true to go on and ask, false if the user chose "Not now".
Future<bool> explainLocationUse() async {
  final context = rootNavigatorKey.currentContext;
  if (context == null) return true;
  final go = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    backgroundColor: AppColors.cream,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: AppColors.inkA(0.15), borderRadius: BorderRadius.circular(99)),
            ),
          ),
          const Icon(Icons.near_me_outlined, color: AppColors.emerald, size: 28),
          const SizedBox(height: 10),
          Text('Use your location?', style: AppType.serif(size: 22)),
          const SizedBox(height: 6),
          Text(
            'Khojlo uses it to show places near you and how far away they are. It’s only '
            'sent while you search or use the map, and never saved to your account.',
            style: AppType.sans(size: 13, height: 1.5, color: AppColors.inkA(0.6)),
          ),
          const SizedBox(height: 6),
          Text('Your device will ask next. You can change this any time in settings.',
              style: AppType.sans(size: 12, color: AppColors.inkA(0.45))),
          const SizedBox(height: 20),
          PrimaryButton(
            label: 'Continue',
            tone: ButtonTone.emerald,
            onTap: () => Navigator.of(ctx).pop(true),
          ),
          const SizedBox(height: 10),
          GhostButton(label: 'Not now', onTap: () => Navigator.of(ctx).pop(false)),
        ],
      ),
    ),
  );
  return go ?? false;
}
