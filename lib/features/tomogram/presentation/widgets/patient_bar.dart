import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';

/// Patient name over the light gradient with the floating "+" button.
class PatientBar extends StatelessWidget {
  const PatientBar({super.key, required this.name, required this.onAdd});

  final String name;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.gradientStart, AppColors.background],
          stops: [0.5, 1],
        ),
      ),
      child: Row(
        children: [
          Expanded(child: Text(name, style: AppTextStyles.header, overflow: TextOverflow.ellipsis)),
          Material(
            color: AppColors.primary,
            shape: const CircleBorder(),
            elevation: 3,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onAdd,
              child: const SizedBox(
                width: 56,
                height: 56,
                child: Icon(Icons.add, color: Colors.white, size: 32),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
