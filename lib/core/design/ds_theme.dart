import 'package:flutter/material.dart';
import 'package:hms_uploader/core/design/tokens/ds_colors.dart';
import 'package:hms_uploader/core/design/tokens/ds_type.dart';

ThemeData buildDsTheme() {
  const colors = DsColors.light;
  final type = DsType.inter(colors);
  final base = ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: colors.canvas,
    colorScheme: base.colorScheme.copyWith(
      primary: colors.accentSolid,
      onPrimary: colors.textOnShell,
      surface: colors.card,
      onSurface: colors.textPrimary,
      error: colors.danger,
      outline: colors.borderSubtle,
      // The M3 baseline tint is purple; elevated surfaces must stay neutral.
      surfaceTint: Colors.transparent,
    ),
    textTheme: base.textTheme.apply(fontFamily: DsType.family, bodyColor: colors.textPrimary, displayColor: colors.textPrimary),
    // Belt and braces: `showModalBottomSheet` takes no surface tint argument on
    // this SDK, so the sheet and dialog surfaces pin it here as well.
    bottomSheetTheme: base.bottomSheetTheme.copyWith(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
    ),
    dialogTheme: base.dialogTheme.copyWith(
      backgroundColor: colors.card,
      surfaceTintColor: Colors.transparent,
    ),
    dividerColor: colors.borderSubtle,
    splashFactory: InkSparkle.splashFactory,
    extensions: [colors, type],
  );
}

extension DsContext on BuildContext {
  DsColors get ds => Theme.of(this).extension<DsColors>() ?? DsColors.light;
  DsType get dsType => Theme.of(this).extension<DsType>() ?? DsType.inter(ds);
}
