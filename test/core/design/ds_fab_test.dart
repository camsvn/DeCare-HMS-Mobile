import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  Future<void> pumpFab(WidgetTester tester, {VoidCallback? onPressed}) async {
    await tester.pumpWidget(MaterialApp(
      theme: buildDsTheme(),
      home: Scaffold(
        floatingActionButton: DsFab(icon: Icons.add, tooltip: 'Add photo', onPressed: onPressed),
      ),
    ));
  }

  testWidgets('enabled fab fires onPressed and is a labelled button', (tester) async {
    var presses = 0;
    final handle = tester.ensureSemantics();
    await pumpFab(tester, onPressed: () => presses++);
    await tester.tap(find.byType(DsFab));
    expect(presses, 1);
    final node = tester.getSemantics(find.byType(DsFab));
    expect(node.label, contains('Add photo'));
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(node.hasFlag(SemanticsFlag.isEnabled), isTrue);
    expect(find.descendant(of: find.byType(DsFab), matching: find.byType(Opacity)), findsNothing);
    handle.dispose();
  });

  testWidgets('disabled fab renders at 0.5 opacity, no shadow, and reads disabled', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpFab(tester);
    final opacity = tester.widget<Opacity>(find.descendant(
      of: find.byType(DsFab),
      matching: find.byType(Opacity),
    ));
    expect(opacity.opacity, 0.5);
    final container = tester.widget<Container>(find.descendant(
      of: find.byType(DsFab),
      matching: find.byType(Container),
    ));
    expect((container.decoration! as BoxDecoration).boxShadow, isNull);
    final node = tester.getSemantics(find.byType(DsFab));
    expect(node.label, contains('Add photo'));
    expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(node.hasFlag(SemanticsFlag.isEnabled), isFalse);
    handle.dispose();
  });
}
