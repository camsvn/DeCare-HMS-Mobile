import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory root;
  late SharedPreferences prefs;
  late PendingUploadsRepository repo;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('pending_repo');
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    repo = PendingUploadsRepository(prefs, root);
  });
  tearDown(() => root.delete(recursive: true));

  File jpeg(String name, List<int> bytes) => File('${root.path}/$name')..writeAsBytesSync(bytes);

  test('an empty store reads as no entries', () {
    expect(repo.read(), isEmpty);
  });

  test('write then read round trips every field', () async {
    final entry = PendingUpload(
      id: 'e1',
      opid: 42,
      patientName: 'Jane Doe',
      files: const [
        PendingFile(path: '/pending/e1/0.jpg', description: 'scalp'),
        PendingFile(path: '/pending/e1/1.jpg', description: ''),
      ],
      createdAt: DateTime.utc(2026, 9, 9, 10, 30),
      attempts: 2,
      lastError: 'Request rejected',
    );
    await repo.write([entry]);

    final back = repo.read().single;
    expect(back.id, 'e1');
    expect(back.opid, 42);
    expect(back.patientName, 'Jane Doe');
    expect(back.createdAt, DateTime.utc(2026, 9, 9, 10, 30));
    expect(back.attempts, 2);
    expect(back.lastError, 'Request rejected');
    expect(back.files.map((f) => f.path), ['/pending/e1/0.jpg', '/pending/e1/1.jpg']);
    expect(back.files.map((f) => f.description), ['scalp', '']);
    expect(back.isFailed, isFalse);
  });

  test('an entry is failed once it reaches the attempt ceiling', () {
    final entry = PendingUpload(
      id: 'e1',
      opid: 1,
      patientName: 'Jo',
      files: const [],
      createdAt: DateTime.utc(2026),
    );
    expect(maxUploadAttempts, 5);
    expect(entry.copyWith(attempts: maxUploadAttempts - 1).isFailed, isFalse);
    expect(entry.copyWith(attempts: maxUploadAttempts).isFailed, isTrue);
  });

  test('a corrupt store reads as no entries instead of throwing', () async {
    await prefs.setString('pending_uploads', 'not json at all');
    expect(repo.read(), isEmpty);
  });

  test('stage copies each file into the entry folder and returns the new paths', () async {
    final a = jpeg('a.jpg', [0xFF, 0xD8, 0xFF, 1]);
    final b = jpeg('b.jpg', [0xFF, 0xD8, 0xFF, 2]);
    final staged = await repo.stage(PendingUpload(
      id: 'e1',
      opid: 7,
      patientName: 'Jo',
      files: [
        PendingFile(path: a.path, description: 'one'),
        PendingFile(path: b.path, description: 'two'),
      ],
      createdAt: DateTime.utc(2026),
    ));

    expect(staged.files.map((f) => f.path), [
      '${root.path}/pending/e1/0.jpg',
      '${root.path}/pending/e1/1.jpg',
    ]);
    expect(staged.files.map((f) => f.description), ['one', 'two']);
    expect(File(staged.files.first.path).readAsBytesSync(), [0xFF, 0xD8, 0xFF, 1]);
    expect(File(staged.files.last.path).readAsBytesSync(), [0xFF, 0xD8, 0xFF, 2]);
    // The picker originals are copies, not moves: the drafts still own them.
    expect(a.existsSync(), isTrue);
    expect(b.existsSync(), isTrue);
    expect(staged.id, 'e1');
    expect(staged.opid, 7);
  });

  test('purge deletes the entry folder and tolerates a missing one', () async {
    final a = jpeg('a.jpg', [0xFF, 0xD8, 0xFF, 1]);
    final staged = await repo.stage(PendingUpload(
      id: 'e1',
      opid: 7,
      patientName: 'Jo',
      files: [PendingFile(path: a.path, description: '')],
      createdAt: DateTime.utc(2026),
    ));
    expect(File(staged.files.single.path).existsSync(), isTrue);

    await repo.purge(staged);
    expect(Directory('${root.path}/pending/e1').existsSync(), isFalse);
    expect(File(staged.files.single.path).existsSync(), isFalse);

    await expectLater(repo.purge(staged), completes);
  });

  test('a copy that fails part-way leaves no half-staged folder behind', () async {
    final a = jpeg('a.jpg', [0xFF, 0xD8, 0xFF, 1]);
    await expectLater(
      repo.stage(PendingUpload(
        id: 'e1',
        opid: 7,
        patientName: 'Jo',
        files: [
          PendingFile(path: a.path, description: 'one'),
          PendingFile(path: '${root.path}/gone.jpg', description: 'two'),
        ],
        createdAt: DateTime.utc(2026),
      )),
      throwsA(isA<FileSystemException>()),
    );

    expect(Directory('${root.path}/pending/e1').existsSync(), isFalse);
  });
}
