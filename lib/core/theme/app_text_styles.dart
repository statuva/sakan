import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTextStyles {
  static const String primaryFont = 'satoshi';
  static const String secondaryFont = 'GeneralSans';
  static const String technicalFont = 'FiraCode';

  static const TextTheme textTheme = TextTheme(
    displayLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 36,
      height: 44 / 36,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    headlineLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 28,
      height: 36 / 28,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
    ),
    headlineMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 22,
      height: 30 / 22,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    titleLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 18,
      height: 26 / 18,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    bodyLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 16,
      height: 24 / 16,
      fontWeight: FontWeight.w400,
      color: AppColors.textPrimary,
    ),
    bodyMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 14,
      height: 20 / 14,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    ),
    labelLarge: TextStyle(
      fontFamily: primaryFont,
      fontSize: 16,
      height: 22 / 16,
      fontWeight: FontWeight.w500,
      color: AppColors.textPrimary,
    ),
    labelMedium: TextStyle(
      fontFamily: primaryFont,
      fontSize: 12,
      height: 18 / 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textSecondary,
    ),
  );

  static const TextStyle hero = TextStyle(
    fontFamily: secondaryFont,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  static const TextStyle technical = TextStyle(
    fontFamily: technicalFont,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
  );
}
