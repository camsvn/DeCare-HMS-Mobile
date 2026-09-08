import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../helpers/pump_app.dart';

class MockTomogramApi extends Mock implements TomogramApi {}

class MockMediaPickerService extends Mock implements MediaPickerService {}

const jane = Patient(id: 1, opid: 42, name: 'Jane Doe');

void main() {
  late Directory dir;
  late MockTomogramApi api;
  late MockMediaPickerService picker;

  setUpAll(() => registerFallbackValue(MediaSource.gallery));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tomo_screen');
    api = MockTomogramApi();
    picker = MockMediaPickerService();
    when(() => picker.deniedPermissions(any())).thenAnswer((_) async => []);
  });
  tearDown(() => dir.delete(recursive: true));

  Future<void> pump(
    WidgetTester tester, {
    void Function(List<Permission> denied)? onPermissionsDenied,
  }) =>
      pumpApp(
        tester,
        TomogramScreen(patient: jane, onPermissionsDenied: onPermissionsDenied),
        overrides: [
          tomogramApiProvider.overrideWithValue(api),
          mediaPickerServiceProvider.overrideWithValue(picker),
          uuidProvider.overrideWithValue(() => 'id'),
        ],
      );

  testWidgets('shows patient name and empty state', (tester) async {
    await pump(tester);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('There is no tomogram added.'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);
  });

  testWidgets('plus opens the sheet; gallery pick adds a card and enables upload', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.gallery))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 1));
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(find.text('Choose from Gallery'), findsOneWidget);
    expect(find.text('Take Photo'), findsOneWidget);
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Description'), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.text('Tomogram: Only JPEG images are supported'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('over-limit gallery picks are reported instead of dropped silently', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.gallery))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 0, overLimit: 1));
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tomogram: Only 2 images per pick'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('upload success flashes and clears drafts', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.camera))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 0));
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'left forearm');
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tomogram: Uploaded'), findsOneWidget);
    final captured = verify(() => api.upload(42, captureAny())).captured.single as List<TomogramDraft>;
    expect(captured.single.description, 'left forearm');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('upload failure flashes error and keeps the card', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.camera))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 0));
    when(() => api.upload(any(), any())).thenThrow(const TimeoutFailure());
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.check));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tomogram Upload: The server took too long to respond'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('denied permission navigates away instead of picking', (tester) async {
    when(() => picker.deniedPermissions(MediaSource.camera)).thenAnswer((_) async => [Permission.camera]);
    await pump(tester, onPermissionsDenied: (_) {});
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    verifyNever(() => picker.pick(any()));
  });
}
