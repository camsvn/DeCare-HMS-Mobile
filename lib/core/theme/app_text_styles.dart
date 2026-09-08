import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';

abstract final class AppTextStyles {
  static const body = TextStyle(fontSize: 15, color: AppColors.text);
  static const bold = TextStyle(fontSize: 15, color: AppColors.text, fontWeight: FontWeight.bold);
  static const header = TextStyle(fontSize: 24, color: AppColors.text, fontWeight: FontWeight.bold);
  static const fieldLabel = TextStyle(fontSize: 13, color: AppColors.dim);
  static const secondary = TextStyle(fontSize: 9, color: AppColors.dim);
  static const brandLarge = TextStyle(fontSize: 40, color: AppColors.text, fontWeight: FontWeight.w700);
  static const headerBar = TextStyle(fontSize: 28, color: AppColors.background, fontWeight: FontWeight.w700);
  static const onPrimary = TextStyle(fontSize: 15, color: AppColors.background);
}
