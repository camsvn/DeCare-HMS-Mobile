import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

import '../../helpers/fake_camera_service.dart';

void main() {
  late Directory dir;
  late FakeCameraService fake;
  late ProviderContainer container;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('capture');
    fake = FakeCameraService(dir: dir);
    container = ProviderContainer(overrides: [cameraServiceProvider.overrideWithValue(fake)]);
    addTearDown(container.dispose);
    // The controller is autoDispose: a listener keeps it alive across reads.
    container.listen(captureControllerProvider, (_, __) {});
  });

  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  CaptureController capture() => container.read(captureControllerProvider.notifier);
  CaptureState state() => container.read(captureControllerProvider);

  /// The stub JPEGs still on disk, in name order (`shot_0`, `shot_1`, ...).
  List<String> filesOnDisk() =>
      (dir.listSync().whereType<File>().map((f) => f.path).toList()..sort());

  test('start readies the camera', () async {
    await capture().start();

    expect(state().status, CaptureStatus.ready);
    expect(fake.startCount, 1);
  });

  test('a failed start can be retried', () async {
    fake.failStart = true;

    await capture().start();

    expect(state().status, CaptureStatus.failed);

    fake.failStart = false;
    await capture().start();

    expect(state().status, CaptureStatus.ready);
    expect(fake.startCount, 2);
  });

  test('shoot appends the captured files in order', () async {
    await capture().start();

    expect(await capture().shoot(), isTrue);
    expect(await capture().shoot(), isTrue);

    final shots = state().shots;
    expect(shots, ['${dir.path}/shot_0.jpg', '${dir.path}/shot_1.jpg']);
    expect(shots.every((p) => File(p).existsSync()), isTrue);
    expect(state().busy, isFalse);
  });

  test('shoot before start does nothing', () async {
    expect(await capture().shoot(), isFalse);

    expect(state().shots, isEmpty);
    expect(filesOnDisk(), isEmpty);
  });

  test('shoot while a capture is in flight is ignored', () async {
    await capture().start();
    fake.gate = Completer<void>();

    final first = capture().shoot();
    expect(state().busy, isTrue);
    expect(await capture().shoot(), isFalse);

    fake.gate!.complete();
    expect(await first, isTrue);

    expect(state().shots.length, 1);
    expect(filesOnDisk().length, 1);
    expect(state().busy, isFalse);
  });

  test('shoot stops at the capture limit', () async {
    await capture().start();
    for (var i = 0; i < captureLimit; i++) {
      expect(await capture().shoot(), isTrue);
    }

    expect(state().shots.length, captureLimit);
    expect(state().atLimit, isTrue);
    expect(state().canShoot, isFalse);
    expect(await capture().shoot(), isFalse);
    expect(state().shots.length, captureLimit);
  });

  test('a failed capture leaves the session untouched', () async {
    await capture().start();
    await capture().shoot();
    fake.failCapture = true;

    expect(await capture().shoot(), isFalse);

    expect(state().shots.length, 1);
    expect(state().busy, isFalse);
    expect(state().status, CaptureStatus.ready);
  });

  test('remove deletes only that shot', () async {
    await capture().start();
    await capture().shoot();
    await capture().shoot();
    final shots = state().shots;

    await capture().remove(shots.first);

    expect(state().shots, [shots.last]);
    expect(File(shots.first).existsSync(), isFalse);
    expect(File(shots.last).existsSync(), isTrue);
  });

  test('discardAll deletes every shot', () async {
    await capture().start();
    await capture().shoot();
    await capture().shoot();
    final shots = state().shots;

    await capture().discardAll();

    expect(state().shots, isEmpty);
    expect(shots.any((p) => File(p).existsSync()), isFalse);
    expect(filesOnDisk(), isEmpty);
  });

  test('takeAll hands the paths over and keeps the files', () async {
    await capture().start();
    await capture().shoot();
    await capture().shoot();

    final taken = capture().takeAll();

    expect(taken, ['${dir.path}/shot_0.jpg', '${dir.path}/shot_1.jpg']);
    expect(state().shots, isEmpty);
    expect(taken.every((p) => File(p).existsSync()), isTrue);
  });

  test('dispose deletes the shots the session still owns', () async {
    await capture().start();
    await capture().shoot();
    await capture().shoot();
    final shots = state().shots;
    expect(shots.every((p) => File(p).existsSync()), isTrue);

    container.dispose();

    expect(shots.any((p) => File(p).existsSync()), isFalse);
  });

  test('toggleTorch flips the torch and forwards it', () async {
    await capture().start();

    await capture().toggleTorch();

    expect(state().torch, isTrue);
    expect(fake.torchCalls, [true]);

    await capture().toggleTorch();

    expect(state().torch, isFalse);
    expect(fake.torchCalls, [true, false]);
  });
}
