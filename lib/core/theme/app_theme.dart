import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';

ThemeData buildAppTheme() {
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.primary,
      secondary: AppColors.orange,
      error: AppColors.error,
      surface: AppColors.background,
    ),
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.background,
      titleTextStyle: AppTextStyles.headerBar,
    ),
    dividerColor: AppColors.divider,
  );
}
