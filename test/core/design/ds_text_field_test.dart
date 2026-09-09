import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('shows label, hint, error and forwards input', (tester) async {
    String? changed;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: DsTextField(label: 'Username', hint: 'jane', errorText: 'Required', onChanged: (v) => changed = v),
      ),
    ));
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('jane'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'abc');
    expect(changed, 'abc');
  });

  testWidgets('mono variant uses tabular figures', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildDsTheme(), home: const Scaffold(body: DsTextField(mono: true))));
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.style?.fontFeatures, contains(const FontFeature.tabularFigures()));
  });
}
