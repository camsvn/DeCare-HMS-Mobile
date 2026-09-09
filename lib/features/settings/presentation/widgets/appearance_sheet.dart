import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/l10n/generated/app_localizations.dart';
import 'package:hms_uploader/core/widgets/l10n_ext.dart';
import 'package:hms_uploader/features/settings/application/appearance_controller.dart';

/// The label the settings row and the sheet both show for [mode].
String appearanceLabel(AppLocalizations l10n, ThemeMode mode) => switch (mode) {
      ThemeMode.system => l10n.appearanceSystem,
      ThemeMode.light => l10n.appearanceLight,
      ThemeMode.dark => l10n.appearanceDark,
    };

/// The three appearance options, with a tick against the active one. Picking
/// one stores it and closes the sheet.
Future<void> showAppearanceSheet(BuildContext context, WidgetRef ref) {
  final l10n = context.l10n;
  final current = ref.read(appearanceProvider);
  return showDsSheet<void>(
    context,
    builder: (sheet) => [
      Padding(
        padding: const EdgeInsets.fromLTRB(DsSpace.gutter, DsSpace.x3, DsSpace.gutter, DsSpace.x2),
        child: Text(l10n.settingsGroupAppearance, style: context.dsType.heading),
      ),
      for (final mode in ThemeMode.values)
        Semantics(
          selected: mode == current,
          child: DsListRow(
            title: appearanceLabel(l10n, mode),
            // The tick marks the active option; it is not a second action, so
            // it carries a label but no tap handler.
            trailingIcon: mode == current ? Icons.check : null,
            trailingTooltip: mode == current ? l10n.appearanceSelected : null,
            onTap: () => _select(sheet, ref, mode),
          ),
        ),
    ],
  );
}

Future<void> _select(BuildContext sheetContext, WidgetRef ref, ThemeMode mode) async {
  await ref.read(appearanceProvider.notifier).set(mode);
  if (sheetContext.mounted) Navigator.of(sheetContext).pop();
}
