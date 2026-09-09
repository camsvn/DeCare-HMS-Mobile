import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('primary fires onPressed and disables while loading', (tester) async {
    var presses = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: Column(children: [
          DsButton.primary(label: 'Go', onPressed: () => presses++),
          DsButton.primary(label: 'Busy', onPressed: () => presses++, loading: true),
        ]),
      ),
    ));
    await tester.tap(find.text('Go'));
    expect(presses, 1);
    expect(find.text('Busy'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.byType(CircularProgressIndicator), warnIfMissed: false);
    expect(presses, 1);
    expect(tester.getSize(find.byType(DsButton).first).height, 44);
  });

  testWidgets('variants render', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: Column(children: [
          DsButton.secondary(label: 'Two', onPressed: () {}),
          DsButton.ghost(label: 'Three', onPressed: () {}),
          DsButton.destructive(label: 'Four', onPressed: () {}),
        ]),
      ),
    ));
    expect(find.text('Two'), findsOneWidget);
    expect(find.text('Three'), findsOneWidget);
    expect(find.text('Four'), findsOneWidget);
  });
}
