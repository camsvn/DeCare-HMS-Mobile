import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('shows heading, body, illustration and a working action', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: DsEmptyState(
          illustration: const SizedBox(key: ValueKey('art')),
          heading: 'No recent patients',
          body: 'Search an OP number to get started.',
          action: DsButton.primary(label: 'Search', onPressed: () => taps++),
        ),
      ),
    ));
    expect(find.text('No recent patients'), findsOneWidget);
    expect(find.text('Search an OP number to get started.'), findsOneWidget);
    expect(tester.getSize(find.byKey(const ValueKey('art'))).height, 180);
    expect(tester.widget<Text>(find.text('Search an OP number to get started.')).style?.color,
        DsColors.light.textSecondary);
    await tester.tap(find.text('Search'));
    expect(taps, 1);
  });

  testWidgets('drops the illustration and action slots when not given', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: const Scaffold(body: DsEmptyState(heading: 'Nothing here', body: 'Yet.')),
    ));
    expect(find.byType(DsButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolls rather than overflowing a short viewport', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: DsEmptyState(
          illustration: const SizedBox(),
          heading: 'No recent patients',
          body: 'Search an OP number to get started.',
          action: DsButton.primary(label: 'Search', onPressed: () {}),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    final before = tester.getRect(find.text('No recent patients')).top;
    await tester.drag(find.byType(DsEmptyState), const Offset(0, -80));
    await tester.pump();
    expect(tester.getRect(find.text('No recent patients')).top, lessThan(before));
  });
}
