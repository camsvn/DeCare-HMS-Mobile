import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';

void main() {
  Widget app(List<Page<void>> pages, {bool reduceMotion = false}) => MaterialApp(
        theme: buildDsTheme(),
        home: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
            child: Navigator(
              pages: pages,
              onDidRemovePage: (page) {},
            ),
          ),
        ),
      );

  /// The `Navigator(pages:)` the test builds — `.last` because the
  /// MaterialApp's own root Navigator comes first in tree order. Transitions
  /// found below it belong to FadeThroughPage; anything above belongs to the
  /// MaterialApp's home route (FadeForwards slides since Flutter 3.27) and is
  /// not under test.
  Finder pageSlides() => find.descendant(of: find.byType(Navigator).last, matching: find.byType(SlideTransition));

  const pageA = FadeThroughPage<void>(key: ValueKey('a'), child: Text('A'));
  const pageB = FadeThroughPage<void>(key: ValueKey('b'), child: Text('B'));

  double incomingOpacity(WidgetTester tester) => tester
      .widget<FadeTransition>(find.ancestor(of: find.text('B'), matching: find.byType(FadeTransition)).first)
      .opacity
      .value;

  testWidgets('the incoming page fades in and rises, then settles', (tester) async {
    await tester.pumpWidget(app(const [pageA]));
    expect(find.text('A'), findsOneWidget);

    await tester.pumpWidget(app(const [pageA, pageB]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final opacity = incomingOpacity(tester);
    expect(opacity, greaterThan(0));
    expect(opacity, lessThan(1));
    // Both FadeThroughPage routes (A settling out, B rising in) slide.
    expect(pageSlides(), findsWidgets);

    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
    expect(incomingOpacity(tester), 1);
  });

  testWidgets('under reduced motion it is a plain fade, and a short one', (tester) async {
    await tester.pumpWidget(app(const [pageA], reduceMotion: true));
    await tester.pumpWidget(app(const [pageA, pageB], reduceMotion: true));
    await tester.pump();
    expect(pageSlides(), findsNothing);
    final route = ModalRoute.of(tester.element(find.text('B')))! as PageRoute<void>;
    expect(route.transitionDuration, DsMotion.fast);
    await tester.pumpAndSettle();
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets('a page update on the same key swaps the content in place', (tester) async {
    await tester.pumpWidget(app(const [pageA]));
    await tester.pumpAndSettle();
    await tester.pumpWidget(app(const [FadeThroughPage<void>(key: ValueKey('a'), child: Text('A2'))]));
    await tester.pumpAndSettle();
    expect(find.text('A2'), findsOneWidget);
    expect(find.text('A'), findsNothing);
  });
}
