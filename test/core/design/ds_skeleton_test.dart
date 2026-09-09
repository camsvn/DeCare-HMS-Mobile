import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('skeleton animates and disposes cleanly', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: buildDsTheme(), home: Scaffold(body: DsSkeleton.row())));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(DsSkeleton), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
