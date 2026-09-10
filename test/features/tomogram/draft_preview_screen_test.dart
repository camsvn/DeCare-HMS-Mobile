import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/pump_app.dart';

class MockTomogramHistoryApi extends Mock implements TomogramHistoryApi {}

/// The OP number the drafts belong to.
const int _opid = 42;

void main() {
  late Directory dir;
  late SharedPreferences prefs;
  late MockTomogramHistoryApi history;
  late ProviderContainer container;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('draft_preview');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    history = MockTomogramHistoryApi();
    when(() => history.list(any())).thenAnswer((_) async => const []);
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  String jpeg(String name) =>
      (File('${dir.path}/$name')..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9])).path;

  /// Seeds [descriptions] as drafts — one photo each — and pushes the preview
  /// at [index] from a host route, the way a card tap does.
  Future<void> open(
    WidgetTester tester,
    List<String> descriptions, {
    int index = 0,
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var n = 0;
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => DraftPreviewScreen(opid: _opid, initialIndex: index),
              ),
            ),
            child: const Text('host'),
          ),
        ),
      ),
      overrides: [
        tomogramHistoryApiProvider.overrideWithValue(history),
        sharedPreferencesProvider.overrideWithValue(prefs),
        uuidProvider.overrideWithValue(() => 'id${++n}'),
      ],
    );
    container = ProviderScope.containerOf(tester.element(find.text('host')));
    // Nothing on the host listens to the list, and an autoDispose provider
    // with no listeners is torn down between seeding it and the push.
    final keepAlive = container.listen(tomogramControllerProvider(_opid), (_, __) {});
    addTearDown(keepAlive.close);
    container.read(tomogramControllerProvider(_opid).notifier).addDrafts([
      for (var i = 0; i < descriptions.length; i++)
        (path: jpeg('shot$i.jpg'), description: descriptions[i]),
    ]);
    await tester.pumpAndSettle();
    await tester.tap(find.text('host'));
    await tester.pumpAndSettle();
  }

  List<TomogramDraft> drafts() => container.read(tomogramControllerProvider(_opid)).drafts;

  Finder caption() => find.byKey(photoViewerCaptionKey);

  Finder captionText(String text) => find.descendant(of: caption(), matching: find.text(text));

  testWidgets('opens on the draft that was tapped', (tester) async {
    await open(tester, ['Left forearm', '', 'Scalp'], index: 1);

    expect(find.byType(PhotoViewer), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
  });

  testWidgets('captions a described draft, and says what a blank one inherits', (tester) async {
    await open(tester, ['Left forearm', '']);

    expect(captionText('Left forearm'), findsOneWidget);

    await tester.drag(find.byType(PageView), const Offset(-400, 0));
    await tester.pumpAndSettle();

    // A blank description is not nothing here: it uploads with the one before
    // it, and the caption says so rather than offering a label it already has.
    expect(captionText('Same as previous photo: Left forearm'), findsOneWidget);
    expect(captionText('Add a label'), findsNothing);
  });

  testWidgets('the first draft with nothing to inherit is offered a description', (tester) async {
    await open(tester, ['', '']);

    expect(captionText('Add a label'), findsOneWidget);
  });

  testWidgets('editing the caption writes the description onto that draft', (tester) async {
    await open(tester, ['Left forearm', ''], index: 1);

    await tester.tap(caption());
    await tester.pumpAndSettle();

    // Prefilled with the draft's own text — blank here, not the inherited
    // placeholder: typing over an inheritance is a decision, not a correction.
    expect(find.text('Label these photos'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

    await tester.enterText(find.byType(TextField), '  Right cheek  ');
    await tester.tap(find.widgetWithText(DsButton, 'Use label'));
    await tester.pumpAndSettle();

    expect(drafts().map((d) => d.description), ['Left forearm', 'Right cheek']);
    expect(captionText('Right cheek'), findsOneWidget);
  });

  testWidgets('clearing a description hands the draft back to what it inherits', (tester) async {
    await open(tester, ['Left forearm', 'Right cheek'], index: 1);
    expect(captionText('Right cheek'), findsOneWidget);

    await tester.tap(caption());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DsButton, 'Clear label'));
    await tester.pumpAndSettle();

    expect(drafts().map((d) => d.description), ['Left forearm', '']);
    expect(captionText('Same as previous photo: Left forearm'), findsOneWidget);
  });

  testWidgets('cancelling the sheet leaves the description as it was', (tester) async {
    await open(tester, ['Left forearm']);

    await tester.tap(caption());
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Scalp');
    await tester.tap(find.widgetWithText(DsButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(drafts().single.description, 'Left forearm');
  });

  testWidgets('the bin deletes the draft and moves on to the next', (tester) async {
    await open(tester, ['Left forearm', 'Right cheek', 'Scalp'], index: 1);
    final path = drafts()[1].filePath;

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    // No question, as on the card: a draft's delete has never asked.
    expect(drafts().map((d) => d.description), ['Left forearm', 'Scalp']);
    expect(File(path).existsSync(), isFalse);
    expect(find.text('2 of 2'), findsOneWidget);
    expect(captionText('Scalp'), findsOneWidget);
  });

  testWidgets('deleting the only draft leaves the viewer', (tester) async {
    await open(tester, ['Left forearm']);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(drafts(), isEmpty);
    expect(find.byType(PhotoViewer), findsNothing);
    expect(find.text('host'), findsOneWidget);
  });

  testWidgets("the patient's own narrations are offered in the sheet", (tester) async {
    when(() => history.list(_opid)).thenAnswer((_) async => [
          TomogramSet(
            id: 9,
            dateTime: DateTime(2026, 9, 8, 14, 32),
            doctorId: 1,
            tomogramTypeId: 1,
            details: const [TomogramSetDetail(id: 1, tomogramPartId: 1, narration: 'Right cheek')],
          ),
        ]);
    await open(tester, ['']);
    await container.read(tomogramHistoryProvider(_opid).future);
    await tester.pumpAndSettle();

    await tester.tap(caption());
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DsChip, 'Right cheek'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DsButton, 'Use label'));
    await tester.pumpAndSettle();

    expect(drafts().single.description, 'Right cheek');
  });
}
