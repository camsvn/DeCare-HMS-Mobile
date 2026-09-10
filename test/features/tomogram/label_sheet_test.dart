import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

void main() {
  /// What the sheet resolved to, one entry per completed open.
  late List<String?> results;

  /// The device's stored preferences: the sheet reads the recent labels out of
  /// them to know which chips it could stop offering.
  late SharedPreferences prefs;

  /// Opens the sheet from a host button, the way the capture screen does.
  Future<void> open(
    WidgetTester tester, {
    String initial = '',
    List<String> suggestions = const [],
    List<String> recent = const [],
  }) async {
    results = [];
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    if (recent.isNotEmpty) await RecentLabelsRepository(prefs).remember(recent);
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async => results.add(
              await showLabelSheet(context, initial: initial, suggestions: suggestions),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField)).controller!.text;

  testWidgets('opens on the label it was given, ready to type', (tester) async {
    await open(tester, initial: 'Left forearm');

    expect(find.text('Label these photos'), findsOneWidget);
    expect(fieldText(tester), 'Left forearm');
    // The keyboard is already up: the sheet exists to be typed into.
    expect(tester.widget<TextField>(find.byType(TextField)).autofocus, isTrue);
  });

  testWidgets('an empty sheet prompts for a description and offers no Clear', (tester) async {
    await open(tester);

    final field = tester.widget<DsTextField>(find.byType(DsTextField));
    expect(fieldText(tester), isEmpty);
    expect(field.hint, 'e.g. Left forearm');
    expect(field.maxLength, labelMaxLength);
    expect(find.text('Clear label'), findsNothing);
  });

  testWidgets('Use label returns the trimmed text', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), '  Left forearm  ');
    await tester.tap(find.widgetWithText(DsButton, 'Use label'));
    await tester.pumpAndSettle();

    expect(results, ['Left forearm']);
    expect(find.text('Label these photos'), findsNothing);
  });

  testWidgets('submitting the field uses the text', (tester) async {
    await open(tester);

    await tester.enterText(find.byType(TextField), 'Scalp');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(results, ['Scalp']);
  });

  testWidgets('Cancel returns null, so the label is left alone', (tester) async {
    await open(tester, initial: 'Left forearm');

    await tester.enterText(find.byType(TextField), 'Scalp');
    await tester.tap(find.widgetWithText(DsButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(results, [null]);
  });

  testWidgets('dismissing the sheet returns null', (tester) async {
    await open(tester, initial: 'Left forearm');

    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    expect(results, [null]);
    expect(find.text('Label these photos'), findsNothing);
  });

  testWidgets('Clear label is offered for a label already set and returns empty', (tester) async {
    await open(tester, initial: 'Left forearm');

    await tester.tap(find.widgetWithText(DsButton, 'Clear label'));
    await tester.pumpAndSettle();

    expect(results, ['']);
  });

  testWidgets('a suggestion fills the field without closing the sheet', (tester) async {
    await open(tester, suggestions: const ['Left forearm', 'Scalp']);

    expect(find.widgetWithText(DsChip, 'Left forearm'), findsOneWidget);
    await tester.tap(find.widgetWithText(DsChip, 'Scalp'));
    await tester.pumpAndSettle();

    expect(fieldText(tester), 'Scalp');
    expect(results, isEmpty);

    await tester.tap(find.widgetWithText(DsButton, 'Use label'));
    await tester.pumpAndSettle();

    expect(results, ['Scalp']);
  });

  testWidgets('the field stays above the soft keyboard it opens', (tester) async {
    // The sheet is autofocused, so the keyboard is up on its first frame:
    // a field behind the glass would make the whole sheet useless.
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.reset);
    await open(tester, suggestions: const ['Scalp']);

    expect(tester.takeException(), isNull);
    expect(find.byType(TextField), findsOneWidget);
    expect(tester.getRect(find.byType(TextField)).bottom, lessThanOrEqualTo(500));
    // And so does the button that closes it.
    expect(tester.getRect(find.widgetWithText(DsButton, 'Use label')).bottom, lessThanOrEqualTo(500));
  });

  testWidgets('no suggestions, no suggestion row', (tester) async {
    await open(tester);

    expect(find.byType(SuggestionChips), findsNothing);
    expect(find.byType(DsChip), findsNothing);
  });

  testWidgets('the suggestion row is announced as a group', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, suggestions: const ['Scalp']);

    expect(find.bySemanticsLabel('Suggestions'), findsOneWidget);

    handle.dispose();
  });
}
