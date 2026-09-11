import 'dart:ui' show Tristate;

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
    expect(action.flagsCollection.isButton, isTrue);
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

  testWidgets('taps near the top and bottom edges of a title-only row fire onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(body: DsListRow(title: 'System', onTap: () => taps++)),
    ));
    final row = find.byType(DsListRow);
    // A title-only row is ~20 dp of content in a 56 dp box; the ink has to
    // cover the box, or the top and bottom thirds of the row swallow taps.
    await tester.tapAt(tester.getTopLeft(row) + const Offset(40, 4));
    await tester.tapAt(tester.getBottomLeft(row) + const Offset(40, -4));
    expect(taps, 2);
    expect(tester.getSize(find.byType(InkWell)).height, tester.getSize(row).height);
  });

  testWidgets("a trailing widget takes the trailing icon action's place", (tester) async {
    var trailing = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: DsListRow(
          title: 'Jane',
          trailingIcon: Icons.delete_outline,
          onTrailingTap: () => trailing++,
          trailing: const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsNothing);
    expect(trailing, 0);
    expect(tester.getSize(find.byType(DsListRow)).height, DsListRow.height);
  });

  testWidgets('announces the selected row as selected', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: Column(children: [
          DsListRow(title: 'Dark', selected: true, onTap: () {}),
          DsListRow(title: 'Light', onTap: () {}),
        ]),
      ),
    ));
    expect(tester.getSemantics(find.text('Dark')).flagsCollection.isSelected, Tristate.isTrue);
    expect(tester.getSemantics(find.text('Light')).flagsCollection.isSelected, isNot(Tristate.isTrue));
    handle.dispose();
  });
}
