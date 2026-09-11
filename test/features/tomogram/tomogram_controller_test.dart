import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockTomogramApi extends Mock implements TomogramApi {}

class MockTomogramHistoryApi extends Mock implements TomogramHistoryApi {}

/// A device that cannot write its prefs: reading works, remembering does not.
class ThrowingLabels extends Mock implements RecentLabelsRepository {}

void main() {
  late Directory dir;
  late MockTomogramApi api;
  late SharedPreferences prefs;
  late ProviderContainer container;
  var counter = 0;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('tomo_ctrl');
    api = MockTomogramApi();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    counter = 0;
    container = ProviderContainer(overrides: [
      tomogramApiProvider.overrideWithValue(api),
      sharedPreferencesProvider.overrideWithValue(prefs),
      uuidProvider.overrideWithValue(() => 'id${++counter}'),
    ]);
    addTearDown(container.dispose);
  });
  tearDown(() => dir.delete(recursive: true));

  File make(String name) => File('${dir.path}/$name')..writeAsBytesSync([0xFF, 0xD8, 0xFF]);

  test('addFiles, updateDescription, remove', () async {
    final a = make('a.jpg');
    final b = make('b.jpg');
    final sub = container.listen(tomogramControllerProvider(42), (_, _) {});
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

  test('addDrafts keeps the order and the descriptions it was given', () async {
    final a = make('a.jpg');
    final b = make('b.jpg');
    final sub = container.listen(tomogramControllerProvider(42), (_, _) {});
    final ctrl = container.read(tomogramControllerProvider(42).notifier);

    ctrl.addDrafts([(path: a.path, description: 'Left forearm'), (path: b.path, description: '')]);

    final drafts = container.read(tomogramControllerProvider(42)).drafts;
    expect(drafts.map((d) => d.id), ['id1', 'id2']);
    expect(drafts.map((d) => d.filePath), [a.path, b.path]);
    expect(drafts.map((d) => d.description), ['Left forearm', '']);
    sub.close();
  });

  test('addFiles is addDrafts without descriptions', () async {
    final a = make('a.jpg');
    final sub = container.listen(tomogramControllerProvider(42), (_, _) {});
    container.read(tomogramControllerProvider(42).notifier).addFiles([a.path]);
    expect(container.read(tomogramControllerProvider(42)).drafts.single.description, '');
    sub.close();
  });

  test('resolvedDrafts inherits the previous photo description forward', () async {
    final files = [for (final n in ['a', 'b', 'c', 'd', 'e']) make('$n.jpg')];
    final sub = container.listen(tomogramControllerProvider(42), (_, _) {});
    final ctrl = container.read(tomogramControllerProvider(42).notifier);
    ctrl.addDrafts([
      (path: files[0].path, description: 'Left forearm'),
      (path: files[1].path, description: ''),
      (path: files[2].path, description: '   '),
      (path: files[3].path, description: 'Back'),
      (path: files[4].path, description: ''),
    ]);

    expect(
      ctrl.resolvedDrafts.map((d) => d.description),
      ['Left forearm', 'Left forearm', 'Left forearm', 'Back', 'Back'],
    );
    // Ids and paths ride along untouched, and the stored drafts keep the blanks
    // the user can still type over.
    expect(ctrl.resolvedDrafts.map((d) => d.id), ['id1', 'id2', 'id3', 'id4', 'id5']);
    expect(ctrl.resolvedDrafts.map((d) => d.filePath), files.map((f) => f.path));
    expect(
      container.read(tomogramControllerProvider(42)).drafts.map((d) => d.description),
      ['Left forearm', '', '   ', 'Back', ''],
    );
    sub.close();
  });

  test('inheritedDescriptionFor says what a blank photo would upload with', () async {
    final files = [for (final n in ['a', 'b', 'c', 'd']) make('$n.jpg')];
    final sub = container.listen(tomogramControllerProvider(42), (_, _) {});
    final ctrl = container.read(tomogramControllerProvider(42).notifier);
    ctrl.addDrafts([
      (path: files[0].path, description: ''),
      (path: files[1].path, description: 'Left forearm'),
      (path: files[2].path, description: '   '),
      (path: files[3].path, description: 'Back'),
    ]);

    // Nothing before the first photo to inherit, and a run of blanks from it
    // inherits nothing either.
    expect(ctrl.inheritedDescriptionFor(0), isNull);
    // Its own text, so there is nothing to inherit.
    expect(ctrl.inheritedDescriptionFor(1), isNull);
    // Whitespace is blank, and what it takes is the trimmed text.
    expect(ctrl.inheritedDescriptionFor(2), 'Left forearm');
    expect(ctrl.inheritedDescriptionFor(3), isNull);
    // Out of range rather than a crash: the card and the viewer both index
    // into a list that can shrink under them.
    expect(ctrl.inheritedDescriptionFor(4), isNull);
    expect(ctrl.inheritedDescriptionFor(-1), isNull);
    sub.close();
  });

  test('resolvedDrafts posts trimmed descriptions and inherits the trimmed text', () async {
    final a = make('a.jpg');
    final b = make('b.jpg');
    final sub = container.listen(tomogramControllerProvider(42), (_, _) {});
    final ctrl = container.read(tomogramControllerProvider(42).notifier);
    ctrl.addDrafts([(path: a.path, description: 'Left forearm '), (path: b.path, description: '')]);

    expect(ctrl.resolvedDrafts.map((d) => d.description), ['Left forearm', 'Left forearm']);
    // The raw text stays in the field the user is still typing in.
    expect(container.read(tomogramControllerProvider(42)).drafts.first.description, 'Left forearm ');
    sub.close();
  });

  test('resolvedDrafts leaves a blank first photo blank', () async {
    final a = make('a.jpg');
    final b = make('b.jpg');
    final sub = container.listen(tomogramControllerProvider(42), (_, _) {});
    final ctrl = container.read(tomogramControllerProvider(42).notifier);
    ctrl.addDrafts([(path: a.path, description: ''), (path: b.path, description: 'Back')]);

    expect(ctrl.resolvedDrafts.map((d) => d.description), ['', 'Back']);
    sub.close();
  });

  test('upload sends drafts, deletes files and clears state', () async {
    final a = make('a.jpg');
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);
    final sub = container.listen(tomogramControllerProvider(42), (_, _) {});
    final c = container.read(tomogramControllerProvider(42).notifier);
    c.addFiles([a.path]);
    await c.upload();
    verify(() => api.upload(42, any(that: hasLength(1)))).called(1);
    expect(container.read(tomogramControllerProvider(42)).drafts, isEmpty);
    expect(container.read(tomogramControllerProvider(42)).uploading, isFalse);
    expect(a.existsSync(), isFalse);
    sub.close();
  });

  test('upload posts the resolved descriptions and remembers them', () async {
    final files = [for (final n in ['a', 'b', 'c', 'd', 'e']) make('$n.jpg')];
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);
    final sub = container.listen(tomogramControllerProvider(42), (_, _) {});
    final ctrl = container.read(tomogramControllerProvider(42).notifier);
    ctrl.addDrafts([
      (path: files[0].path, description: 'Left forearm'),
      (path: files[1].path, description: ''),
      (path: files[2].path, description: ''),
      (path: files[3].path, description: 'Back'),
      (path: files[4].path, description: ''),
    ]);

    await ctrl.upload();

    final posted = verify(() => api.upload(42, captureAny())).captured.single as List<TomogramDraft>;
    expect(
      posted.map((d) => d.description),
      ['Left forearm', 'Left forearm', 'Left forearm', 'Back', 'Back'],
    );
    // The set's descriptions are offered on the next patient, newest first and
    // distinct: the repository takes the first of what it is given as the most
    // recent.
    expect(container.read(recentLabelsProvider), ['Left forearm', 'Back']);
    expect(prefs.getStringList(RecentLabelsRepository.key), ['Left forearm', 'Back']);
    sub.close();
  });

  test('a prefs failure cannot fail an upload that succeeded', () async {
    final a = make('a.jpg');
    final labels = ThrowingLabels();
    final historyApi = MockTomogramHistoryApi();
    when(() => labels.read()).thenReturn(const []);
    when(() => labels.remember(any())).thenThrow(Exception('prefs are full'));
    when(() => historyApi.list(42)).thenAnswer((_) async => const []);
    when(() => api.upload(42, any())).thenAnswer((_) async => const []);
    final local = ProviderContainer(overrides: [
      tomogramApiProvider.overrideWithValue(api),
      tomogramHistoryApiProvider.overrideWithValue(historyApi),
      recentLabelsRepositoryProvider.overrideWithValue(labels),
      uuidProvider.overrideWithValue(() => 'id1'),
    ]);
    addTearDown(local.dispose);
    final historySub = local.listen(tomogramHistoryProvider(42), (_, _) {});
    final sub = local.listen(tomogramControllerProvider(42), (_, _) {});
    await local.read(tomogramHistoryProvider(42).future);
    final ctrl = local.read(tomogramControllerProvider(42).notifier);
    ctrl.addDrafts([(path: a.path, description: 'Left forearm')]);

    // The photos are on the server: everything the upload owes the user still
    // happens, and the suggestion row is the only thing that misses out.
    await ctrl.upload();

    expect(local.read(tomogramControllerProvider(42)).drafts, isEmpty);
    expect(local.read(tomogramControllerProvider(42)).uploading, isFalse);
    expect(a.existsSync(), isFalse);
    await local.read(tomogramHistoryProvider(42).future);
    verify(() => historyApi.list(42)).called(2);
    verify(() => labels.remember(any())).called(1);
    sub.close();
    historySub.close();
  });

  test('upload failure keeps drafts and files and rethrows', () async {
    final a = make('a.jpg');
    when(() => api.upload(any(), any())).thenThrow(const TimeoutFailure());
    final sub = container.listen(tomogramControllerProvider(42), (_, _) {});
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
    final sub = container.listen(tomogramControllerProvider(1), (_, _) {});
    final c = container.read(tomogramControllerProvider(1).notifier);
    c.addFiles([a.path]);
    await c.clearAll();
    expect(container.read(tomogramControllerProvider(1)).drafts, isEmpty);
    expect(a.existsSync(), isFalse);
    sub.close();
  });
}
