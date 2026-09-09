import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:mocktail/mocktail.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_connectivity.dart';
import '../../helpers/pump_app.dart';

class MockTomogramApi extends Mock implements TomogramApi {}

class MockMediaPickerService extends Mock implements MediaPickerService {}

class MockTomogramHistoryApi extends Mock implements TomogramHistoryApi {}

const jane = Patient(id: 1, opid: 42, name: 'Jane Doe');

void main() {
  late Directory dir;
  late Directory docs;
  late SharedPreferences prefs;
  late MockTomogramApi api;
  late MockMediaPickerService picker;
  late MockTomogramHistoryApi history;
  late FakeConnectivityService connectivity;

  setUpAll(() => registerFallbackValue(MediaSource.gallery));

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tomo_screen');
    docs = await Directory.systemTemp.createTemp('tomo_docs');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = MockTomogramApi();
    picker = MockMediaPickerService();
    history = MockTomogramHistoryApi();
    connectivity = FakeConnectivityService();
    when(() => picker.deniedPermissions(any())).thenAnswer((_) async => []);
    when(() => history.list(any())).thenAnswer((_) async => const []);
  });
  tearDown(() async {
    await connectivity.close();
    await dir.delete(recursive: true);
    await docs.delete(recursive: true);
  });

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
          tomogramHistoryApiProvider.overrideWithValue(history),
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDocumentsDirProvider.overrideWithValue(docs),
          connectivityServiceProvider.overrideWithValue(connectivity),
          uuidProvider.overrideWithValue(() => 'id'),
          // The queue only runs for a signed-in user.
          accessTokenProvider.overrideWithValue('test-token'),
        ],
      );

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(TomogramScreen)));

  List<PendingUpload> queueOf(WidgetTester tester) =>
      containerOf(tester).read(uploadQueueProvider).valueOrNull ?? const [];

  testWidgets('shows patient name, OP chip and empty state', (tester) async {
    await pump(tester);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('42'), findsOneWidget);
    expect(find.text('There is no tomogram added.'), findsOneWidget);
    expect(find.textContaining("'+' button"), findsOneWidget);
    expect(find.text('Upload'), findsNothing);
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
    expect(find.text('1 of 1'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
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
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tomogram: Uploaded'), findsOneWidget);
    final captured = verify(() => api.upload(42, captureAny())).captured.single as List<TomogramDraft>;
    expect(captured.single.description, 'left forearm');
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('an upload in flight shows the progress bar and disables Upload', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.camera))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 0));
    final gate = Completer<List<UploadResult>>();
    when(() => api.upload(42, any())).thenAnswer((_) => gate.future);
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('Upload'));
    await tester.pump();
    expect(find.byType(DsProgressBar), findsOneWidget);
    expect(tester.widget<DsButton>(find.widgetWithText(DsButton, 'Upload')).onPressed, isNull);

    gate.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byType(DsProgressBar), findsNothing);
    expect(find.text('Tomogram: Uploaded'), findsOneWidget);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('a rejected upload flashes the error, keeps the card and does not queue', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.camera))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 0));
    when(() => api.upload(any(), any())).thenThrow(const RejectedFailure('Image too large'));
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tomogram Upload: Image too large'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(queueOf(tester), isEmpty);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('back with drafts asks to discard and clears them on confirm', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.camera))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 0));
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    expect(find.text('Description'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(find.text('Discard photos?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Description'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.text('Description'), findsNothing);
    expect(find.text('There is no tomogram added.'), findsOneWidget);
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

  testWidgets('history sits above the empty state and reloads after an upload', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => history.list(42)).thenAnswer((_) async => [
          TomogramSet(
            id: 9,
            dateTime: DateTime(2026, 9, 8, 14, 32),
            doctorId: 1,
            tomogramTypeId: 1,
            details: const [TomogramSetDetail(id: 1, tomogramPartId: 1, narration: 'scalp')],
          ),
        ]);
    when(() => picker.pick(MediaSource.camera))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 0));
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);

    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('Already uploaded'), findsOneWidget);
    expect(find.text('1 set'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Already uploaded')).dy,
      lessThan(tester.getCenter(find.text('There is no tomogram added.')).dy),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Tomogram: Uploaded'), findsOneWidget);
    verify(() => history.list(42)).called(2);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('a connection failure queues the photos, clears the drafts and says so', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.camera))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 0));
    when(() => api.upload(any(), any())).thenThrow(const CannotConnectFailure());
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'left forearm');

    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Saved offline. It will upload when the server is reachable.'), findsOneWidget);
    expect(find.text('Description'), findsNothing);
    expect(find.text('There is no tomogram added.'), findsOneWidget);
    final queued = queueOf(tester).single;
    expect(queued.opid, 42);
    expect(queued.patientName, 'Jane Doe');
    expect(queued.files.single.description, 'left forearm');
    expect(File(queued.files.single.path).existsSync(), isTrue);
    // The staged copy is a separate file, so clearing the drafts only removed
    // the picker original.
    expect(f.existsSync(), isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('a timeout queues the photos too', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.camera))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 0));
    when(() => api.upload(any(), any())).thenThrow(const TimeoutFailure());
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Saved offline. It will upload when the server is reachable.'), findsOneWidget);
    expect(queueOf(tester).length, 1);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('a queued entry for this patient shows a waiting line above history', (tester) async {
    when(() => history.list(42)).thenAnswer((_) async => [
          TomogramSet(
            id: 9,
            dateTime: DateTime(2026, 9, 8, 14, 32),
            doctorId: 1,
            tomogramTypeId: 1,
            details: const [],
          ),
        ]);
    await PendingUploadsRepository(prefs, docs).write([
      PendingUpload(
        id: 'q1',
        opid: 42,
        patientName: 'Jane Doe',
        files: const [PendingFile(path: 'a.jpg', description: ''), PendingFile(path: 'b.jpg', description: '')],
        createdAt: DateTime.utc(2026, 9, 9),
      ),
    ]);

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('2 photos waiting to upload'), findsOneWidget);
    expect(
      tester.getCenter(find.text('2 photos waiting to upload')).dy,
      lessThan(tester.getCenter(find.text('Already uploaded')).dy),
    );
  });

  testWidgets('no waiting line when the queue holds nothing for this patient', (tester) async {
    await PendingUploadsRepository(prefs, docs).write([
      PendingUpload(
        id: 'q1',
        opid: 7,
        patientName: 'Someone Else',
        files: const [PendingFile(path: 'a.jpg', description: '')],
        createdAt: DateTime.utc(2026, 9, 9),
      ),
    ]);

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('waiting to upload'), findsNothing);
  });

  testWidgets('the waiting line counts every queued photo for this patient', (tester) async {
    await PendingUploadsRepository(prefs, docs).write([
      PendingUpload(
        id: 'q1',
        opid: 42,
        patientName: 'Jane Doe',
        files: const [PendingFile(path: 'a.jpg', description: ''), PendingFile(path: 'b.jpg', description: '')],
        createdAt: DateTime.utc(2026, 9, 9),
      ),
      PendingUpload(
        id: 'q2',
        opid: 42,
        patientName: 'Jane Doe',
        files: const [PendingFile(path: 'c.jpg', description: '')],
        createdAt: DateTime.utc(2026, 9, 9, 1),
      ),
      PendingUpload(
        id: 'q3',
        opid: 7,
        patientName: 'Someone Else',
        files: const [PendingFile(path: 'd.jpg', description: '')],
        createdAt: DateTime.utc(2026, 9, 9, 2),
      ),
    ]);

    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('3 photos waiting to upload'), findsOneWidget);
  });

  testWidgets('a staging failure reports the upload error and keeps the drafts', (tester) async {
    final f = File('${dir.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);
    when(() => picker.pick(MediaSource.camera))
        .thenAnswer((_) async => MediaPickResult(accepted: [f.path], rejected: 0));
    when(() => api.upload(any(), any())).thenThrow(const CannotConnectFailure());
    await pump(tester);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    // The OS cleared the picker cache between the pick and the upload, so the
    // queue cannot copy the file aside.
    f.deleteSync();

    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Tomogram Upload: Could not reach the server'), findsOneWidget);
    expect(find.text('Description'), findsOneWidget);
    expect(queueOf(tester), isEmpty);
    expect(Directory('${docs.path}/pending/id').existsSync(), isFalse);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });
}
