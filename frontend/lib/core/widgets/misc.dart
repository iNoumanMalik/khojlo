import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import 'glass.dart';

/// Thin hairline divider (`${INK}14`).
class Hairline extends StatelessWidget {
  const Hairline({super.key, this.margin});
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) => Container(
        height: 1,
        margin: margin,
        color: AppColors.ink.withValues(alpha: 0.08),
      );
}

/// Emerald pill toggle switch.
class KhojloToggle extends StatelessWidget {
  const KhojloToggle({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onChanged == null ? null : () => onChanged!(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        decoration: BoxDecoration(
          color: value ? AppColors.emerald : AppColors.ink.withValues(alpha: 0.13),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chat message bubble (glass / ink / plain).
class ChatBubble extends StatelessWidget {
  const ChatBubble({
    super.key,
    required this.text,
    this.isMe = false,
    this.glass = false,
    this.child,
  });

  final String text;
  final bool isMe;
  final bool glass;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final bg = glass
        ? AppColors.whiteA(0.75)
        : isMe
            ? AppColors.ink
            : AppColors.whiteA(0.85);
    final fg = isMe ? Colors.white : AppColors.ink;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72),
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMe ? 18 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.ink.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child ??
            Text(text,
                style: AppType.sans(size: 13.5, height: 1.45, color: fg)),
      ),
    );
  }
}

/// Screen header row with a glass back button + title/subtitle.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 64, 20, 14),
      child: Row(
        children: [
          if (onBack != null) ...[
            GlassIconButton(
                icon: Icons.chevron_left_rounded, size: 38, onTap: onBack),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppType.sans(size: 16.5, weight: FontWeight.w700)),
                if (subtitle != null)
                  Text(subtitle!,
                      style: AppType.sans(
                          size: 11.5, color: AppColors.inkA(0.47))),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Section eyebrow: emerald dot + uppercase mono label.
class SectionEyebrow extends StatelessWidget {
  const SectionEyebrow({
    super.key,
    required this.label,
    this.color = AppColors.emerald,
    this.showDot = true,
  });

  final String label;
  final Color color;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (showDot) ...[
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
        ],
        Text(label.toUpperCase(),
            style: AppType.mono(
                size: 10.5, weight: FontWeight.w600, color: color, letterSpacing: 1.0)),
      ],
    );
  }
}
