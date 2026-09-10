import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_camera_service.dart';
import '../../helpers/pump_app.dart';

/// The OP number the preview is opened for: the label sheet's suggestions are
/// this patient's.
const int _opid = 581;

/// The patient's upload history, stubbed: the preview's suggestions are built
/// from it, so a test can put a narration in front of the sheet with no
/// server behind it.
class _FakeHistory extends TomogramHistoryController {
  _FakeHistory(this.narrations);

  final List<String> narrations;

  @override
  Future<List<TomogramSet>> build(int arg) async => [
        TomogramSet(
          id: 1,
          dateTime: DateTime(2026, 9, 1),
          doctorId: 1,
          tomogramTypeId: 1,
          details: [
            for (var i = 0; i < narrations.length; i++)
              TomogramSetDetail(id: i, tomogramPartId: i, narration: narrations[i]),
          ],
        ),
      ];
}

void main() {
  late Directory dir;
  late FakeCameraService fake;
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('shot_preview');
    fake = FakeCameraService(dir: dir);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// Shoots [count] photos into the session, then pushes the preview at
  /// [index] from a host route — the way the capture screen does.
  Future<void> open(
    WidgetTester tester, {
    int index = 0,
    int count = 3,
    String label = '',
    List<String> narrations = const [],
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ShotPreviewScreen(initialIndex: index, opid: _opid),
              ),
            ),
            child: const Text('host'),
          ),
        ),
      ),
      overrides: [
        cameraServiceProvider.overrideWithValue(fake),
        // The sheet's suggestions are this patient's own narrations plus the
        // device's recent labels; both are stubbed rather than fetched.
        sharedPreferencesProvider.overrideWithValue(prefs),
        tomogramHistoryProvider.overrideWith(() => _FakeHistory(narrations)),
      ],
    );
    container = ProviderScope.containerOf(tester.element(find.text('host')));
    // Nothing on the host route listens to the session, and an autoDispose
    // provider with no listeners is torn down between the shots and the push.
    final keepAlive = container.listen(captureControllerProvider, (_, __) {});
    addTearDown(keepAlive.close);
    final capture = container.read(captureControllerProvider.notifier);
    await capture.start();
    capture.setLabel(label);
    for (var i = 0; i < count; i++) {
      await capture.shoot();
    }
    await tester.pumpAndSettle();
    await tester.tap(find.text('host'));
    await tester.pumpAndSettle();
  }

  List<Shot> shots() => container.read(captureControllerProvider).shots;

  Finder dialogRemove() =>
      find.descendant(of: find.byType(Dialog), matching: find.widgetWithText(DsButton, 'Remove'));

  testWidgets('opens on the shot it was asked for and swipes through the set', (tester) async {
    await open(tester, index: 1);

    expect(find.byType(PageView), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('3 of 3'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('2 of 3'), findsOneWidget);
  });

  testWidgets('the label the shot was taken under is shown under the counter', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, count: 1, label: 'Left forearm');

    expect(find.text('1 of 1'), findsOneWidget);
    expect(find.byKey(shotPreviewLabelKey), findsOneWidget);
    expect(find.text('Left forearm'), findsOneWidget);
    // The photo itself says which one it is, for a reader that never reaches
    // the chip above it.
    expect(find.bySemanticsLabel('1 of 1, Labelled Left forearm'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('an unlabelled shot offers to be labelled', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, count: 1);

    expect(find.text('1 of 1'), findsOneWidget);
    // The line does not disappear when there is no label: it is the offer to
    // add one, which is half of what the preview is for.
    expect(find.byKey(shotPreviewLabelKey), findsOneWidget);
    expect(find.text('Add a label'), findsOneWidget);

    final chip = tester.getSemantics(find.byKey(shotPreviewLabelKey));
    expect(chip.hasFlag(SemanticsFlag.isButton), isTrue);
    expect(chip.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
    // Small as it draws, it is still a thumb-sized target.
    expect(tester.getSize(find.byKey(shotPreviewLabelKey)).height, greaterThanOrEqualTo(44));

    handle.dispose();
  });

  testWidgets('the label chip relabels only the shot on screen', (tester) async {
    await open(tester, index: 1, label: 'Left forearm');
    final paths = shots().map((s) => s.path).toList();

    await tester.tap(find.byKey(shotPreviewLabelKey));
    await tester.pumpAndSettle();

    // Prefilled with what this shot already says, so a correction is a few
    // keystrokes rather than retyping.
    expect(find.text('Label these photos'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'Left forearm');

    await tester.enterText(find.byType(TextField), '  Left forearm, lateral  ');
    await tester.tap(find.widgetWithText(DsButton, 'Use label'));
    await tester.pumpAndSettle();

    expect(shots().map((s) => s.label), ['Left forearm', 'Left forearm, lateral', 'Left forearm']);
    // The files are untouched: only the descriptions moved.
    expect(shots().map((s) => s.path), paths);
    expect(find.text('Left forearm, lateral'), findsOneWidget);
    // The session's own label is what the *next* shot takes, and this was not
    // a change to that.
    expect(container.read(captureControllerProvider).label, 'Left forearm');
  });

  testWidgets('the label chip adds a label to a shot taken without one', (tester) async {
    await open(tester, count: 2);

    await tester.tap(find.byKey(shotPreviewLabelKey));
    await tester.pumpAndSettle();

    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);

    await tester.enterText(find.byType(TextField), 'Scalp');
    await tester.tap(find.widgetWithText(DsButton, 'Use label'));
    await tester.pumpAndSettle();

    expect(shots().map((s) => s.label), ['Scalp', '']);
    expect(find.text('Scalp'), findsOneWidget);
    expect(find.text('Add a label'), findsNothing);
  });

  testWidgets('Clear takes the label off the shot', (tester) async {
    await open(tester, count: 1, label: 'Left forearm');

    await tester.tap(find.byKey(shotPreviewLabelKey));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DsButton, 'Clear label'));
    await tester.pumpAndSettle();

    expect(shots().single.label, isEmpty);
    expect(find.text('Add a label'), findsOneWidget);
  });

  testWidgets('cancelling the sheet leaves the label as it was', (tester) async {
    await open(tester, count: 1, label: 'Left forearm');

    await tester.tap(find.byKey(shotPreviewLabelKey));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Scalp');
    await tester.tap(find.widgetWithText(DsButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(shots().single.label, 'Left forearm');
  });

  testWidgets("the patient's own narrations are offered in the sheet", (tester) async {
    await open(tester, count: 1, narrations: ['Right cheek']);

    await tester.tap(find.byKey(shotPreviewLabelKey));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(DsChip, 'Right cheek'), findsOneWidget);

    await tester.tap(find.widgetWithText(DsChip, 'Right cheek'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DsButton, 'Use label'));
    await tester.pumpAndSettle();

    expect(shots().single.label, 'Right cheek');
  });

  testWidgets('Remove asks first, then drops the shot and deletes its file', (tester) async {
    await open(tester);
    final path = shots().first.path;

    await tester.tap(find.widgetWithText(DsButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(find.text('Remove this photo?'), findsOneWidget);
    expect(find.text('It has not been added yet and will be deleted.'), findsOneWidget);
    // Nothing has gone yet: the dialog is a question, not a receipt.
    expect(shots(), hasLength(3));

    await tester.tap(dialogRemove());
    await tester.pumpAndSettle();

    expect(shots(), hasLength(2));
    expect(File(path).existsSync(), isFalse);
    expect(find.text('1 of 2'), findsOneWidget);
    expect(find.byType(ShotPreviewScreen), findsOneWidget);
  });

  testWidgets('declining the question leaves the shot alone', (tester) async {
    await open(tester);

    await tester.tap(find.widgetWithText(DsButton, 'Remove'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DsButton, 'Cancel'));
    await tester.pumpAndSettle();

    expect(shots(), hasLength(3));
    expect(find.text('1 of 3'), findsOneWidget);
  });

  testWidgets('removing the last of the set steps back onto the one before it', (tester) async {
    await open(tester, index: 2);
    expect(find.text('3 of 3'), findsOneWidget);

    await tester.tap(find.widgetWithText(DsButton, 'Remove'));
    await tester.pumpAndSettle();
    await tester.tap(dialogRemove());
    await tester.pumpAndSettle();

    expect(shots(), hasLength(2));
    expect(find.text('2 of 2'), findsOneWidget);
  });

  testWidgets('removing the only shot leaves the preview', (tester) async {
    await open(tester, count: 1);

    await tester.tap(find.widgetWithText(DsButton, 'Remove'));
    await tester.pumpAndSettle();
    await tester.tap(dialogRemove());
    await tester.pumpAndSettle();

    expect(shots(), isEmpty);
    expect(find.byType(ShotPreviewScreen), findsNothing);
    expect(find.text('host'), findsOneWidget);
  });

  testWidgets('close leaves the set as it was', (tester) async {
    await open(tester);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(ShotPreviewScreen), findsNothing);
    expect(shots(), hasLength(3));
    expect(shots().every((s) => File(s.path).existsSync()), isTrue);
  });
}
