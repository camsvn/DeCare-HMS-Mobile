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
}
