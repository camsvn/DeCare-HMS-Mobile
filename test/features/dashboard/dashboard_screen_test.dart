import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/dio_client.dart';
import 'package:hms_uploader/core/design/design.dart';
import 'package:hms_uploader/core/modules/app_module.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/dashboard/dashboard.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_connectivity.dart';
import '../../helpers/pump_app.dart';

class MockHealthCheckApi extends Mock implements HealthCheckApi {}

class MockTomogramApi extends Mock implements TomogramApi {}

AppModule fakeModule(String id, String title) => AppModule(
      id: id,
      title: (_) => title,
      subtitle: (_) => 'sub',
      icon: Icons.extension,
      entryRoute: '/app/$id',
      routes: const [],
    );

void main() {
  late Directory docs;
  late SharedPreferences prefs;
  late MockHealthCheckApi api;
  late MockTomogramApi uploads;
  late FakeConnectivityService connectivity;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('dash_docs');
    SharedPreferences.setMockInitialValues({'server_url': 'http://cutis.decare.team'});
    prefs = await SharedPreferences.getInstance();
    api = MockHealthCheckApi();
    uploads = MockTomogramApi();
    connectivity = FakeConnectivityService();
    when(() => api.check(any())).thenAnswer((_) async {});
  });
  tearDown(() async {
    await connectivity.close();
    await docs.delete(recursive: true);
  });

  List<Override> baseOverrides() => [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStoreProvider.overrideWithValue(InMemorySecureStore()),
        healthCheckApiProvider.overrideWithValue(api),
        appDocumentsDirProvider.overrideWithValue(docs),
        connectivityServiceProvider.overrideWithValue(connectivity),
        tomogramApiProvider.overrideWithValue(uploads),
        // The queue only runs for a signed-in user.
        accessTokenProvider.overrideWithValue('test-token'),
      ];

  /// A staged photo that really is on disk: the queue discards an entry whose
  /// files have vanished, so a fixture pointing at nothing is never uploaded.
  String stagedPath(String name) {
    final file = File('${docs.path}/$name')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0]);
    return file.path;
  }

  PendingUpload pending({int attempts = 0, String? lastError}) => PendingUpload(
        id: 'q1',
        opid: 42,
        patientName: 'Jane Doe',
        files: [
          PendingFile(path: stagedPath('a.jpg'), description: ''),
          PendingFile(path: stagedPath('b.jpg'), description: ''),
        ],
        createdAt: DateTime.utc(2026, 9, 9),
        attempts: attempts,
        lastError: lastError,
      );

  Future<void> pumpDashboard(WidgetTester tester) => pumpApp(
        tester,
        DashboardScreen(modules: [fakeModule('a', 'Alpha')]),
        overrides: baseOverrides(),
      );

  testWidgets('renders a card per module plus placeholder when only one', (tester) async {
    await pumpDashboard(tester);
    await tester.pumpAndSettle();
    expect(find.byType(ModuleCard), findsOneWidget);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('More modules coming'), findsOneWidget);
    expect(find.text('cutis.decare.team'), findsOneWidget);
    expect(find.text('Connected'), findsOneWidget);
  });

  testWidgets('no placeholder with two modules; unreachable server shows warning text', (tester) async {
    when(() => api.check(any())).thenThrow(Exception('down'));
    await pumpApp(
      tester,
      DashboardScreen(modules: [fakeModule('a', 'Alpha'), fakeModule('b', 'Beta')]),
      overrides: baseOverrides(),
    );
    await tester.pumpAndSettle();
    expect(find.byType(ModuleCard), findsNWidgets(2));
    expect(find.byType(ModulePlaceholderCard), findsNothing);
    expect(find.text('Server unreachable'), findsOneWidget);
  });

  testWidgets('no pending chip when the queue is empty', (tester) async {
    await pumpDashboard(tester);
    await tester.pumpAndSettle();
    expect(find.textContaining('pending'), findsNothing);
  });

  testWidgets('a queued upload shows a chip that opens the sheet and retries', (tester) async {
    await PendingUploadsRepository(prefs, docs).write([pending()]);
    when(() => uploads.upload(any(), any())).thenAnswer((_) async => const []);
    await pumpDashboard(tester);
    await tester.pumpAndSettle();

    expect(find.text('1 pending'), findsOneWidget);
    await tester.tap(find.text('1 pending'));
    await tester.pumpAndSettle();
    expect(find.text('Pending uploads'), findsOneWidget);
    expect(find.text('Jane Doe'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.text('Retry now'));
    await tester.pumpAndSettle();

    verify(() => uploads.upload(42, any())).called(1);
    expect(find.text('Jane Doe'), findsNothing);
    expect(find.text('1 pending'), findsNothing);
  });

  testWidgets('discarding a queued upload asks first, then drops it', (tester) async {
    await PendingUploadsRepository(prefs, docs).write([pending()]);
    await pumpDashboard(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 pending'));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(find.text('Discard pending upload?'), findsOneWidget);
    expect(find.text('The photos will be deleted from this device.'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.text('Jane Doe'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Jane Doe'), findsNothing);
    expect(PendingUploadsRepository(prefs, docs).read(), isEmpty);
    verifyNever(() => uploads.upload(any(), any()));
  });

  testWidgets('an exhausted entry names the failure in the sheet', (tester) async {
    await PendingUploadsRepository(prefs, docs)
        .write([pending(attempts: maxUploadAttempts, lastError: 'Image too large')]);
    await pumpDashboard(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 pending'));
    await tester.pumpAndSettle();

    expect(find.text('Failed 5 times: Image too large'), findsOneWidget);
  });

  testWidgets('one failure already names the reason in the sheet', (tester) async {
    await PendingUploadsRepository(prefs, docs).write([pending(attempts: 1, lastError: 'Image too large')]);
    await pumpDashboard(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 pending'));
    await tester.pumpAndSettle();

    expect(find.text('Failed 1 times: Image too large'), findsOneWidget);
  });

  testWidgets('a long queue scrolls and keeps Retry now on screen', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await PendingUploadsRepository(prefs, docs).write([
      for (var i = 0; i < 8; i++)
        PendingUpload(
          id: 'q$i',
          opid: 40 + i,
          patientName: 'Patient $i',
          files: [PendingFile(path: stagedPath('a.jpg'), description: '')],
          createdAt: DateTime.utc(2026, 9, 9),
        ),
    ]);
    when(() => uploads.upload(any(), any())).thenAnswer((_) async => const []);
    await pumpDashboard(tester);
    await tester.pumpAndSettle();
    await tester.tap(find.text('8 pending'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    final button = tester.getRect(find.text('Retry now'));
    expect(button.bottom, lessThanOrEqualTo(700.0));
    expect(button.top, greaterThanOrEqualTo(0.0));

    // The rows scroll rather than growing the sheet past the footer.
    final firstRowTop = tester.getRect(find.text('Patient 0')).top;
    await tester.drag(find.text('Patient 0'), const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Patient 0')).top, lessThan(firstRowTop));
    expect(tester.getRect(find.text('Retry now')), button);

    // A tap that lands proves the footer is hit-testable, not just laid out.
    await tester.tap(find.text('Retry now'));
    await tester.pumpAndSettle();
    verify(() => uploads.upload(any(), any())).called(8);
  });
}
