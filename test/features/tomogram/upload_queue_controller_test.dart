import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_connectivity.dart';

class MockTomogramApi extends Mock implements TomogramApi {}

class MockTomogramHistoryApi extends Mock implements TomogramHistoryApi {}

void main() {
  late Directory docs;
  late Directory picker;
  late SharedPreferences prefs;
  late MockTomogramApi api;
  late MockTomogramHistoryApi history;
  late FakeConnectivityService connectivity;
  late ProviderContainer container;
  late int nextId;

  setUp(() async {
    docs = await Directory.systemTemp.createTemp('queue_docs');
    picker = await Directory.systemTemp.createTemp('queue_picker');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    api = MockTomogramApi();
    history = MockTomogramHistoryApi();
    when(() => history.list(any())).thenAnswer((_) async => const []);
    connectivity = FakeConnectivityService();
    nextId = 0;
  });

  tearDown(() async {
    await connectivity.close();
    await docs.delete(recursive: true);
    await picker.delete(recursive: true);
  });

  /// Built lazily so a test can seed prefs before the notifier reads them.
  ProviderContainer build() {
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      appDocumentsDirProvider.overrideWithValue(docs),
      tomogramApiProvider.overrideWithValue(api),
      tomogramHistoryApiProvider.overrideWithValue(history),
      connectivityServiceProvider.overrideWithValue(connectivity),
      uuidProvider.overrideWithValue(() => 'e${nextId++}'),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  Future<UploadQueueController> notifier() async {
    final c = build();
    await c.read(uploadQueueProvider.future);
    return c.read(uploadQueueProvider.notifier);
  }

  PendingUploadsRepository repository() => PendingUploadsRepository(prefs, docs);

  /// A staged entry already on disk, as a previous app run would have left it.
  Future<PendingUpload> seed(String id, int opid, {String name = 'Jane Doe', int attempts = 0, String? lastError}) async {
    final source = File('${picker.path}/$id.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0]);
    final staged = await repository().stage(PendingUpload(
      id: id,
      opid: opid,
      patientName: name,
      files: [PendingFile(path: source.path, description: 'note-$id')],
      createdAt: DateTime.utc(2026, 9, 9),
    ));
    return staged.copyWith(attempts: attempts, lastError: lastError);
  }

  List<TomogramDraft> draftsFrom(String name, {String description = ''}) {
    final f = File('${picker.path}/$name')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0]);
    return [TomogramDraft(id: 'draft-$name', filePath: f.path, description: description)];
  }

  test('enqueue stages the picker files and persists the entry', () async {
    connectivity.online = false;
    final queue = await notifier();

    await queue.enqueue(42, 'Jane Doe', draftsFrom('a.jpg', description: 'scalp'));

    final entry = container.read(uploadQueueProvider).requireValue.single;
    expect(entry.id, 'e0');
    expect(entry.opid, 42);
    expect(entry.patientName, 'Jane Doe');
    expect(entry.attempts, 0);
    expect(entry.files.single.description, 'scalp');
    expect(entry.files.single.path, '${docs.path}/pending/e0/0.jpg');
    expect(File(entry.files.single.path).existsSync(), isTrue);
    // Persisted, so the next app run finds it.
    expect(repository().read().single.id, 'e0');
    verifyNever(() => api.upload(any(), any()));
  });

  test('enqueue while online starts a run straight away', () async {
    when(() => api.upload(any(), any())).thenAnswer((_) async => const []);
    final queue = await notifier();

    await queue.enqueue(42, 'Jane Doe', draftsFrom('a.jpg'));
    await pumpEventQueue();

    verify(() => api.upload(42, any())).called(1);
    expect(container.read(uploadQueueProvider).requireValue, isEmpty);
  });

  test('processQueue uploads oldest first, then removes the entries and their files', () async {
    connectivity.online = false;
    final queue = await notifier();
    await queue.enqueue(41, 'Older', draftsFrom('a.jpg'));
    await queue.enqueue(42, 'Newer', draftsFrom('b.jpg'));
    final staged = container.read(uploadQueueProvider).requireValue;
    when(() => api.upload(any(), any())).thenAnswer((_) async => const []);

    await queue.processQueue();

    expect(verify(() => api.upload(captureAny(), any())).captured, [41, 42]);
    expect(container.read(uploadQueueProvider).requireValue, isEmpty);
    expect(repository().read(), isEmpty);
    for (final entry in staged) {
      expect(Directory('${docs.path}/pending/${entry.id}').existsSync(), isFalse);
    }
  });

  test('queued files keep unique multipart ids and their staged paths', () async {
    connectivity.online = false;
    final queue = await notifier();
    final a = File('${picker.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0]);
    final b = File('${picker.path}/b.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0]);
    await queue.enqueue(42, 'Jane Doe', [
      TomogramDraft(id: 'd1', filePath: a.path, description: 'scalp'),
      TomogramDraft(id: 'd2', filePath: b.path, description: 'nape'),
    ]);
    when(() => api.upload(any(), any())).thenAnswer((_) async => const []);

    await queue.processQueue();

    final sent = verify(() => api.upload(42, captureAny())).captured.single as List<TomogramDraft>;
    expect(sent.map((d) => d.id), ['q0', 'q1']);
    expect(sent.map((d) => d.description), ['scalp', 'nape']);
    expect(sent.map((d) => d.filePath), [
      '${docs.path}/pending/e0/0.jpg',
      '${docs.path}/pending/e0/1.jpg',
    ]);
  });

  test('a successful upload refreshes that patient history', () async {
    connectivity.online = false;
    final queue = await notifier();
    await queue.enqueue(42, 'Jane Doe', draftsFrom('a.jpg'));
    // A live listener, so the invalidation actually refetches.
    container.listen(tomogramHistoryProvider(42), (_, __) {}, fireImmediately: true);
    await container.read(tomogramHistoryProvider(42).future);
    verify(() => history.list(42)).called(1);
    when(() => api.upload(any(), any())).thenAnswer((_) async => const []);

    await queue.processQueue();
    await container.read(tomogramHistoryProvider(42).future);

    verify(() => history.list(42)).called(1);
  });

  test('a network failure stops the run and leaves attempts untouched', () async {
    connectivity.online = false;
    final queue = await notifier();
    await queue.enqueue(41, 'Older', draftsFrom('a.jpg'));
    await queue.enqueue(42, 'Newer', draftsFrom('b.jpg'));
    when(() => api.upload(any(), any())).thenThrow(const CannotConnectFailure());

    await queue.processQueue();

    verify(() => api.upload(41, any())).called(1);
    verifyNever(() => api.upload(42, any()));
    final entries = container.read(uploadQueueProvider).requireValue;
    expect(entries.map((e) => e.id), ['e0', 'e1']);
    expect(entries.map((e) => e.attempts), [0, 0]);
    expect(entries.every((e) => e.lastError == null), isTrue);
  });

  test('a timeout also stops the run', () async {
    connectivity.online = false;
    final queue = await notifier();
    await queue.enqueue(41, 'Older', draftsFrom('a.jpg'));
    await queue.enqueue(42, 'Newer', draftsFrom('b.jpg'));
    when(() => api.upload(any(), any())).thenThrow(const TimeoutFailure());

    await queue.processQueue();

    verifyNever(() => api.upload(42, any()));
    expect(container.read(uploadQueueProvider).requireValue.length, 2);
  });

  test('a rejection counts an attempt, records the reason and moves on', () async {
    connectivity.online = false;
    final queue = await notifier();
    await queue.enqueue(41, 'Older', draftsFrom('a.jpg'));
    await queue.enqueue(42, 'Newer', draftsFrom('b.jpg'));
    when(() => api.upload(41, any())).thenThrow(const RejectedFailure('Image too large'));
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);

    await queue.processQueue();

    final entries = container.read(uploadQueueProvider).requireValue;
    expect(entries.single.id, 'e0');
    expect(entries.single.attempts, 1);
    expect(entries.single.lastError, 'Image too large');
    expect(repository().read().single.attempts, 1);
    // The rejected entry's files are kept for the retry.
    expect(File('${docs.path}/pending/e0/0.jpg').existsSync(), isTrue);
    expect(Directory('${docs.path}/pending/e1').existsSync(), isFalse);
  });

  test('a failure without a server message records the failure type', () async {
    connectivity.online = false;
    final queue = await notifier();
    await queue.enqueue(41, 'Older', draftsFrom('a.jpg'));
    when(() => api.upload(any(), any())).thenThrow(const UnauthorizedFailure());

    await queue.processQueue();

    expect(container.read(uploadQueueProvider).requireValue.single.lastError, 'UnauthorizedFailure');
  });

  test('entries at the attempt ceiling are skipped until retryAll', () async {
    final exhausted = await seed('e9', 42, attempts: maxUploadAttempts, lastError: 'Image too large');
    await repository().write([exhausted]);
    connectivity.online = false;
    final queue = await notifier();
    expect(container.read(uploadQueueProvider).requireValue.single.isFailed, isTrue);
    when(() => api.upload(any(), any())).thenAnswer((_) async => const []);

    await queue.processQueue();
    verifyNever(() => api.upload(any(), any()));

    await queue.retryAll();

    verify(() => api.upload(42, any())).called(1);
    expect(container.read(uploadQueueProvider).requireValue, isEmpty);
  });

  test('retryAll clears the previous failure before processing', () async {
    final exhausted = await seed('e9', 42, attempts: maxUploadAttempts, lastError: 'Image too large');
    await repository().write([exhausted]);
    connectivity.online = false;
    final queue = await notifier();
    when(() => api.upload(any(), any())).thenThrow(const CannotConnectFailure());

    await queue.retryAll();

    final entry = container.read(uploadQueueProvider).requireValue.single;
    expect(entry.attempts, 0);
    expect(entry.lastError, isNull);
    expect(entry.isFailed, isFalse);
  });

  test('a queue left over from an offline launch drains when the network arrives', () async {
    final pending = await seed('e9', 42);
    await repository().write([pending]);
    // Launched with no network, and the plugin reports no initial state.
    connectivity.online = false;
    final queue = await notifier();
    when(() => api.upload(any(), any())).thenThrow(const CannotConnectFailure());

    await queue.start();
    verify(() => api.upload(42, any())).called(1);
    expect(container.read(uploadQueueProvider).requireValue.length, 1);

    when(() => api.upload(any(), any())).thenAnswer((_) async => const []);
    connectivity.emit(true);
    await pumpEventQueue();

    verify(() => api.upload(42, any())).called(1);
    expect(container.read(uploadQueueProvider).requireValue, isEmpty);
  });

  test('losing the network is not a trigger', () async {
    final pending = await seed('e9', 42);
    await repository().write([pending]);
    final queue = await notifier();
    when(() => api.upload(any(), any())).thenThrow(const CannotConnectFailure());
    await queue.start();
    verify(() => api.upload(42, any())).called(1);

    connectivity.emit(false);
    await pumpEventQueue();

    verifyNever(() => api.upload(any(), any()));
  });

  test('reconnects arriving during a run do not double-upload', () async {
    final pending = await seed('e9', 42);
    await repository().write([pending]);
    connectivity.online = false;
    final queue = await notifier();
    final gate = Completer<List<UploadResult>>();
    when(() => api.upload(any(), any())).thenAnswer((_) => gate.future);

    final started = queue.start();
    await pumpEventQueue();
    connectivity.emit(true);
    connectivity.emit(true);
    await pumpEventQueue();
    gate.complete(const []);
    await started;
    await pumpEventQueue();

    verify(() => api.upload(42, any())).called(1);
    expect(container.read(uploadQueueProvider).requireValue, isEmpty);
  });

  test('an entry enqueued during a run is still uploaded by that run', () async {
    final pending = await seed('e9', 41);
    await repository().write([pending]);
    final queue = await notifier();
    final gate = Completer<List<UploadResult>>();
    when(() => api.upload(41, any())).thenAnswer((_) => gate.future);
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);

    final run = queue.processQueue();
    await pumpEventQueue();
    await queue.enqueue(42, 'Newer', draftsFrom('b.jpg'));
    gate.complete(const []);
    await run;
    await pumpEventQueue();

    verify(() => api.upload(41, any())).called(1);
    verify(() => api.upload(42, any())).called(1);
    expect(container.read(uploadQueueProvider).requireValue, isEmpty);
  });

  test('overlapping processQueue calls upload once', () async {
    final pending = await seed('e9', 42);
    await repository().write([pending]);
    connectivity.online = false;
    final queue = await notifier();
    final gate = Completer<List<UploadResult>>();
    when(() => api.upload(any(), any())).thenAnswer((_) => gate.future);

    final first = queue.processQueue();
    final second = queue.processQueue();
    expect(queue.isProcessing, isTrue);
    gate.complete(const []);
    await Future.wait([first, second]);

    verify(() => api.upload(42, any())).called(1);
    expect(queue.isProcessing, isFalse);
    expect(container.read(uploadQueueProvider).requireValue, isEmpty);
  });

  test('discard drops the entry and deletes its files', () async {
    connectivity.online = false;
    final queue = await notifier();
    await queue.enqueue(42, 'Jane Doe', draftsFrom('a.jpg'));

    await queue.discard('e0');

    expect(container.read(uploadQueueProvider).requireValue, isEmpty);
    expect(repository().read(), isEmpty);
    expect(Directory('${docs.path}/pending/e0').existsSync(), isFalse);
  });

  test('the count and per-opid lookups follow the queue', () async {
    connectivity.online = false;
    final queue = await notifier();
    expect(container.read(pendingCountProvider), 0);
    expect(container.read(pendingForOpidProvider(42)), isNull);

    await queue.enqueue(42, 'Jane Doe', draftsFrom('a.jpg'));
    await queue.enqueue(7, 'Other', draftsFrom('b.jpg'));

    expect(container.read(pendingCountProvider), 2);
    expect(container.read(pendingForOpidProvider(42))?.patientName, 'Jane Doe');
    expect(container.read(pendingForOpidProvider(99)), isNull);
  });

  test('the per-opid photo count sums every entry for that patient', () async {
    connectivity.online = false;
    final queue = await notifier();
    final a = File('${picker.path}/a.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0]);
    final b = File('${picker.path}/b.jpg')..writeAsBytesSync([0xFF, 0xD8, 0xFF, 0]);
    await queue.enqueue(42, 'Jane Doe', [
      TomogramDraft(id: 'd1', filePath: a.path, description: ''),
      TomogramDraft(id: 'd2', filePath: b.path, description: ''),
    ]);
    await queue.enqueue(42, 'Jane Doe', draftsFrom('c.jpg'));
    await queue.enqueue(7, 'Other', draftsFrom('d.jpg'));

    expect(container.read(pendingFileCountForOpidProvider(42)), 3);
    expect(container.read(pendingFileCountForOpidProvider(7)), 1);
    expect(container.read(pendingFileCountForOpidProvider(99)), 0);
  });
}
