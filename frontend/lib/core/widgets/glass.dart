import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Frosted-glass surface: translucent white, backdrop blur, inset highlight,
/// soft shadow. The recurring container behind pills, cards and the dock.
class GlassSurface extends StatelessWidget {
  const GlassSurface({
    super.key,
    required this.child,
    this.radius = 20,
    this.blur = 18,
    this.opacity = 0.65,
    this.padding,
    this.shadows,
    this.border = true,
  });

  final Widget child;
  final double radius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;
  final bool border;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: shadows ?? AppShadows.glass,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              color: AppColors.whiteA(opacity),
              borderRadius: BorderRadius.circular(radius),
              border: border
                  ? Border.all(color: AppColors.whiteA(0.7), width: 1)
                  : null,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Small square glass button used for bell / filter / back icons.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    this.size = 44,
    this.onTap,
    this.dark = false,
    this.showDot = false,
  });

  final IconData icon;
  final double size;
  final VoidCallback? onTap;
  final bool dark;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            GlassSurface(
              radius: size * 0.36,
              opacity: dark ? 0.35 : 0.65,
              child: Center(
                child: Icon(icon,
                    size: size * 0.42,
                    color: dark ? Colors.white : AppColors.ink),
              ),
            ),
            if (showDot)
              Positioned(
                top: size * 0.24,
                right: size * 0.26,
                child: Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: AppColors.plum,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Warm mesh-gradient background (radial blobs over cream) used on the auth
/// and discovery-stack screens.
class MeshBackground extends StatelessWidget {
  const MeshBackground({
    super.key,
    this.tones = const [AppColors.coral, AppColors.gold, AppColors.plum],
    this.height,
  });

  final List<Color> tones;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        children: [
          Positioned.fill(child: ColoredBox(color: AppColors.cream)),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.8, -1.1),
                  radius: 1.1,
                  colors: [tones[0].withValues(alpha: 0.6), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(1.1, -1.0),
                  radius: 1.0,
                  colors: [tones[1].withValues(alpha: 0.33), Colors.transparent],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.9, 0.2),
                  radius: 1.1,
                  colors: [tones[2].withValues(alpha: 0.13), Colors.transparent],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
