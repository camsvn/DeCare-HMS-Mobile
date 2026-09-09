import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  double sweepLeft(WidgetTester tester) => tester
      .widget<Positioned>(find.descendant(of: find.byType(DsProgressBar), matching: find.byType(Positioned)))
      .left!;

  testWidgets('is a 3 dp full-width bar whose gradient sweep advances', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: const Scaffold(body: DsProgressBar()),
    ));
    final size = tester.getSize(find.byType(DsProgressBar));
    expect(size.height, 3);
    expect(size.width, tester.getSize(find.byType(Scaffold)).width);

    final first = sweepLeft(tester);
    await tester.pump(const Duration(milliseconds: 400));
    expect(sweepLeft(tester), greaterThan(first));

    final decoration = tester
        .widget<DecoratedBox>(find.descendant(of: find.byType(DsProgressBar), matching: find.byType(DecoratedBox)))
        .decoration as BoxDecoration;
    expect(decoration.gradient, DsColors.light.accentGradient);

    // A repeating controller keeps a ticker alive; unmount before the test ends.
    await tester.pumpWidget(const SizedBox());
  });
}
