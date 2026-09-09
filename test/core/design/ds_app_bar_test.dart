import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('spans the width, shows title, actions and back when it can pop', (tester) async {
    var backs = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        appBar: DsAppBar(title: 'Tomogram', onBack: () => backs++, actions: const [Icon(Icons.check)]),
      ),
    ));
    expect(tester.getSize(find.byType(DsAppBar)).width, tester.getSize(find.byType(Scaffold)).width);
    expect(find.text('Tomogram'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    await tester.tap(find.byIcon(Icons.arrow_back));
    expect(backs, 1);
  });

  testWidgets('hides the back arrow on a root route', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: const Scaffold(appBar: DsAppBar(title: 'Home')),
    ));
    expect(find.byIcon(Icons.arrow_back), findsNothing);
  });

  testWidgets('follows the text size up to 1.3, then clamps and keeps its height', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    /// The rendered height of the title at [scale], with the bar's own height.
    Future<({double title, double bar})> pumpAt(double scale) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildDsTheme(),
        home: Builder(
          // Keep the ambient size and padding; only the text scale changes.
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(appBar: DsAppBar(title: 'Tomogram upload')),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      return (
        title: tester.getSize(find.text('Tomogram upload')).height,
        bar: tester.getSize(find.byType(DsAppBar)).height,
      );
    }

    final base = await pumpAt(1);
    final clamped = await pumpAt(1.3);
    expect(clamped.title, greaterThan(base.title));
    // Past the clamp the title stops growing, and the bar never does: shell
    // chrome must not paint over the screen it frames.
    expect((await pumpAt(2)).title, clamped.title);
    expect([base.bar, clamped.bar], everyElement(DsAppBar.barHeight));
  });
}
