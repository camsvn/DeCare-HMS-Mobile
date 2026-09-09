import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';

Future<T?> showAppBottomSheet<T>(BuildContext context, {required List<Widget> children}) {
  return showModalBottomSheet<T>(
    context: context,
    // Present above the tab shell, not inside the current tab branch.
    useRootNavigator: true,
    barrierColor: AppColors.scrim,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    ),
  );
}
