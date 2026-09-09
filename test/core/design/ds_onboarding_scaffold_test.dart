import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

import '../../helpers/pump_app.dart';

void main() {
  BoxDecoration cardShell(WidgetTester tester) => tester
      .widget<Container>(
        find.descendant(of: find.byType(DsOnboardingScaffold), matching: find.byType(Container)).last,
      )
      .decoration! as BoxDecoration;

  double cardOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(
        find.ancestor(of: find.text('card body'), matching: find.byType(FadeTransition)).first,
      )
      .opacity
      .value;

  /// Keeps the ambient MediaQuery (size, padding) and only asks for less motion.
  Widget reducedMotion(Widget child) => Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child,
        ),
      );

  testWidgets('brands the shell and raises a rounded card holding its child', (tester) async {
    await pumpApp(tester, const DsOnboardingScaffold(card: Text('card body')));
    await tester.pumpAndSettle();
    expect(find.text('DeCare HMS'), findsOneWidget);
    expect(find.text('card body'), findsOneWidget);
    expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, DsColors.light.shell);
    final decoration = cardShell(tester);
    expect(decoration.color, DsColors.light.card);
    expect(decoration.borderRadius, const BorderRadius.vertical(top: Radius.circular(DsRadius.onboarding)));
  });

  testWidgets('the card fades in, and is there at once under reduced motion', (tester) async {
    await pumpApp(tester, const DsOnboardingScaffold(card: Text('card body')));
    await tester.pump();
    expect(cardOpacity(tester), lessThan(1));
    expect(find.ancestor(of: find.text('card body'), matching: find.byType(SlideTransition)), findsWidgets);
    await tester.pumpAndSettle();
    expect(cardOpacity(tester), 1);

    await pumpApp(tester, reducedMotion(const DsOnboardingScaffold(card: Text('card body'))));
    await tester.pump();
    expect(cardOpacity(tester), 1);
  });

  testWidgets('the card scrolls when the viewport is short', (tester) async {
    await tester.binding.setSurfaceSize(const Size(440, 320));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester, const DsOnboardingScaffold(card: SizedBox(height: 600, child: Text('card body'))));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final before = tester.getRect(find.text('card body')).top;
    // Drag the viewport, not the tall child: its centre is off screen.
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -100));
    await tester.pump();
    expect(tester.getRect(find.text('card body')).top, lessThan(before));
  });
}
