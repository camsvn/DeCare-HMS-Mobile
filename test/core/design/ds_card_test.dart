import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  Material cardMaterial(WidgetTester tester) => tester.widget<Material>(
        find.descendant(of: find.byType(DsCard), matching: find.byType(Material)).first,
      );

  testWidgets('paints a card surface with a subtle border and no shadow, and taps', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(body: DsCard(onTap: () => taps++, child: const Text('body'))),
    ));
    await tester.tap(find.text('body'));
    expect(taps, 1);
    final material = cardMaterial(tester);
    expect(material.color, DsColors.light.card);
    expect(material.elevation, 0);
    final shape = material.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, DsRadius.mediumAll);
    expect(shape.side.color, DsColors.light.borderSubtle);
  });

  testWidgets('takes its surface from the theme rather than a literal', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(Brightness.dark),
      home: const Scaffold(body: DsCard(child: Text('body'))),
    ));
    expect(cardMaterial(tester).color, DsColors.dark.card);
  });

  testWidgets('pads its child by the card token, or by the padding given', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: const Scaffold(
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DsCard(child: SizedBox(width: 20, height: 20)),
            DsCard(padding: EdgeInsets.zero, child: SizedBox(width: 20, height: 20)),
          ],
        ),
      ),
    ));
    expect(tester.getSize(find.byType(DsCard).first).height, 20 + 2 * DsSpace.cardPadding);
    expect(tester.getSize(find.byType(DsCard).last).height, 20);
  });
}
