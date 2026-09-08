import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_text_styles.dart';

/// Dark header bar with a centred title and optional icon buttons.
class AppHeader extends StatelessWidget {
  const AppHeader({
    super.key,
    required this.title,
    this.leftIcon,
    this.onLeftTap,
    this.rightIcon,
    this.onRightTap,
    this.rightIconColor,
  });

  final String title;
  final IconData? leftIcon;
  final VoidCallback? onLeftTap;
  final IconData? rightIcon;
  final VoidCallback? onRightTap;
  final Color? rightIconColor;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Container(
      padding: EdgeInsets.only(top: top),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(5)),
      ),
      child: SizedBox(
        height: 56,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(title, style: AppTextStyles.headerBar),
            if (leftIcon != null)
              Positioned(
                left: 4,
                child: IconButton(
                  icon: Icon(leftIcon, color: Colors.white),
                  onPressed: onLeftTap,
                ),
              ),
            if (rightIcon != null)
              Positioned(
                right: 4,
                child: IconButton(
                  icon: Icon(rightIcon, color: rightIconColor ?? AppColors.goGreen),
                  onPressed: onRightTap,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
