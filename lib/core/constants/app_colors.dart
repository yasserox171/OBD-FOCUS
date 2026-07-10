import 'package:flutter/material.dart';

/// Central color palette for the Focus OBD2 Scanner design system.
///
/// The app is dark-first: [darkBackground] / [surfaceDark] are the primary
/// canvas, with [primaryBlue] and [accentCyan] as brand colors and the
/// semantic colors used consistently for gauge zones, alerts and charts.
abstract class AppColors {
  // Brand
  static const Color primaryBlue = Color(0xFF1E90FF);
  static const Color accentCyan = Color(0xFF00D4FF);

  // Dark theme surfaces
  static const Color darkBackground = Color(0xFF0F1419);
  static const Color surfaceDark = Color(0xFF1A1F28);
  static const Color surfaceDarkElevated = Color(0xFF232A36);

  // Light theme surfaces
  static const Color lightBackground = Color(0xFFF5F7FA);
  static const Color surfaceLight = Color(0xFFFFFFFF);

  // Semantic
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color danger = Color(0xFFEF4444);

  // Text (dark theme)
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB0B8C1);

  // Text (light theme)
  static const Color textPrimaryLight = Color(0xFF10151C);
  static const Color textSecondaryLight = Color(0xFF5B6470);

  /// Gauge / value color by ratio of the danger threshold (0..1+).
  static Color byLevel(double ratio) {
    if (ratio >= 1.0) return danger;
    if (ratio >= 0.8) return warning;
    return success;
  }

  /// Gradient used on headers and highlighted cards.
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryBlue, accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
