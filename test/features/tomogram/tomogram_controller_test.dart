import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';

class MockTomogramApi extends Mock implements TomogramApi {}

void main() {
  late Directory dir;
  late MockTomogramApi api;
  late ProviderContainer container;
  var counter = 0;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tomo_ctrl');
    api = MockTomogramApi();
    counter = 0;
    container = ProviderContainer(overrides: [
      tomogramApiProvider.overrideWithValue(api),
      uuidProvider.overrideWithValue(() => 'id${++counter}'),
    ]);
    addTearDown(container.dispose);
  });
  tearDown(() => dir.delete(recursive: true));

  File make(String name) => File('${dir.path}/$name')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

  test('addFiles, updateDescription, remove', () async {
    final a = make('a.jpg');
    final b = make('b.jpg');
    final sub = container.listen(tomogramControllerProvider(42), (_, __) {});
    final c = container.read(tomogramControllerProvider(42).notifier);
    c.addFiles([a.path, b.path]);
    expect(container.read(tomogramControllerProvider(42)).drafts.map((d) => d.id), ['id1', 'id2']);
    c.updateDescription('id1', 'left');
    expect(container.read(tomogramControllerProvider(42)).drafts.first.description, 'left');
    await c.remove('id1');
    expect(container.read(tomogramControllerProvider(42)).drafts.map((d) => d.id), ['id2']);
    expect(a.existsSync(), isFalse);
    expect(b.existsSync(), isTrue);
    sub.close();
  });

  test('upload sends drafts, deletes files and clears state', () async {
    final a = make('a.jpg');
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);
    final sub = container.listen(tomogramControllerProvider(42), (_, __) {});
    final c = container.read(tomogramControllerProvider(42).notifier);
    c.addFiles([a.path]);
    await c.upload();
    verify(() => api.upload(42, any(that: hasLength(1)))).called(1);
    expect(container.read(tomogramControllerProvider(42)).drafts, isEmpty);
    expect(container.read(tomogramControllerProvider(42)).uploading, isFalse);
    expect(a.existsSync(), isFalse);
    sub.close();
  });

  test('upload failure keeps drafts and files and rethrows', () async {
    final a = make('a.jpg');
    when(() => api.upload(any(), any())).thenThrow(const TimeoutFailure());
    final sub = container.listen(tomogramControllerProvider(42), (_, __) {});
    final c = container.read(tomogramControllerProvider(42).notifier);
    c.addFiles([a.path]);
    await expectLater(c.upload(), throwsA(isA<TimeoutFailure>()));
    expect(container.read(tomogramControllerProvider(42)).drafts, hasLength(1));
    expect(container.read(tomogramControllerProvider(42)).uploading, isFalse);
    expect(a.existsSync(), isTrue);
    sub.close();
  });

  test('clearAll deletes files', () async {
    final a = make('a.jpg');
    final sub = container.listen(tomogramControllerProvider(1), (_, __) {});
    final c = container.read(tomogramControllerProvider(1).notifier);
    c.addFiles([a.path]);
    await c.clearAll();
    expect(container.read(tomogramControllerProvider(1)).drafts, isEmpty);
    expect(a.existsSync(), isFalse);
    sub.close();
  });
}
