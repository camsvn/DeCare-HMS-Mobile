import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  Future<void> pumpTile(WidgetTester tester, {double? size, Brightness brightness = Brightness.light}) =>
      tester.pumpWidget(MaterialApp(
        theme: buildDsTheme(brightness),
        home: Scaffold(
          body: Align(
            child: size == null ? const DsIconTile(icon: Icons.add) : DsIconTile(icon: Icons.add, size: size),
          ),
        ),
      ));

  testWidgets('is a 40 dp gradient square with a white icon at 55%', (tester) async {
    await pumpTile(tester);
    expect(tester.getSize(find.byType(DsIconTile)), const Size(40, 40));
    final decoration = tester
        .widget<Container>(find.descendant(of: find.byType(DsIconTile), matching: find.byType(Container)))
        .decoration! as BoxDecoration;
    expect(decoration.gradient, DsColors.light.accentGradient);
    expect(decoration.borderRadius, BorderRadius.circular(DsRadius.small));
    final icon = tester.widget<Icon>(find.byIcon(Icons.add));
    expect(icon.size, 40 * 0.55);
    expect(icon.color, DsColors.light.textOnShell);
  });

  testWidgets('scales the icon with the tile', (tester) async {
    await pumpTile(tester, size: 64);
    expect(tester.getSize(find.byType(DsIconTile)), const Size(64, 64));
    expect(tester.widget<Icon>(find.byIcon(Icons.add)).size, 64 * 0.55);
  });

  testWidgets('paints the brand gradient in either palette', (tester) async {
    await pumpTile(tester, brightness: Brightness.dark);
    final decoration = tester
        .widget<Container>(find.descendant(of: find.byType(DsIconTile), matching: find.byType(Container)))
        .decoration! as BoxDecoration;
    expect(decoration.gradient, DsColors.dark.accentGradient);
  });
}
