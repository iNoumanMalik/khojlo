import 'package:flutter/material.dart';

/// Khojlo palette — extracted verbatim from the design bundle (`Khojlo App.dc.html`).
class AppColors {
  AppColors._();

  static const ink = Color(0xFF2B2620);
  static const cream = Color(0xFFFBF6EE);
  static const gold = Color(0xFFE3A73D);
  static const emerald = Color(0xFF1D6D5A);
  static const plum = Color(0xFF7A3350);
  static const coral = Color(0xFFF2C9C1);

  /// Reference-board / app page background.
  static const pageBg = Color(0xFFF0EBE0);

  /// Ink with alpha — the design uses `${INK}77` etc. throughout.
  static Color inkA(double opacity) => ink.withValues(alpha: opacity);
  static Color whiteA(double opacity) => Colors.white.withValues(alpha: opacity);

  /// Tone gradients used by image placeholders / avatars.
  static const Map<String, List<Color>> toneGradients = {
    'gold': [gold, Color(0xFFC97F2A)],
    'plum': [plum, Color(0xFF4E2137)],
    'emerald': [emerald, Color(0xFF123F34)],
    'coral': [coral, Color(0xFFD98F80)],
    'ink': [Color(0xFF4A4238), ink],
  };

  static List<Color> gradientFor(String tone) =>
      toneGradients[tone] ?? toneGradients['gold']!;

  static Color solidFor(String tone) => gradientFor(tone).first;
}
