import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static const String primaryFont = 'Satoshi';
  static const String secondaryFont = 'GeneralSans';
  static const String arabicFont = 'Thmanyah';

  static TextStyle _titleStyle({
    required double fontSize,
    required double height,
  }) {
    return GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      height: height,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    );
  }

  static TextTheme get textTheme {
    return TextTheme(
      displayLarge: _titleStyle(fontSize: 36, height: 44 / 36),
      displayMedium: _titleStyle(fontSize: 32, height: 40 / 32),
      displaySmall: _titleStyle(fontSize: 28, height: 36 / 28),
      headlineLarge: _titleStyle(fontSize: 28, height: 36 / 28),
      headlineMedium: _titleStyle(fontSize: 24, height: 31 / 24),
      headlineSmall: _titleStyle(fontSize: 21, height: 28 / 21),
      titleLarge: _titleStyle(fontSize: 19, height: 26 / 19),
      titleMedium: _titleStyle(fontSize: 17, height: 23 / 17),
      titleSmall: const TextStyle(
        fontFamily: primaryFont,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyLarge: const TextStyle(
        fontFamily: primaryFont,
        fontSize: 16,
        height: 24 / 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontFamily: primaryFont,
        fontSize: 14,
        height: 20 / 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      bodySmall: const TextStyle(
        fontFamily: primaryFont,
        fontSize: 12,
        height: 18 / 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      labelLarge: const TextStyle(
        fontFamily: primaryFont,
        fontSize: 16,
        height: 22 / 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      labelMedium: const TextStyle(
        fontFamily: primaryFont,
        fontSize: 12,
        height: 18 / 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
      labelSmall: const TextStyle(
        fontFamily: primaryFont,
        fontSize: 11,
        height: 16 / 11,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );
  }

  static TextStyle get hero {
    return _titleStyle(fontSize: 32, height: 40 / 32);
  }

  static const TextStyle arabic = TextStyle(
    fontFamily: arabicFont,
    fontSize: 14,
    height: 22 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
}
