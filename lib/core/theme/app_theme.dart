import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// All colors, spacing, and radius values below come directly from the
/// CERTIFIED Design System page (Coasterna_UI_Design_v8.7.pdf, page 3).
/// If any value ever changes, it must change here AND in the report
/// (Ch.5.2) together — never in just one place.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF0F2B43); // Navy
  static const Color accent = Color(0xFFAF9064); // Gold
  static const Color success = Color(0xFF3B6D11);
  static const Color warning = Color(0xFFA66300);
  static const Color error = Color(0xFFA32D2D);

  static const Color textPrimary = Color(0xFF1A1A18);
  static const Color textSecondary = Color(0xFF5C5C55);
  static const Color textTertiary = Color(0xFF6E6E67);

  static const Color background = Color(0xFFF7F4EE);
  static const Color surface = Color(0xFFFFFFFF);
  // Not an explicit spec token — derived tint used for card/divider borders.
  static const Color surfaceBorder = Color(0xFFE4E0D6);
}

/// Spacing scale — only these five values are allowed anywhere in the
/// app for padding, margin, or gaps between widgets.
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
}

/// Corner radius scale — matches the frozen Design System exactly.
class AppRadius {
  AppRadius._();

  static const double card = 12;
  static const double button = 8;
  static const double chip = 4;
}

/// Minimum tappable height/width for any button or interactive row.
const double kMinTouchTarget = 48;

/// Text style for prices, clock times, and durations ONLY.
/// Everything else uses the theme's default font (Roboto).
class AppTextStyles {
  AppTextStyles._();

  static TextStyle monoData({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w500,
    Color color = AppColors.textPrimary,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}

/// The single Flutter ThemeData for the whole app. Built once here,
/// applied once in main.dart via MaterialApp(theme: appTheme).
final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    error: AppColors.error,
    surface: AppColors.surface,
  ),
  scaffoldBackgroundColor: AppColors.background,
  textTheme: Typography.material2021().black.apply(
    bodyColor: AppColors.textPrimary,
    displayColor: AppColors.textPrimary,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(kMinTouchTarget),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
    ),
  ),
  cardTheme: CardThemeData(
    color: AppColors.surface,
    elevation: 1,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.card),
      side: const BorderSide(color: AppColors.surfaceBorder, width: 1),
    ),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.button),
    ),
  ),
);