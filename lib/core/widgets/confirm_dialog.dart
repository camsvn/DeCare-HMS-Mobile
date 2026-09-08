import 'package:flutter/material.dart';
import 'package:hms_uploader/core/theme/app_colors.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// "Are you sure?" with No / Yes. Resolves true when confirmed.
Future<bool> showConfirmDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(ctx.l10n.commonConfirmTitle),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(ctx.l10n.commonConfirmNo, style: const TextStyle(color: AppColors.dim)),
        ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(ctx.l10n.commonConfirmYes, style: const TextStyle(color: AppColors.errorRed)),
        ),
      ],
    ),
  );
  return result ?? false;
}
