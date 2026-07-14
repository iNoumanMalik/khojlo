import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Fonts, matching the bundle: Fraunces (headlines), Plus Jakarta Sans (UI/body),
/// IBM Plex Mono (labels, prices, distance, timestamps).
class AppType {
  AppType._();

  static TextStyle serif({
    double size = 24,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.ink,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.fraunces(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.ink,
    double? height,
    double? letterSpacing,
  }) =>
      GoogleFonts.plusJakartaSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
        letterSpacing: letterSpacing,
      );

  static TextStyle mono({
    double size = 11,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.ink,
    double letterSpacing = 0.6,
    double? height,
  }) =>
      GoogleFonts.ibmPlexMono(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  /// Uppercase mono label — the recurring section eyebrow / field label.
  static TextStyle label({Color? color}) => mono(
        size: 10,
        weight: FontWeight.w600,
        color: color ?? AppColors.inkA(0.47),
        letterSpacing: 0.9,
      );
}
