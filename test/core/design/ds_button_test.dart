import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

  testWidgets('ghost labels are painted in the accent text colour', (tester) async {
    late DsColors ds;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        body: Builder(builder: (context) {
          ds = context.ds;
          return DsButton.ghost(label: 'Link', onPressed: () {});
        }),
      ),
    ));
    expect(tester.widget<Text>(find.text('Link')).style?.color, ds.accentText);
    // Not the solid accent: ghost text sits on a page surface, not on a fill.
    expect(ds.accentText, isNot(ds.accentSolid));
  });

  testWidgets('a null onPressed is non-interactive, dimmed and reads disabled', (tester) async {
    final handle = tester.ensureSemantics();
    var presses = 0;
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: const Scaffold(body: DsButton.primary(label: 'Go', onPressed: null)),
    ));
    await tester.tap(find.text('Go'), warnIfMissed: false);
    expect(presses, 0);
    final opacity = tester.widget<Opacity>(find.descendant(
      of: find.byType(DsButton),
      matching: find.byType(Opacity),
    ));
    expect(opacity.opacity, 0.5);
    final node = tester.getSemantics(find.byType(DsButton));
    expect(node.label, 'Go');
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
    handle.dispose();
  });

  testWidgets('label and button land on one semantics node', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(body: DsButton.primary(label: 'Go', onPressed: () {})),
    ));
    final node = tester.getSemantics(find.byType(DsButton));
    expect(node.label, 'Go');
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    handle.dispose();
  });

  testWidgets('every variant, disabled, is dimmed, silent and reads disabled', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: const Scaffold(
        body: Column(
          children: [
            DsButton.primary(label: 'One', onPressed: null),
            DsButton.secondary(label: 'Two', onPressed: null),
            DsButton.ghost(label: 'Three', onPressed: null),
            DsButton.destructive(label: 'Four', onPressed: null),
          ],
        ),
      ),
    ));
    for (final label in ['One', 'Two', 'Three', 'Four']) {
      final button = find.widgetWithText(DsButton, label);
      // A disabled button does not even take the press scale.
      final gesture = await tester.startGesture(tester.getCenter(button));
      await tester.pump();
      final scale = tester.widget<AnimatedScale>(find.descendant(of: button, matching: find.byType(AnimatedScale)));
      expect(scale.scale, 1, reason: '$label reacted to a press while disabled');
      await gesture.up();
      await tester.pump();
      final opacity = tester.widget<Opacity>(find.descendant(of: button, matching: find.byType(Opacity)));
      expect(opacity.opacity, 0.5, reason: '$label is not dimmed');
      final node = tester.getSemantics(button);
      expect(node.label, label);
      expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
      expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse, reason: '$label does not read disabled');
    }
    handle.dispose();
  });
}
