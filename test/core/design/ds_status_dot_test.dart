import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  Future<Color?> pumpDot(WidgetTester tester, {required bool ok, Color? color}) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(body: Align(child: DsStatusDot(ok: ok, color: color))),
    ));
    final container = tester.widget<Container>(
      find.descendant(of: find.byType(DsStatusDot), matching: find.byType(Container)),
    );
    final decoration = container.decoration! as BoxDecoration;
    expect(decoration.shape, BoxShape.circle);
    expect(tester.getSize(find.byType(DsStatusDot)), const Size(8, 8));
    return decoration.color;
  }

  testWidgets('ok reads success, not ok reads warning', (tester) async {
    expect(await pumpDot(tester, ok: true), DsColors.light.success);
    expect(await pumpDot(tester, ok: false), DsColors.light.warning);
  });

  testWidgets('an explicit colour wins, for indeterminate states', (tester) async {
    expect(await pumpDot(tester, ok: true, color: DsColors.light.textSecondary), DsColors.light.textSecondary);
  });
}
