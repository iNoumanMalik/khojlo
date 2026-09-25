import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/cupertino.dart';

import 'app_colors.dart';

/// Global Material theme tuned to the Khojlo design language (light, warm, glassy).
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.emerald,
        primary: AppColors.emerald,
        secondary: AppColors.gold,
        surface: AppColors.cream,
        brightness: Brightness.light,
      ),
      splashFactory: InkRipple.splashFactory,
    );

    return base.copyWith(
      textTheme: GoogleFonts.plusJakartaSansTextTheme(base.textTheme)
          .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}

/// Shared elevation / radius tokens seen across the design.
class AppShadows {
  AppShadows._();

  /// Soft frosted-glass shadow (`0 10px 28px rgba(43,38,32,0.14)`).
  static List<BoxShadow> glass = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.14),
      blurRadius: 28,
      offset: const Offset(0, 10),
    ),
  ];

  /// Floating dock / elevated card (`0 12px 32px rgba(43,38,32,0.16)`).
  static List<BoxShadow> floating = [
    BoxShadow(
      color: AppColors.ink.withValues(alpha: 0.16),
      blurRadius: 32,
      offset: const Offset(0, 12),
    ),
  ];

  /// Colored button glow (`0 12px 24px <color>40`).
  static List<BoxShadow> glow(Color color) => [
        BoxShadow(
          color: color.withValues(alpha: 0.25),
          blurRadius: 24,
          offset: const Offset(0, 12),
        ),
      ];
}
