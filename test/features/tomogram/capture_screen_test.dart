import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

import '../../helpers/fake_camera_service.dart';
import '../../helpers/pump_app.dart';

/// The OP number the screen is opened for: the label sheet's suggestions are
/// this patient's.
const int _opid = 581;

void main() {
  late Directory dir;
  late FakeCameraService fake;

  /// What the pushed screen popped with, one entry per completed push.
  late List<List<Shot>?> results;

  /// What `descriptionSuggestionsProvider` offers for [_opid]. Set before
  /// [open], which is where the override is installed.
  late List<String> suggestions;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('capture_screen');
    fake = FakeCameraService(dir: dir);
    results = [];
    suggestions = [];
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// Pushes [CaptureScreen] from a host button so that its pop result can be
  /// read, the way the tomogram screen will read it.
  Future<void> open(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () async => results.add(
              await Navigator.of(context).push<List<Shot>>(
                MaterialPageRoute(builder: (_) => const CaptureScreen(opid: _opid)),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [
        cameraServiceProvider.overrideWithValue(fake),
        // The real one reaches for the patient's upload history over the
        // network; what the sheet does with the list is what is under test.
        descriptionSuggestionsProvider(_opid).overrideWithValue(suggestions),
      ],
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  Future<void> shoot(WidgetTester tester, {int times = 1}) async {
    for (var i = 0; i < times; i++) {
      await tester.tap(find.byType(ShutterButton));
      await tester.pumpAndSettle();
    }
  }

  CaptureState stateOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(CaptureScreen))).read(captureControllerProvider);

  List<Shot> shotsOf(WidgetTester tester) => stateOf(tester).shots;

  Finder thumbnails() => find.descendant(of: find.byType(ShotStrip), matching: find.byType(Image));

  /// Opens the label sheet from the pill and types [type] into it, without
  /// committing: each test finishes the sheet its own way.
  Future<void> openLabelSheet(WidgetTester tester, {String? type}) async {
    await tester.tap(find.byType(LabelPill));
    await tester.pumpAndSettle();
    if (type != null) await tester.enterText(find.byType(TextField), type);
  }

  Future<void> setLabel(WidgetTester tester, String label) async {
    await openLabelSheet(tester, type: label);
    await tester.tap(find.widgetWithText(DsButton, 'Use label'));
    await tester.pumpAndSettle();
  }

  List<String> filesOnDisk() => dir.listSync().whereType<File>().map((f) => f.path).toList()..sort();

  /// Drives the app lifecycle the way the engine does, over
  /// `SystemChannels.lifecycle`: the binding's own entry point is
  /// `@protected`, and the channel also synthesises the intermediate states a
  /// real pause goes through (resumed → inactive → hidden → paused).
  Future<void> lifecycle(WidgetTester tester, AppLifecycleState state) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.lifecycle.name,
      const StringCodec().encodeMessage('$state'),
      (_) {},
    );
    await tester.pumpAndSettle();
  }

  testWidgets('the shutter takes one photo and shows it in the strip', (tester) async {
    await open(tester);
    expect(find.byKey(const Key('fake-preview')), findsOneWidget);
    expect(find.text('No photos yet'), findsOneWidget);
    expect(thumbnails(), findsNothing);

    await shoot(tester);

    expect(thumbnails(), findsOneWidget);
    expect(find.text('1 photo'), findsOneWidget);
    expect(filesOnDisk(), hasLength(1));
  });

  testWidgets('Done is disabled until there is a shot, then pops with the paths in order', (tester) async {
    await open(tester);
    expect(tester.widget<DsButton>(find.widgetWithText(DsButton, 'Done')).onPressed, isNull);

    await shoot(tester, times: 2);
    expect(tester.widget<DsButton>(find.widgetWithText(DsButton, 'Done')).onPressed, isNotNull);
    final shots = shotsOf(tester);

    await tester.tap(find.widgetWithText(DsButton, 'Done'));
    await tester.pumpAndSettle();

    expect(results, hasLength(1));
    expect(results.single, shots);
    expect(results.single!.first.path, endsWith('shot_0.jpg'));
    expect(results.single!.last.path, endsWith('shot_1.jpg'));
    // Handed over, not discarded: the draft list owns the files now.
    expect(filesOnDisk(), hasLength(2));
  });

  testWidgets('Done waits for the shots to finish post-processing before popping', (tester) async {
    // The camera rewrites each shot's orientation in the background. Handing
    // the paths over mid-rewrite would upload a half-written JPEG, so Done
    // waits — visibly, and with the shutter shut, because the pop is coming.
    await open(tester);
    await shoot(tester);
    final shots = shotsOf(tester);
    fake.flushGate = Completer<void>();

    await tester.tap(find.widgetWithText(DsButton, 'Done'));
    await tester.pump();

    expect(fake.flushCount, 1);
    expect(tester.widget<DsButton>(find.byType(DsButton)).loading, isTrue);
    // The spinner takes the label's place, so there is nothing left to tap.
    expect(find.widgetWithText(DsButton, 'Done'), findsNothing);
    expect(tester.widget<ShutterButton>(find.byType(ShutterButton)).onPressed, isNull);
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(results, isEmpty);

    fake.flushGate!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CaptureScreen), findsNothing);
    expect(results, [shots]);
    expect(filesOnDisk(), hasLength(1));
  });

  testWidgets('nothing else on the screen works while Done hands the shots over', (tester) async {
    // Every one of these used to open a dialog on the root navigator, and the
    // pop that ended the flush would then hand a `List<String>` to a
    // `Route<bool>`: a TypeError, a screen still up with its shots already
    // cleared, and the photos orphaned. The screen is frozen instead.
    await open(tester);
    await shoot(tester);
    final shots = shotsOf(tester);
    fake.flushGate = Completer<void>();

    await tester.tap(find.widgetWithText(DsButton, 'Done'));
    await tester.pump();

    expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close)).onPressed, isNull);
    expect(
      tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.flashlight_off_outlined)).onPressed,
      isNull,
    );

    // Done's spinner never stops, so `pumpAndSettle` cannot be used while it is
    // up: each interaction is instead given long enough for a dialog route to
    // have arrived if it were coming.
    Future<void> pumpDialogIn() => tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byTooltip('Close'), warnIfMissed: false);
    await pumpDialogIn();
    expect(find.text('Discard photos?'), findsNothing);

    await tester.binding.handlePopRoute();
    await pumpDialogIn();
    expect(find.text('Discard photos?'), findsNothing);

    await tester.tap(thumbnails());
    await pumpDialogIn();
    expect(find.byType(ShotPreviewScreen), findsNothing);

    await tester.tap(find.byType(LabelPill));
    await pumpDialogIn();
    expect(find.text('Label these photos'), findsNothing);

    expect(find.byType(CaptureScreen), findsOneWidget);

    fake.flushGate!.complete();
    await tester.pumpAndSettle();

    expect(find.byType(CaptureScreen), findsNothing);
    expect(results, [shots]);
    expect(shots.every((s) => File(s.path).existsSync()), isTrue);
  });

  testWidgets('tapping a thumbnail previews that shot rather than offering to remove it', (tester) async {
    await open(tester);
    await shoot(tester, times: 3);
    // Read before the push: the preview is opaque, so the capture screen
    // under it is off stage and its container out of reach.
    final shots = shotsOf(tester);

    await tester.tap(thumbnails().at(1));
    await tester.pumpAndSettle();

    // A tap on a photo used to ask whether to delete it, which is not what a
    // thumbnail looks like it does. It opens the photo.
    expect(find.byType(ShotPreviewScreen), findsOneWidget);
    expect(find.text('2 of 3'), findsOneWidget);
    expect(find.text('Remove this photo?'), findsNothing);

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(find.byType(ShotPreviewScreen), findsNothing);
    expect(find.byType(CaptureScreen), findsOneWidget);
    expect(shotsOf(tester), shots);
    expect(results, isEmpty);
  });

  testWidgets('Done is a compact pill, disabled until there is something to hand over', (tester) async {
    await open(tester);
    final done = find.widgetWithText(DsButton, 'Done');

    // It used to fill half the row, which read as the screen's main action
    // when the shutter is.
    expect(tester.widget<DsButton>(done).expand, isFalse);
    expect(tester.getSize(done).width, lessThan(200));
    expect(tester.getSize(done).height, 40);
    expect(tester.widget<DsButton>(done).onPressed, isNull);
    // Done sits at the right end of the row, the label pill on the left edge
    // of the panel above it.
    expect(tester.getTopRight(done).dx, closeTo(400 - DsSpace.x3, 0.5));
    expect(tester.getTopLeft(find.byType(LabelPill)).dx, closeTo(DsSpace.x3, 0.5));

    await shoot(tester);

    expect(tester.widget<DsButton>(done).onPressed, isNotNull);
  });

  testWidgets('a label set on the pill rides along with the shots taken after it', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    expect(find.text('Add a label'), findsOneWidget);
    expect(find.bySemanticsLabel('Add a label'), findsOneWidget);

    await setLabel(tester, 'Left forearm');

    expect(find.text('Add a label'), findsNothing);
    expect(find.text('Left forearm'), findsOneWidget);
    // The pill shows the label; a reader is told it *is* the label.
    expect(find.bySemanticsLabel('Labelled Left forearm'), findsOneWidget);

    await shoot(tester, times: 2);
    await tester.tap(find.widgetWithText(DsButton, 'Done'));
    await tester.pumpAndSettle();

    expect(results.single, hasLength(2));
    expect(results.single!.every((s) => s.label == 'Left forearm'), isTrue);

    handle.dispose();
  });

  testWidgets('a labelled shot is tagged in the strip and says so', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);
    await shoot(tester);
    expect(find.byKey(shotTagDotKey), findsNothing);

    await setLabel(tester, 'Left forearm');
    await shoot(tester);

    // Only the second shot was taken under the label, so only it is tagged.
    expect(find.byKey(shotTagDotKey), findsOneWidget);
    expect(find.bySemanticsLabel('1 of 2'), findsOneWidget);
    expect(find.bySemanticsLabel('2 of 2, Labelled Left forearm'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('the label pill is a button a screen reader can actually press', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester);

    final pill = tester.getSemantics(find.byType(LabelPill));
    expect(pill.hasFlag(SemanticsFlag.isButton), isTrue);
    // The node replaces everything under it, so the tap action has to be on
    // the node itself: without it the reader is handed an inert button.
    expect(pill.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);

    // Through the render tree's own pipeline owner: the binding's getter for
    // it is deprecated, and this is the same owner.
    tester
        .renderObject(find.byType(LabelPill))
        .owner!
        .semanticsOwner!
        .performAction(pill.id, SemanticsAction.tap);
    await tester.pumpAndSettle();

    expect(find.text('Label these photos'), findsOneWidget);

    handle.dispose();
  });

  testWidgets('the label pill is a full-size tap target however small it draws', (tester) async {
    await open(tester);

    final pill = find.descendant(of: find.byType(LabelPill), matching: find.byType(InkWell));
    expect(tester.getSize(pill).height, greaterThanOrEqualTo(44));
    // The pill itself still draws at its own size inside that target.
    expect(tester.getSize(find.descendant(of: find.byType(LabelPill), matching: find.byType(Row)))
        .height, lessThan(44));
  });

  testWidgets('a suggestion chip is a full-size tap target', (tester) async {
    suggestions = ['Scalp'];
    await open(tester);
    await openLabelSheet(tester);

    final inChips = find.descendant(of: find.byType(SuggestionChips), matching: find.byType(InkWell));
    expect(tester.getSize(inChips).height, greaterThanOrEqualTo(44));
    // The chip is still drawn chip-sized inside that target.
    final chip = find.descendant(of: find.byType(SuggestionChips), matching: find.byType(DsChip));
    expect(tester.getSize(chip).height, lessThan(44));
  });

  testWidgets('Clear label is offered only once a label is set, and clears it', (tester) async {
    await open(tester);

    await openLabelSheet(tester);
    expect(find.text('Clear label'), findsNothing);
    await tester.tap(find.widgetWithText(DsButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(stateOf(tester).label, isEmpty);

    await setLabel(tester, 'Left forearm');
    await openLabelSheet(tester);

    expect(find.text('Clear label'), findsOneWidget);
    await tester.tap(find.widgetWithText(DsButton, 'Clear label'));
    await tester.pumpAndSettle();

    expect(stateOf(tester).label, isEmpty);
    expect(find.text('Add a label'), findsOneWidget);
  });

  testWidgets('the patient\'s own descriptions are offered as suggestions', (tester) async {
    suggestions = ['Left forearm', 'Scalp'];
    await open(tester);

    await openLabelSheet(tester);
    expect(find.widgetWithText(DsChip, 'Left forearm'), findsOneWidget);

    await tester.tap(find.widgetWithText(DsChip, 'Scalp'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(DsButton, 'Use label'));
    await tester.pumpAndSettle();

    expect(stateOf(tester).label, 'Scalp');
  });

  testWidgets('closing with shots asks to discard, deletes the files and pops with null', (tester) async {
    await open(tester);
    await shoot(tester);
    final path = shotsOf(tester).single.path;

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Discard photos?'), findsOneWidget);

    await tester.tap(find.widgetWithText(DsButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(find.byType(CaptureScreen), findsNothing);
    expect(results, [null]);
    expect(File(path).existsSync(), isFalse);
    expect(filesOnDisk(), isEmpty);
  });

  testWidgets('at the cap the shutter is disabled and the warning shows once', (tester) async {
    await open(tester);
    await shoot(tester, times: captureLimit);

    expect(shotsOf(tester), hasLength(captureLimit));
    expect(tester.widget<ShutterButton>(find.byType(ShutterButton)).onPressed, isNull);
    // The strip followed the shots: the newest one is the one on screen.
    final strip = tester.state<ScrollableState>(
      find.descendant(of: find.byType(ShotStrip), matching: find.byType(Scrollable)),
    );
    expect(strip.position.maxScrollExtent, greaterThan(0));
    expect(strip.position.pixels, strip.position.maxScrollExtent);
    expect(find.text('Up to 20 photos per session'), findsOneWidget);
    // Done still works at the cap.
    expect(tester.widget<DsButton>(find.widgetWithText(DsButton, 'Done')).onPressed, isNotNull);

    // The banner is queued, so a second one would appear after this one goes.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Up to 20 photos per session'), findsNothing);
  });

  testWidgets('a camera that will not start offers a retry that starts it', (tester) async {
    fake.failStart = true;
    await open(tester);

    expect(find.text('Camera unavailable'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
    expect(find.byKey(const Key('fake-preview')), findsNothing);

    fake.failStart = false;
    await tester.tap(find.widgetWithText(DsButton, 'Try again'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('fake-preview')), findsOneWidget);
    expect(find.text('Camera unavailable'), findsNothing);
    expect(fake.startCount, 2);
  });

  testWidgets('the torch toggle flips its tooltip and forwards to the camera', (tester) async {
    await open(tester);
    expect(find.byTooltip('Turn torch on'), findsOneWidget);

    await tester.tap(find.byTooltip('Turn torch on'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('Turn torch off'), findsOneWidget);
    expect(find.byTooltip('Turn torch on'), findsNothing);
    expect(fake.torchCalls, [true]);
  });

  testWidgets('the camera is released in the background and re-opened on resume, keeping the shots', (tester) async {
    await open(tester);
    await shoot(tester);
    expect(fake.startCount, 1);

    await lifecycle(tester, AppLifecycleState.paused);

    // One release, though a real pause arrives as three states. Asserted on
    // the camera and the session rather than on the tree: a backgrounded app
    // draws no frames, so the widgets still show the last foreground build.
    expect(fake.stopCount, 1);
    expect(fake.isReady, isFalse);
    expect(stateOf(tester).status, CaptureStatus.starting);

    await lifecycle(tester, AppLifecycleState.resumed);

    expect(fake.startCount, 2);
    expect(shotsOf(tester), hasLength(1));
    expect(thumbnails(), findsOneWidget);
    expect(find.text('1 photo'), findsOneWidget);
    expect(find.byKey(const Key('fake-preview')), findsOneWidget);
  });

  testWidgets('a failed capture is reported and leaves the count alone', (tester) async {
    await open(tester);
    fake.failCapture = true;

    await tester.tap(find.byType(ShutterButton));
    await tester.pumpAndSettle();

    expect(find.text('Could not take the photo. Try again.'), findsOneWidget);
    expect(shotsOf(tester), isEmpty);
    expect(thumbnails(), findsNothing);
    expect(find.text('No photos yet'), findsOneWidget);

    // Let the banner finish, so it is not still queued at the end of the test.
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
  });

  testWidgets('a focus tap is mapped into the camera frame, not the cropped view', (tester) async {
    fake.aspectRatio = 16 / 9;
    await open(tester);
    final area = tester.getRect(find.byKey(capturePreviewAreaKey));

    await tester.tapAt(area.center);
    await tester.pumpAndSettle();

    expect(fake.focusCalls, hasLength(1));
    expect(fake.focusCalls.single.dx, closeTo(0.5, 0.01));
    expect(fake.focusCalls.single.dy, closeTo(0.5, 0.01));

    await tester.tapAt(Offset(area.left + 1, area.center.dy));
    await tester.pumpAndSettle();

    // A 16:9 frame covering a portrait area is cropped left and right, so the
    // screen's left edge is well inside the frame rather than at its edge.
    expect(fake.focusCalls, hasLength(2));
    expect(fake.focusCalls.last.dx, inExclusiveRange(0.2, 0.45));
    expect(fake.focusCalls.last.dy, closeTo(0.5, 0.01));
  });

  testWidgets('a portrait preview is sized and read in the ratio it is displayed at', (tester) async {
    // What `CameraService.previewAspectRatio` reports is the *displayed* ratio,
    // so a portrait preview of a 16:9 sensor arrives as 9:16. The cover box has
    // to be built in that ratio: sized with the sensor's own 1.78 it would be a
    // landscape box, and its tight constraints would squash the texture.
    fake.aspectRatio = 9 / 16;
    await open(tester);

    final box = tester
        .widgetList<SizedBox>(find.descendant(of: find.byType(FittedBox), matching: find.byType(SizedBox)))
        .firstWhere((s) => s.height == 1000);
    expect(box.width, closeTo(562.5, 0.01));

    final area = tester.getRect(find.byKey(capturePreviewAreaKey));
    await tester.tapAt(area.center);
    await tester.pumpAndSettle();

    expect(fake.focusCalls.single.dx, closeTo(0.5, 0.01));
    expect(fake.focusCalls.single.dy, closeTo(0.5, 0.01));

    await tester.tapAt(Offset(area.left + 1, area.center.dy));
    await tester.pumpAndSettle();

    // A 9:16 frame in a 400-wide portrait area is cropped top and bottom, not
    // left and right, so the area's left edge really is the frame's left edge.
    // Sized in the sensor's ratio instead, this tap would land near 0.31.
    expect(fake.focusCalls.last.dx, lessThan(0.1));
    expect(fake.focusCalls.last.dy, closeTo(0.5, 0.05));
  });

  testWidgets('a shot and a focus tap leave the camera preview alone', (tester) async {
    await open(tester);
    final builds = fake.previewBuilds;
    expect(builds, greaterThan(0));

    await shoot(tester);

    expect(thumbnails(), findsOneWidget);
    expect(fake.previewBuilds, builds);

    await tester.tapAt(tester.getRect(find.byKey(capturePreviewAreaKey)).center);
    await tester.pumpAndSettle();

    expect(fake.focusCalls, hasLength(1));
    expect(fake.previewBuilds, builds);
  });

  testWidgets('system back with shots asks to discard, then pops with null', (tester) async {
    await open(tester);
    await shoot(tester);
    final path = shotsOf(tester).single.path;

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Discard photos?'), findsOneWidget);

    await tester.tap(find.widgetWithText(DsButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(find.byType(CaptureScreen), findsNothing);
    expect(results, [null]);
    expect(File(path).existsSync(), isFalse);
  });

  group('coverTapToFrame', () {
    void expectOffset(Offset actual, Offset expected) {
      expect(actual.dx, closeTo(expected.dx, 0.001));
      expect(actual.dy, closeTo(expected.dy, 0.001));
    }

    test('an area shaped like the frame maps straight through', () {
      const area = Size(400, 400);
      expectOffset(coverTapToFrame(const Offset(200, 200), area, 1), const Offset(0.5, 0.5));
      expectOffset(coverTapToFrame(const Offset(100, 300), area, 1), const Offset(0.25, 0.75));
      expectOffset(coverTapToFrame(Offset.zero, area, 1), Offset.zero);
      expectOffset(coverTapToFrame(const Offset(400, 400), area, 1), const Offset(1, 1));
    });

    test('a wide frame in a portrait area is read across its crop', () {
      const area = Size(400, 600);
      const wide = 1.78;
      expectOffset(coverTapToFrame(const Offset(200, 300), area, wide), const Offset(0.5, 0.5));
      // The area's left edge is a third of the way into a frame whose sides
      // are cropped away, not the frame's own left edge.
      final left = coverTapToFrame(const Offset(0, 300), area, wide);
      expect(left.dx, closeTo(0.313, 0.005));
      expect(left.dy, closeTo(0.5, 0.001));
    });

    test('the corners stay inside the frame', () {
      const area = Size(400, 600);
      final topLeft = coverTapToFrame(Offset.zero, area, 1.78);
      expect(topLeft.dx, greaterThanOrEqualTo(0));
      expect(topLeft.dy, greaterThanOrEqualTo(0));
      final bottomRight = coverTapToFrame(const Offset(400, 600), area, 1.78);
      expect(bottomRight.dx, lessThanOrEqualTo(1));
      expect(bottomRight.dy, lessThanOrEqualTo(1));
    });

    test('a degenerate area or ratio aims at the middle', () {
      expectOffset(coverTapToFrame(Offset.zero, Size.zero, 1), const Offset(0.5, 0.5));
      expectOffset(coverTapToFrame(Offset.zero, const Size(400, 600), 0), const Offset(0.5, 0.5));
    });
  });
}
