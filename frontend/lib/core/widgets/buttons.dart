import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../theme/app_typography.dart';

enum ButtonTone { ink, emerald, gold, white }

/// Solid pill button with a soft colored glow — the primary CTA everywhere.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.tone = ButtonTone.ink,
    this.small = false,
    this.expand = true,
    this.loading = false,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final ButtonTone tone;
  final bool small;
  final bool expand;
  final bool loading;
  final IconData? icon;

  Color get _bg => switch (tone) {
        ButtonTone.ink => AppColors.ink,
        ButtonTone.emerald => AppColors.emerald,
        ButtonTone.gold => AppColors.gold,
        ButtonTone.white => Colors.white,
      };

  @override
  Widget build(BuildContext context) {
    final fg = tone == ButtonTone.white ? AppColors.ink : Colors.white;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 120),
        opacity: onTap == null && !loading ? 0.55 : 1,
        child: Container(
          width: expand ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            horizontal: small ? 18 : 22,
            vertical: small ? 11 : 15,
          ),
          decoration: BoxDecoration(
            color: _bg,
            borderRadius: BorderRadius.circular(999),
            boxShadow: AppShadows.glow(_bg),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              else ...[
                if (icon != null) ...[
                  Icon(icon, size: small ? 15 : 17, color: fg),
                  const SizedBox(width: 8),
                ],
                Text(label,
                    style: AppType.sans(
                        size: small ? 13 : 15,
                        weight: FontWeight.w700,
                        color: fg)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent outlined pill — secondary actions (Google/Apple, etc.).
class GhostButton extends StatelessWidget {
  const GhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.small = false,
    this.tone = AppColors.ink,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final bool small;
  final Color tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
            horizontal: 20, vertical: small ? 9 : 14),
        decoration: BoxDecoration(
          color: AppColors.whiteA(0.5),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tone.withValues(alpha: 0.18), width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: small ? 15 : 17, color: tone),
              const SizedBox(width: 8),
            ],
            Text(label,
                style: AppType.sans(
                    size: small ? 12.5 : 14.5,
                    weight: FontWeight.w600,
                    color: tone)),
          ],
        ),
      ),
    );
  }
}
