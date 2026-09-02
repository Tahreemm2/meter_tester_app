// =============================================================================
// FILE: lib/core/constants/app_theme.dart
// PURPOSE: Central theme configuration for the Meter Testing App.
//          Government-grade aesthetic: deep greens, off-white, muted slate,
//          soft gold accents. All design tokens live here.
// =============================================================================

import 'package:flutter/material.dart';

// -----------------------------------------------------------------------------
// COLOR PALETTE
// -----------------------------------------------------------------------------
class AppColors {
  AppColors._(); // Prevent instantiation

  // Primary — Deep Corporate Government Green
  static const Color primaryGreen        = Color(0xFF1B4332); // Main brand color
  static const Color primaryGreenLight   = Color(0xFF2D6A4F); // Hover / lighter variant
  static const Color primaryGreenSurface = Color(0xFFD8F3DC); // Tinted green background

  // Background & Surface
  static const Color backgroundPage      = Color(0xFFF4F6F5); // Soft off-white, low eye-strain
  static const Color surfaceCard         = Color(0xFFFFFFFF); // Pure white for cards/inputs
  static const Color surfaceMuted        = Color(0xFFECF0EE); // Dividers, input fills

  // Text & Borders — Muted Slate / Navy
  static const Color textPrimary         = Color(0xFF1C2B2A); // Near-black for headings
  static const Color textSecondary       = Color(0xFF4A5E5B); // Body / labels
  static const Color textHint            = Color(0xFF8FA09D); // Placeholder text
  static const Color borderSubtle        = Color(0xFFCDD8D5); // Input borders, dividers

  // Accent — Soft Gold / Warm Amber (use sparingly: warnings, critical CTAs)
  static const Color accentGold          = Color(0xFFC8973A); // Primary accent
  static const Color accentGoldLight     = Color(0xFFFFF3E0); // Amber-tinted surface

  // Semantic
  static const Color errorRed            = Color(0xFFB00020);
  static const Color successGreen        = Color(0xFF2D6A4F);
  static const Color warningAmber        = Color(0xFFC8973A);
  static const Color white               = Color(0xFFFFFFFF);
}

// -----------------------------------------------------------------------------
// TYPOGRAPHY
// -----------------------------------------------------------------------------
class AppTextStyles {
  AppTextStyles._();

  // Using system sans-serif (Roboto on Android, SF Pro on iOS)
  // For Urdu localization, swap fontFamily to 'NotoNastaliqUrdu' when locale == 'ur'

  static const TextStyle displayLarge = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.2,
  );

  static const TextStyle headingMedium = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
    height: 1.3,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.4,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    color: AppColors.textHint,
    height: 1.4,
  );

  static const TextStyle buttonLabel = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
    letterSpacing: 0.5,
  );

  static const TextStyle linkText = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.primaryGreenLight,
    decoration: TextDecoration.underline,
  );

  static const TextStyle roleTag = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.primaryGreen,
    letterSpacing: 0.3,
  );
}

// -----------------------------------------------------------------------------
// SPACING CONSTANTS
// -----------------------------------------------------------------------------
class AppSpacing {
  AppSpacing._();

  static const double xs   = 4.0;
  static const double sm   = 8.0;
  static const double md   = 16.0;
  static const double lg   = 24.0;
  static const double xl   = 32.0;
  static const double xxl  = 48.0;
}

// -----------------------------------------------------------------------------
// RADII
// -----------------------------------------------------------------------------
class AppRadius {
  AppRadius._();

  static const double input  = 8.0;
  static const double button = 8.0;
  static const double card   = 12.0;
  static const double chip   = 6.0;
}

// -----------------------------------------------------------------------------
// MATERIAL THEME
// -----------------------------------------------------------------------------
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorScheme: const ColorScheme(
      brightness: Brightness.light,
      primary:          AppColors.primaryGreen,
      onPrimary:        AppColors.white,
      primaryContainer: AppColors.primaryGreenSurface,
      onPrimaryContainer: AppColors.primaryGreen,
      secondary:        AppColors.accentGold,
      onSecondary:      AppColors.white,
      secondaryContainer: AppColors.accentGoldLight,
      onSecondaryContainer: AppColors.accentGold,
      surface:          AppColors.surfaceCard,
      onSurface:        AppColors.textPrimary,
      error:            AppColors.errorRed,
      onError:          AppColors.white,
    ),
    scaffoldBackgroundColor: AppColors.backgroundPage,
    fontFamily: 'Roboto',
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceCard,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textHint),
      labelStyle: AppTextStyles.labelLarge,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.borderSubtle, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.input),
        borderSide: const BorderSide(color: AppColors.errorRed, width: 2.0),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: AppColors.white,
        minimumSize: const Size(double.infinity, 52), // Large tap target for field workers
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        elevation: 1,
        textStyle: AppTextStyles.buttonLabel,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryGreenLight,
        textStyle: AppTextStyles.linkText,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primaryGreen,
      foregroundColor: AppColors.white,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.white,
        letterSpacing: 0.2,
      ),
    ),
  );
}
