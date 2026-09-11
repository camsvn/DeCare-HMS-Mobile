import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

import '../../helpers/pump_app.dart';

void main() {
  /// How many times the pill asked for the sheet, and how many times it was
  /// cleared — counted separately, because the whole point of the × is that
  /// it does not go through the sheet.
  late int taps;
  late int clears;

  Future<void> pumpPill(WidgetTester tester, {String label = ''}) async {
    taps = 0;
    clears = 0;
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      Scaffold(
        body: Align(
          alignment: Alignment.centerLeft,
          child: LabelPill(label: label, onTap: () => taps++, onClear: () => clears++),
        ),
      ),
    );
  }

  testWidgets('with no label it says what a label would be for', (tester) async {
    await pumpPill(tester);

    // "Add a label" did not say what the label would apply to, which is why
    // setting one before shooting did not feel like part of taking photos.
    expect(find.text('Label next photos'), findsOneWidget);
    // Nothing to clear yet.
    expect(find.byKey(labelPillClearKey), findsNothing);
  });

  testWidgets('with a label set it says which photos will carry it', (tester) async {
    await pumpPill(tester, label: 'Left forearm');

    expect(find.text('Next photos: Left forearm'), findsOneWidget);
    expect(find.text('Label next photos'), findsNothing);
    final text = tester.widget<Text>(find.text('Next photos: Left forearm'));
    expect(text.maxLines, 1);
    expect(text.overflow, TextOverflow.ellipsis);
  });

  testWidgets('the × clears the label in one tap, without the sheet', (tester) async {
    await pumpPill(tester, label: 'Left forearm');

    expect(find.byTooltip('Clear label'), findsOneWidget);

    await tester.tap(find.byKey(labelPillClearKey));
    await tester.pumpAndSettle();

    expect(clears, 1);
    // Clearing is not "open the sheet and clear it there": one tap, done.
    expect(taps, 0);
  });

  testWidgets('the text still opens the sheet', (tester) async {
    await pumpPill(tester, label: 'Left forearm');

    await tester.tap(find.byKey(labelPillTextKey));
    await tester.pumpAndSettle();

    expect(taps, 1);
    expect(clears, 0);
  });

  testWidgets('both halves are full-size tap targets however small they draw', (tester) async {
    await pumpPill(tester, label: 'Left forearm');

    expect(tester.getSize(find.byKey(labelPillTextKey)).height, greaterThanOrEqualTo(44));
    final clear = tester.getSize(find.byKey(labelPillClearKey));
    expect(clear.height, greaterThanOrEqualTo(44));
    expect(clear.width, greaterThanOrEqualTo(44));
  });

  testWidgets('both halves are buttons a screen reader can press', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPill(tester, label: 'Left forearm');

    final text = tester.getSemantics(find.byKey(labelPillTextKey));
    expect(text.flagsCollection.isButton, isTrue);
    expect(text.label, 'Next photos: Left forearm');
    expect(text.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    final clear = tester.getSemantics(find.byKey(labelPillClearKey));
    expect(clear.flagsCollection.isButton, isTrue);
    expect(clear.label, 'Clear label');
    expect(clear.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    handle.dispose();
  });

  testWidgets('an empty pill reads as the invitation it is', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpPill(tester);

    final text = tester.getSemantics(find.byKey(labelPillTextKey));
    expect(text.label, 'Label next photos');
    expect(text.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    handle.dispose();
  });
}
