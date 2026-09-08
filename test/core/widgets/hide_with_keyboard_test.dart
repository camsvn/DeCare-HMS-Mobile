import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/widgets/keyboard_visibility.dart';

void main() {
  testWidgets('hides the child while the keyboard is up, inside a Scaffold body', (tester) async {
    // A Scaffold strips the bottom view inset from its body's MediaQuery, so
    // this only works if visibility is read from the FlutterView directly.
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: HideWithKeyboard(child: Text('x')))),
    );
    expect(find.text('x'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.text('x'), findsNothing);

    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    expect(find.text('x'), findsOneWidget);
  });
}
