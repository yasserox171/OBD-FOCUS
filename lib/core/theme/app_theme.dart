import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/app_colors.dart';

/// Builds the dark (default) and light [ThemeData] for the app.
///
/// Typography: Poppins for Latin text; IBM Plex Sans Arabic is applied
/// automatically for Arabic through the fallback list.
abstract class AppTheme {
  static TextTheme _textTheme(Color primary, Color secondary) {
    final base = GoogleFonts.poppinsTextTheme();
    final arabicFallback =
        GoogleFonts.ibmPlexSansArabic().fontFamily != null
            ? <String>[GoogleFonts.ibmPlexSansArabic().fontFamily!]
            : const <String>[];

    TextStyle style(TextStyle? s, double size, FontWeight weight,
            {Color? color}) =>
        (s ?? const TextStyle()).copyWith(
          fontSize: size,
          fontWeight: weight,
          color: color ?? primary,
          fontFamilyFallback: arabicFallback,
        );

    return base.copyWith(
      displayLarge: style(base.displayLarge, 32, FontWeight.w700),
      displayMedium: style(base.displayMedium, 28, FontWeight.w700),
      headlineMedium: style(base.headlineMedium, 22, FontWeight.w600),
      headlineSmall: style(base.headlineSmall, 20, FontWeight.w600),
      titleLarge: style(base.titleLarge, 18, FontWeight.w600),
      titleMedium: style(base.titleMedium, 16, FontWeight.w500),
      bodyLarge: style(base.bodyLarge, 15, FontWeight.w400),
      bodyMedium: style(base.bodyMedium, 14, FontWeight.w400),
      bodySmall: style(base.bodySmall, 12, FontWeight.w400, color: secondary),
      labelLarge: style(base.labelLarge, 14, FontWeight.w600),
      labelSmall: style(base.labelSmall, 11, FontWeight.w500, color: secondary),
    );
  }

  static ThemeData get dark {
    final textTheme =
        _textTheme(AppColors.textPrimary, AppColors.textSecondary);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentCyan,
        surface: AppColors.surfaceDark,
        error: AppColors.danger,
        onPrimary: Colors.white,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.darkBackground,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceDark,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      dividerColor: Colors.white12,
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.surfaceDarkElevated,
        contentTextStyle: TextStyle(color: AppColors.textPrimary),
        behavior: SnackBarBehavior.floating,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceDark,
        indicatorColor: AppColors.primaryBlue.withOpacity(0.2),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.accentCyan
                : AppColors.textSecondary,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.accentCyan
                : AppColors.textSecondary),
      ),
      progressIndicatorTheme:
          const ProgressIndicatorThemeData(color: AppColors.accentCyan),
    );
  }

  static ThemeData get light {
    final textTheme =
        _textTheme(AppColors.textPrimaryLight, AppColors.textSecondaryLight);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBackground,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primaryBlue,
        secondary: AppColors.accentCyan,
        surface: AppColors.surfaceLight,
        error: AppColors.danger,
      ),
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.lightBackground,
        foregroundColor: AppColors.textPrimaryLight,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: textTheme.headlineSmall,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        indicatorColor: AppColors.primaryBlue.withOpacity(0.15),
        labelTextStyle: WidgetStatePropertyAll(textTheme.labelSmall),
      ),
    );
  }
}
