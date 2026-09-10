import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

import '../../helpers/fake_camera_service.dart';
import '../../helpers/pump_app.dart';

void main() {
  late Directory dir;
  late FakeCameraService fake;
  late ProviderContainer container;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('shot_preview');
    fake = FakeCameraService(dir: dir);
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
  }) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(
      tester,
      Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ShotPreviewScreen(initialIndex: index)),
            ),
            child: const Text('host'),
          ),
        ),
      ),
      overrides: [cameraServiceProvider.overrideWithValue(fake)],
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

  testWidgets('an unlabelled shot shows no label line', (tester) async {
    await open(tester, count: 1);

    expect(find.text('1 of 1'), findsOneWidget);
    expect(find.byKey(shotPreviewLabelKey), findsNothing);
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
