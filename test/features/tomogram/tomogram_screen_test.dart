import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/features/patient_lookup/patient_lookup.dart';
import 'package:hms_uploader/features/tomogram/presentation/widgets/tomogram_card.dart';
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

/// A queue whose staging never finishes until [gate] does, so a test can leave
/// the screen mid-enqueue.
class GatedQueue extends UploadQueueController {
  GatedQueue(this.gate);

  final Completer<void> gate;

  @override
  Future<void> enqueue(int opid, String patientName, List<TomogramDraft> drafts) => gate.future;
}

/// Drops the screen out of the tree without tearing the [ProviderScope] down
/// with it — a route change, not the app exiting.
class Host extends StatefulWidget {
  const Host({super.key, required this.child});

  final Widget child;

  @override
  State<Host> createState() => HostState();
}

class HostState extends State<Host> {
  var _visible = true;

  void hide() => setState(() => _visible = false);

  @override
  Widget build(BuildContext context) => _visible ? widget.child : const SizedBox.shrink();
}

const jane = Patient(id: 1, opid: 42, name: 'Jane Doe');

/// What the capture screen pops for [paths]: unlabelled shots, which is what
/// this screen sees when nothing was typed while shooting.
List<Shot> shotsFor(Iterable<String> paths) => [for (final path in paths) Shot(path: path)];

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
    Future<List<Shot>?> Function(BuildContext context)? onCapture,
    String Function()? uuid,
    UploadQueueController Function()? queue,
    GlobalKey<HostState>? host,
  }) {
    final screen =
        TomogramScreen(patient: jane, onPermissionsDenied: onPermissionsDenied, onCapture: onCapture);
    return pumpApp(
        tester,
        host == null ? screen : Host(key: host, child: screen),
        overrides: [
          tomogramApiProvider.overrideWithValue(api),
          mediaPickerServiceProvider.overrideWithValue(picker),
          tomogramHistoryApiProvider.overrideWithValue(history),
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDocumentsDirProvider.overrideWithValue(docs),
          connectivityServiceProvider.overrideWithValue(connectivity),
          uuidProvider.overrideWithValue(uuid ?? () => 'id'),
          // The queue only runs for a signed-in user.
          accessTokenProvider.overrideWithValue('test-token'),
          if (queue != null) uploadQueueProvider.overrideWith(queue),
        ],
      );
  }

  ProviderContainer containerOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(TomogramScreen)));

  List<PendingUpload> queueOf(WidgetTester tester) =>
      containerOf(tester).read(uploadQueueProvider).valueOrNull ?? const [];

  /// Distinct draft ids, so two photos are two cards rather than one key clash.
  String Function() ids() {
    var n = 0;
    return () => 'id${++n}';
  }

  /// Two cards do not fit the default 800x600 surface, which would leave the
  /// second card unbuilt and its description field off-screen. Only the height
  /// changes: a narrower surface would overflow the dialog's buttons under the
  /// test font, whose glyphs are all em squares.
  void tallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  String descriptionAt(WidgetTester tester, int i) =>
      tester.widget<TextField>(find.byType(TextField).at(i)).controller!.text;

  /// The description field's placeholder on card [i], or null when it has
  /// none. Read off the field so no other text on the card can stand in for it.
  String? hintAt(WidgetTester tester, int i) =>
      tester.widget<TextField>(find.byType(TextField).at(i)).decoration?.hintText;

  /// Text inside card [card] only: the history card above the list renders the
  /// same narrations, so an unscoped finder would match twice.
  Finder textOn(int card, String text) =>
      find.descendant(of: find.byType(TomogramCard).at(card), matching: find.text(text));

  Finder chipsOn(int card) =>
      find.descendant(of: find.byType(TomogramCard).at(card), matching: find.byType(SuggestionChips));

  /// One uploaded set for OP 42 whose only narration is [narration].
  void historyWith(String narration) => when(() => history.list(42)).thenAnswer((_) async => [
        TomogramSet(
          id: 9,
          dateTime: DateTime(2026, 9, 8, 14, 32),
          doctorId: 1,
          tomogramTypeId: 1,
          details: [TomogramSetDetail(id: 1, tomogramPartId: 1, narration: narration)],
        ),
      ]);

  File jpeg(String name) => File('${dir.path}/$name')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

  /// Captures two photos through the injected capture route: the first taken
  /// under [label], the second without one.
  Future<void> pumpTwoDrafts(WidgetTester tester, {String label = ''}) async {
    tallSurface(tester);
    final shots = [Shot(path: jpeg('a.jpg').path, label: label), Shot(path: jpeg('b.jpg').path)];
    await pump(tester, uuid: ids(), onCapture: (_) async => shots);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
  }

  testWidgets('photos that arrive after the screen is gone are deleted', (tester) async {
    // The capture screen can pop its paths into a screen that is no longer
    // there (a route change or a deep link while it was open). Nothing owns
    // those files then, so they must not be left behind in the cache.
    final paths = [jpeg('a.jpg').path, jpeg('b.jpg').path];
    final popped = Completer<List<Shot>?>();
    await pump(tester, onCapture: (_) => popped.future);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    expect(paths.every((p) => File(p).existsSync()), isTrue);

    await tester.pumpWidget(const SizedBox());
    popped.complete(shotsFor(paths));
    await tester.pump();

    expect(paths.any((p) => File(p).existsSync()), isFalse);
  });

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
    when(() => picker.pickFromGallery())
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
    when(() => picker.pickFromGallery())
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
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);
    await pump(tester, onCapture: (_) async => shotsFor([f.path]));
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
    final gate = Completer<List<UploadResult>>();
    when(() => api.upload(42, any())).thenAnswer((_) => gate.future);
    await pump(tester, onCapture: (_) async => shotsFor([f.path]));
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
    when(() => api.upload(any(), any())).thenThrow(const RejectedFailure('Image too large'));
    await pump(tester, onCapture: (_) async => shotsFor([f.path]));
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
    await pump(tester, onCapture: (_) async => shotsFor([f.path]));
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

  testWidgets('denied camera permission navigates away instead of capturing', (tester) async {
    when(() => picker.deniedPermissions(MediaSource.camera)).thenAnswer((_) async => [Permission.camera]);
    var denied = <Permission>[];
    var captures = 0;
    await pump(
      tester,
      onPermissionsDenied: (d) => denied = d,
      onCapture: (_) async {
        captures++;
        return null;
      },
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();
    expect(denied, [Permission.camera]);
    expect(captures, 0);
    verifyNever(() => picker.pickFromGallery());
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
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);

    await pump(tester, onCapture: (_) async => shotsFor([f.path]));
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
    when(() => api.upload(any(), any())).thenThrow(const CannotConnectFailure());
    await pump(tester, onCapture: (_) async => shotsFor([f.path]));
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
    when(() => api.upload(any(), any())).thenThrow(const TimeoutFailure());
    await pump(tester, onCapture: (_) async => shotsFor([f.path]));
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
    when(() => api.upload(any(), any())).thenThrow(const CannotConnectFailure());
    await pump(tester, onCapture: (_) async => shotsFor([f.path]));
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

  testWidgets('Take Photo hands off to the capture route and adds what it returns', (tester) async {
    tallSurface(tester);
    final paths = [jpeg('a.jpg').path, jpeg('b.jpg').path];
    var captures = 0;
    await pump(
      tester,
      uuid: ids(),
      onCapture: (_) async {
        captures++;
        return shotsFor(paths);
      },
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();

    expect(captures, 1);
    expect(find.byType(TomogramCard), findsNWidgets(2));
    expect(find.text('2 of 2'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    // Capturing no longer goes anywhere near the system picker.
    verifyNever(() => picker.pickFromGallery());
  });

  testWidgets('a discarded capture leaves the empty state in place', (tester) async {
    await pump(tester, onCapture: (_) async => null);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();

    expect(find.byType(TomogramCard), findsNothing);
    expect(find.text('There is no tomogram added.'), findsOneWidget);
    expect(find.text('Upload'), findsNothing);
  });

  testWidgets('capture labels arrive as descriptions and inherit forward', (tester) async {
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);
    await pumpTwoDrafts(tester, label: 'Left forearm');

    // The label the photos were taken under is already in the first field, and
    // the blank second card says what it will upload with.
    expect(descriptionAt(tester, 0), 'Left forearm');
    expect(descriptionAt(tester, 1), '');
    expect(hintAt(tester, 0), isNull);
    expect(hintAt(tester, 1), 'Same as previous photo: Left forearm');
    expect(find.text('Same as previous photo: Left forearm'), findsOneWidget);

    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    final posted = verify(() => api.upload(42, captureAny())).captured.single as List<TomogramDraft>;
    expect(posted.map((d) => d.description), ['Left forearm', 'Left forearm']);
    // The set's descriptions are offered on the next patient.
    expect(prefs.getStringList(RecentLabelsRepository.key), ['Left forearm']);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('typing on the second photo replaces the inherited placeholder', (tester) async {
    await pumpTwoDrafts(tester, label: 'Left forearm');
    expect(hintAt(tester, 1), 'Same as previous photo: Left forearm');

    await tester.enterText(find.byType(TextField).at(1), 'Back');
    await tester.pump();

    expect(hintAt(tester, 1), isNull);
    expect(find.text('Same as previous photo: Left forearm'), findsNothing);
  });

  testWidgets('a blank first photo has nothing to inherit', (tester) async {
    await pumpTwoDrafts(tester);

    expect(hintAt(tester, 0), isNull);
    expect(hintAt(tester, 1), isNull);
    expect(find.textContaining('Same as previous photo'), findsNothing);
  });

  testWidgets('an empty card offers the patient history and recent labels as chips', (tester) async {
    historyWith('Back');
    await prefs.setStringList(RecentLabelsRepository.key, ['Neck']);
    await pumpTwoDrafts(tester);
    await tester.pumpAndSettle();

    // This patient's own narration first, then the device's recent labels.
    expect(textOn(0, 'Back'), findsOneWidget);
    expect(textOn(0, 'Neck'), findsOneWidget);

    await tester.tap(textOn(0, 'Back'));
    await tester.pumpAndSettle();

    expect(descriptionAt(tester, 0), 'Back');
    // A field with text in it has nothing left to suggest.
    expect(chipsOn(0), findsNothing);
    expect(chipsOn(1), findsOneWidget);
  });

  testWidgets('no chips when there is nothing to suggest', (tester) async {
    await pumpTwoDrafts(tester);
    await tester.pumpAndSettle();

    expect(find.byType(SuggestionChips), findsNothing);
  });

  testWidgets('Apply to all is gone', (tester) async {
    await pumpTwoDrafts(tester, label: 'Left forearm');

    expect(find.text('Apply to all'), findsNothing);
    expect(find.text('Apply to all photos?'), findsNothing);
  });

  testWidgets('queueing offline stores the resolved descriptions and remembers them', (tester) async {
    when(() => api.upload(any(), any())).thenThrow(const CannotConnectFailure());
    await pumpTwoDrafts(tester, label: 'Left forearm');

    await tester.tap(find.text('Upload'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Saved offline. It will upload when the server is reachable.'), findsOneWidget);
    final queued = queueOf(tester).single;
    expect(queued.files.map((f) => f.description), ['Left forearm', 'Left forearm']);
    expect(prefs.getStringList(RecentLabelsRepository.key), ['Left forearm']);
    await tester.pump(const Duration(seconds: 4));
    await tester.pumpAndSettle();
  });

  testWidgets('a whitespace-only description still counts as empty', (tester) async {
    await prefs.setStringList(RecentLabelsRepository.key, ['Neck']);
    await pumpTwoDrafts(tester);
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).at(0), '   ');
    await tester.pumpAndSettle();

    // Spaces are not a description: the card still offers what it would upload
    // with, exactly as resolvedDrafts treats it.
    expect(chipsOn(0), findsOneWidget);
  });

  testWidgets('leaving the screen mid-enqueue does not throw', (tester) async {
    final gate = Completer<void>();
    final host = GlobalKey<HostState>();
    when(() => api.upload(any(), any())).thenThrow(const CannotConnectFailure());
    tallSurface(tester);
    final shots = [Shot(path: jpeg('a.jpg').path, label: 'Left forearm')];
    await pump(tester, uuid: ids(), host: host, queue: () => GatedQueue(gate), onCapture: (_) async => shots);
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Take Photo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Upload'));
    await tester.pump();

    // A route change while the queue is still copying the files aside.
    host.currentState!.hide();
    await tester.pump();
    gate.complete();
    await tester.pump();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // The staging finished, so the label is remembered even though the screen
    // that started it is gone.
    expect(prefs.getStringList(RecentLabelsRepository.key), ['Left forearm']);
  });
}
