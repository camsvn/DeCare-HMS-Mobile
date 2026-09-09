import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  testWidgets('renders title, mono value, and separate trailing action', (tester) async {
    var taps = 0;
    var trailing = 0;
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: DsListRow(
          leadingIcon: Icons.person_outline,
          title: 'Jane',
          trailingValue: '580',
          trailingIcon: Icons.delete_outline,
          trailingTooltip: 'Remove from recent',
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
    // The row's own content merges onto one node; the trailing action keeps
    // its own labelled node.
    final row = tester.getSemantics(find.text('Jane'));
    expect(row.label, contains('Jane'));
    expect(row.label, contains('580'));
    expect(row.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    final action = tester.getSemantics(find.byIcon(Icons.delete_outline));
    expect(action.tooltip, 'Remove from recent');
    expect(action.hasFlag(SemanticsFlag.isButton), isTrue);
    handle.dispose();
  });

  testWidgets('grows with large text instead of clipping it', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    Future<double> pumpAt(double scale) async {
      await tester.pumpWidget(MaterialApp(
        theme: buildDsTheme(),
        home: Builder(
          // Keep the ambient size and padding; only the text scale changes.
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: const Scaffold(
              body: DsListRow(
                leadingIcon: Icons.person_outline,
                title: 'Jane Doe Roe',
                trailingValue: '580',
              ),
            ),
          ),
        ),
      ));
      expect(tester.takeException(), isNull);
      return tester.getSize(find.byType(DsListRow)).height;
    }

    final base = await pumpAt(1);
    expect(base, DsListRow.height);
    // Rows carry the content, so they follow the reader's text size all the way.
    expect(await pumpAt(2), greaterThan(base));
  });
}
