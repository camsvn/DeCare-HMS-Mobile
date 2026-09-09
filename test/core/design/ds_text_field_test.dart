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

  testWidgets('shows prefix, suffix and — when asked — the counter, and caps the length', (tester) async {
    final controller = TextEditingController(text: 'ab');
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: DsTextField(
          controller: controller,
          prefix: const Icon(Icons.person_outline),
          suffix: const Icon(Icons.clear),
          maxLength: 6,
          showCounter: true,
        ),
      ),
    ));
    expect(find.byIcon(Icons.person_outline), findsOneWidget);
    expect(find.byIcon(Icons.clear), findsOneWidget);
    expect(find.text('2/6'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'abcdefghij');
    await tester.pump();
    expect(controller.text, 'abcdef');
    expect(find.text('6/6'), findsOneWidget);
  });

  testWidgets('hides the counter unless it is asked for', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: const Scaffold(body: DsTextField(maxLength: 6)),
    ));
    expect(find.text('0/6'), findsNothing);
    expect(tester.widget<TextField>(find.byType(TextField)).decoration?.counterText, '');
  });
}
