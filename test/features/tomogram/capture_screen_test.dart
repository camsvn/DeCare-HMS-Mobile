import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

import '../../helpers/fake_camera_service.dart';
import '../../helpers/pump_app.dart';

void main() {
  late Directory dir;
  late FakeCameraService fake;

  /// What the pushed screen popped with, one entry per completed push.
  late List<List<String>?> results;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('capture_screen');
    fake = FakeCameraService(dir: dir);
    results = [];
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
              await Navigator.of(context).push<List<String>>(
                MaterialPageRoute(builder: (_) => const CaptureScreen()),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
      overrides: [cameraServiceProvider.overrideWithValue(fake)],
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

  List<String> shotsOf(WidgetTester tester) => stateOf(tester).shots;

  Finder thumbnails() => find.descendant(of: find.byType(ShotStrip), matching: find.byType(Image));

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
    expect(results.single!.first, endsWith('shot_0.jpg'));
    expect(results.single!.last, endsWith('shot_1.jpg'));
    // Handed over, not discarded: the draft list owns the files now.
    expect(filesOnDisk(), hasLength(2));
  });

  testWidgets('tapping a thumbnail asks, then removes it and deletes the file', (tester) async {
    await open(tester);
    await shoot(tester);
    final path = shotsOf(tester).single;

    await tester.tap(thumbnails());
    await tester.pumpAndSettle();
    expect(find.text('Remove this photo?'), findsOneWidget);
    expect(find.text('It has not been added yet and will be deleted.'), findsOneWidget);

    await tester.tap(find.widgetWithText(DsButton, 'Remove'));
    await tester.pumpAndSettle();

    expect(thumbnails(), findsNothing);
    expect(find.text('No photos yet'), findsOneWidget);
    expect(File(path).existsSync(), isFalse);
    expect(results, isEmpty);
  });

  testWidgets('closing with shots asks to discard, deletes the files and pops with null', (tester) async {
    await open(tester);
    await shoot(tester);
    final path = shotsOf(tester).single;

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
    final path = shotsOf(tester).single;

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
