import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/theme/app_spacing.dart';

/// Shows a modal sheet above the tab shell. [builder] receives the sheet's own
/// context; items must pop with that context (`Navigator.of(sheetContext)`),
/// not the caller's, because the sheet lives on the root navigator.
Future<T?> showAppBottomSheet<T>(
  BuildContext context, {
  required List<Widget> Function(BuildContext sheetContext) builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    // Present above the tab shell, not inside the current tab branch.
    useRootNavigator: true,
    barrierColor: AppColors.scrim,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
        child: Column(mainAxisSize: MainAxisSize.min, children: builder(sheetContext)),
      ),
    ),
  );
}
