import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';

/// Root-navigator sheet with a drag handle. Items must pop with the
/// [sheetContext] they receive, never the caller's context.
Future<T?> showDsSheet<T>(
  BuildContext context, {
  required List<Widget> Function(BuildContext sheetContext) builder,
}) {
  final ds = context.ds;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    barrierColor: ds.scrim.withOpacity(0.45),
    backgroundColor: ds.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DsRadius.large))),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: DsSpace.x2, bottom: DsSpace.x1),
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: ds.borderSubtle, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          ...builder(sheetContext),
          const SizedBox(height: DsSpace.x2),
        ],
      ),
    ),
  );
}
