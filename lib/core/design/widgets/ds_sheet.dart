import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/ds_theme.dart';
import 'package:hms_uploader/core/design/tokens/ds_radius.dart';
import 'package:hms_uploader/core/design/tokens/ds_space.dart';

/// How tall a sheet may grow. The same 9/16 of the screen the framework's own
/// unscrolled modal sheet allowed, kept as an explicit cap now that the sheet
/// asks for the whole viewport in order to sit above the keyboard.
const double dsSheetMaxHeightFactor = 9 / 16;

/// Root-navigator sheet with a drag handle. Items must pop with the
/// [sheetContext] they receive, never the caller's context.
///
/// Keyboard-safe: the sheet is scroll-controlled, so it may ask for the whole
/// viewport, and its content is lifted clear of the soft keyboard rather than
/// left behind it — a sheet with a field in it is a normal sheet. The content
/// is still capped at [dsSheetMaxHeightFactor] of the screen, and scrolls
/// inside that cap, so a tall sheet on a short screen (or one with the
/// keyboard up) loses nothing off the bottom.
Future<T?> showDsSheet<T>(
  BuildContext context, {
  required List<Widget> Function(BuildContext sheetContext) builder,
}) {
  final ds = context.ds;
  return showModalBottomSheet<T>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    barrierColor: ds.scrim.withOpacity(0.45),
    backgroundColor: ds.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(DsRadius.large))),
    builder: (sheetContext) => Padding(
      // What the keyboard covers, given back: the sheet stands on top of it.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * dsSheetMaxHeightFactor,
          ),
          child: SingleChildScrollView(
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
        ),
      ),
    ),
  );
}
