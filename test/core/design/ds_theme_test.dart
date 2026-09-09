import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('theme exposes tokens through context extensions', (tester) async {
    late DsColors ds;
    late DsType type;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Builder(builder: (context) {
        ds = context.ds;
        type = context.dsType;
        return const SizedBox();
      }),
    ));
    expect(ds.shell, const Color(0xFF151D28));
    expect(ds.canvas, const Color(0xFFF4F6FA));
    expect(ds.accentGradient.colors, hasLength(3));
    expect(type.body.fontFamily, 'Inter');
    expect(type.body.fontSize, 14);
    expect(type.title.fontWeight, FontWeight.w600);
    expect(type.mono.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(type.body.color, ds.textPrimary);
  });

  testWidgets('the dark theme exposes the dark palette', (tester) async {
    late DsColors ds;
    late DsType type;
    late ThemeData theme;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(Brightness.dark),
      home: Builder(builder: (context) {
        ds = context.ds;
        type = context.dsType;
        theme = Theme.of(context);
        return const SizedBox();
      }),
    ));
    expect(theme.brightness, Brightness.dark);
    expect(ds.canvas, const Color(0xFF0F141C));
    expect(ds.card, const Color(0xFF171E29));
    expect(ds.shell, const Color(0xFF0B1017));
    expect(ds.shellRaised, const Color(0xFF1E2938));
    expect(ds.textPrimary, const Color(0xFFE8ECF2));
    expect(ds.textSecondary, const Color(0xFF9AA4B2));
    expect(ds.textOnShell, const Color(0xFFFFFFFF));
    expect(ds.textOnShellMuted, const Color(0xB3FFFFFF));
    expect(ds.borderSubtle, const Color(0xFF273040));
    expect(ds.accentSolid, const Color(0xFF5AA8F0));
    expect(ds.accentText, const Color(0xFF7DBCF5));
    expect(ds.success, const Color(0xFF3DBA85));
    expect(ds.warning, const Color(0xFFF0B429));
    expect(ds.danger, const Color(0xFFF26B70));
    // The gradient is the brand mark; it does not change per brightness.
    expect(ds.accentGradient.colors, DsColors.light.accentGradient.colors);
    // Surfaces and text follow the dark palette, not the M3 baseline.
    expect(theme.scaffoldBackgroundColor, ds.canvas);
    expect(theme.colorScheme.surface, ds.card);
    expect(theme.colorScheme.surfaceTint, Colors.transparent);
    expect(theme.bottomSheetTheme.backgroundColor, ds.card);
    expect(theme.dialogTheme.backgroundColor, ds.card);
    expect(theme.textTheme.bodyMedium?.color, ds.textPrimary);
    expect(type.body.color, ds.textPrimary);
  });

  test('buildDsTheme defaults to the light palette', () {
    expect(buildDsTheme().brightness, Brightness.light);
    expect(buildDsTheme(Brightness.light).extension<DsColors>()?.canvas, DsColors.light.canvas);
    expect(DsColors.light.accentText, const Color(0xFF1F6FBF));
  });

  test('DsMotion.of collapses to fast when animations are disabled', () {
    expect(DsMotion.resolve(const Duration(milliseconds: 320), disableAnimations: true), DsMotion.fast);
    expect(DsMotion.resolve(const Duration(milliseconds: 320), disableAnimations: false),
        const Duration(milliseconds: 320));
  });
}
