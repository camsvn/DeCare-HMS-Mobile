import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('renders title, mono value, and separate trailing action', (tester) async {
    var taps = 0;
    var trailing = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: DsListRow(
          leadingIcon: Icons.person_outline,
          title: 'Jane',
          trailingValue: '580',
          trailingIcon: Icons.delete_outline,
          onTrailingTap: () => trailing++,
          onTap: () => taps++,
        ),
      ),
    ));
    expect(find.text('Jane'), findsOneWidget);
    expect(find.text('580'), findsOneWidget);
    await tester.tap(find.text('Jane'));
    await tester.tap(find.byIcon(Icons.delete_outline));
    expect(taps, 1);
    expect(trailing, 1);
    expect(tester.getSize(find.byType(DsListRow)).height, 56);
  });
}
