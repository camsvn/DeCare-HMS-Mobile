import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  BoxDecoration decorationOf(WidgetTester tester) => tester
      .widget<Container>(find.descendant(of: find.byType(DsChip), matching: find.byType(Container)))
      .decoration! as BoxDecoration;

  Future<void> pumpChip(WidgetTester tester, DsChip chip, {Brightness brightness = Brightness.light}) =>
      tester.pumpWidget(MaterialApp(
        theme: buildDsTheme(brightness),
        home: Scaffold(body: Align(child: chip)),
      ));

  testWidgets('on a page surface it is a fully rounded outlined pill', (tester) async {
    await pumpChip(tester, const DsChip(text: 'cutis.decare.team'));
    expect(find.text('cutis.decare.team'), findsOneWidget);
    final decoration = decorationOf(tester);
    expect(decoration.color, DsColors.light.canvas);
    expect(decoration.borderRadius, BorderRadius.circular(DsRadius.full));
    expect(decoration.border, isNotNull);
    expect(tester.widget<Text>(find.text('cutis.decare.team')).style?.color, DsColors.light.textSecondary);
  });

  testWidgets('on the shell it fills instead of outlining, from the dark palette', (tester) async {
    await pumpChip(tester, const DsChip(text: '580', onShell: true), brightness: Brightness.dark);
    final decoration = decorationOf(tester);
    expect(decoration.color, DsColors.dark.shellRaised);
    expect(decoration.border, isNull);
    expect(tester.widget<Text>(find.text('580')).style?.color, DsColors.dark.textOnShell);
  });

  testWidgets('the mono variant keeps tabular figures at the label size', (tester) async {
    await pumpChip(tester, const DsChip(text: '580', mono: true));
    final type = DsType.inter(DsColors.light);
    final style = tester.widget<Text>(find.text('580')).style!;
    expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(style.fontSize, type.label.fontSize);
  });

  testWidgets('its padding comes from the space scale', (tester) async {
    await pumpChip(tester, const DsChip(text: '3', mono: true));
    final padding = tester.widget<Container>(
      find.descendant(of: find.byType(DsChip), matching: find.byType(Container)),
    ).padding;
    expect(padding, const EdgeInsets.symmetric(horizontal: DsSpace.x2, vertical: DsSpace.x1));
  });
}
