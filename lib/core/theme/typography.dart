import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

class AppTypography {
  static TextTheme build() {
    final base = ThemeData.light().textTheme;
    final heading = GoogleFonts.interTextTheme(base);
    final body = GoogleFonts.interTextTheme(base);
    return body.copyWith(
      displayLarge: heading.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.navy,
      ),
      displayMedium: heading.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.navy,
      ),
      headlineLarge: heading.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.navy,
      ),
      headlineMedium: heading.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
      headlineSmall: heading.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
      titleLarge: heading.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        color: AppColors.navy,
      ),
      titleMedium: body.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.navy,
      ),
      titleSmall: body.titleSmall?.copyWith(
        fontWeight: FontWeight.w600,
        color: AppColors.navy2,
      ),
      bodyLarge: body.bodyLarge?.copyWith(color: AppColors.navy2),
      bodyMedium: body.bodyMedium?.copyWith(color: AppColors.navy2),
      bodySmall: body.bodySmall?.copyWith(color: AppColors.muted),
      labelLarge: body.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}
