import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';
import 'package:hms_uploader/core/design/widgets/ds_button.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';

/// Confirmation dialog. Resolves true when confirmed.
Future<bool> showDsDialog(
  BuildContext context, {
  required String title,
  String? body,
  String? confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    useRootNavigator: true,
    builder: (ctx) {
      final ds = ctx.ds;
      final type = ctx.dsType;
      final l10n = ctx.l10n;
      final confirm = confirmLabel ?? l10n.commonConfirm;
      return Dialog(
        backgroundColor: ds.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: DsRadius.largeAll),
        child: Padding(
          padding: const EdgeInsets.all(DsSpace.x5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: type.heading),
              if (body != null) ...[
                const SizedBox(height: DsSpace.x2),
                Text(body, style: type.body.withColor(ds.textSecondary)),
              ],
              const SizedBox(height: DsSpace.x5),
              Row(
                children: [
                  Expanded(child: DsButton.secondary(label: l10n.commonCancel, onPressed: () => Navigator.of(ctx).pop(false))),
                  const SizedBox(width: DsSpace.x3),
                  Expanded(
                    child: destructive
                        ? DsButton.destructive(label: confirm, onPressed: () => Navigator.of(ctx).pop(true))
                        : DsButton.primary(label: confirm, onPressed: () => Navigator.of(ctx).pop(true)),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
