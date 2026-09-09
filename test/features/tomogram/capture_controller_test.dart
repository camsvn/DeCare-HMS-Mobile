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

    final taken = await capture().takeAll();

    expect(taken, ['${dir.path}/shot_0.jpg', '${dir.path}/shot_1.jpg']);
    expect(state().shots, isEmpty);
    expect(taken.every((p) => File(p).existsSync()), isTrue);
    expect(fake.flushCount, 1);
  });

  // The camera rewrites each shot's orientation in the background, so what is
  // on disk when `takePicture` returns is not yet what should be uploaded.
  test('takeAll waits for the shots to finish post-processing', () async {
    await capture().start();
    await capture().shoot();
    fake.flushGate = Completer<void>();

    var handed = false;
    final taken = capture().takeAll().then((paths) {
      handed = true;
      return paths;
    });
    await pumpEventQueue();

    expect(handed, isFalse);
    expect(fake.flushCount, 1);
    expect(state().shots, hasLength(1));

    fake.flushGate!.complete();

    expect(await taken, ['${dir.path}/shot_0.jpg']);
    expect(state().shots, isEmpty);
  });

  test('a flush that fails still hands the shots over', () async {
    await capture().start();
    await capture().shoot();
    fake.failFlush = true;

    expect(await capture().takeAll(), ['${dir.path}/shot_0.jpg']);
    expect(File('${dir.path}/shot_0.jpg').existsSync(), isTrue);
  });

  // Deleting under a rename would either resurrect the file or leave the
  // bake's `.tmp` sibling behind.
  test('remove waits for the post-processing before deleting', () async {
    await capture().start();
    await capture().shoot();
    final path = state().shots.single;
    fake.flushGate = Completer<void>();

    final removing = capture().remove(path);
    await pumpEventQueue();

    expect(fake.flushCount, 1);
    expect(File(path).existsSync(), isTrue);

    fake.flushGate!.complete();
    await removing;

    expect(File(path).existsSync(), isFalse);
    expect(state().shots, isEmpty);
  });

  test('discardAll waits for the post-processing before deleting', () async {
    await capture().start();
    await capture().shoot();
    final path = state().shots.single;
    fake.flushGate = Completer<void>();

    final discarding = capture().discardAll();
    await pumpEventQueue();

    expect(fake.flushCount, 1);
    expect(File(path).existsSync(), isTrue);

    fake.flushGate!.complete();
    await discarding;

    expect(filesOnDisk(), isEmpty);
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

  test('stop releases the camera and keeps the shots', () async {
    await capture().start();
    await capture().shoot();
    await capture().toggleTorch();
    final shots = state().shots;

    await capture().stop();

    expect(state().status, CaptureStatus.starting);
    expect(state().torch, isFalse);
    expect(fake.stopCount, 1);
    expect(state().shots, shots);
    expect(shots.every((p) => File(p).existsSync()), isTrue);
  });

  // The cold start is slow (`availableCameras` then `initialize`), and both the
  // back gesture and a background can land inside it. Whoever gets there first
  // wins: the start that finishes afterwards must not leave a live camera
  // behind, nor a session that thinks it can shoot.
  test('a start still in flight when the session is disposed leaves no camera open', () async {
    // Its own container: `overrideWithValue` replaces the provider's body, and
    // with it the `onDispose` that hands the device back, so the release this
    // test is about would never happen. The override mirrors that body.
    final popped = ProviderContainer(overrides: [
      cameraServiceProvider.overrideWith((ref) {
        ref.onDispose(() => unawaited(fake.stop().catchError((Object _) {})));
        return fake;
      }),
    ]);
    popped.listen(captureControllerProvider, (_, __) {});
    fake.startGate = Completer<void>();
    final pending = popped.read(captureControllerProvider.notifier).start();

    popped.dispose();
    fake.startGate!.complete();
    await pending;

    expect(fake.isReady, isFalse);
    expect(fake.stopCount, 1);
  });

  test('a start cancelled by a stop does not ready the session', () async {
    fake.startGate = Completer<void>();
    final pending = capture().start();

    await capture().stop();
    fake.startGate!.complete();
    await pending;

    expect(fake.isReady, isFalse);
    expect(state().status, isNot(CaptureStatus.ready));
    expect(state().canShoot, isFalse);
  });

  test('the torch is ignored while the camera is not ready', () async {
    await capture().toggleTorch();

    expect(state().torch, isFalse);
    expect(fake.torchCalls, isEmpty);
  });

  test('focus is forwarded only while the camera is ready', () async {
    await capture().start();

    await capture().focusAt(const Offset(0.25, 0.75));

    expect(fake.focusCalls, [const Offset(0.25, 0.75)]);

    await capture().stop();
    await capture().focusAt(const Offset(0.5, 0.5));

    expect(fake.focusCalls, [const Offset(0.25, 0.75)]);
  });

  test('the session holds one camera for its whole life', () async {
    var created = 0;
    var disposed = 0;
    final linked = ProviderContainer(overrides: [
      cameraServiceProvider.overrideWith((ref) {
        created++;
        ref.onDispose(() => disposed++);
        return FakeCameraService(dir: dir);
      }),
    ]);
    addTearDown(linked.dispose);
    linked.listen(captureControllerProvider, (_, __) {});
    final session = linked.read(captureControllerProvider.notifier);

    // `pump` lets Riverpod run its pending auto-dispose pass between calls,
    // as a frame does in the app: a provider merely `read` by the session
    // (never watched) has no listener and would be torn down here.
    await session.start();
    await linked.pump();
    await session.shoot();
    await linked.pump();
    await session.shoot();
    await session.toggleTorch();
    await linked.pump();

    // The camera is a device, not a value: it must not be rebuilt (and the
    // live one stopped) mid-session.
    expect(created, 1);
    expect(disposed, 0);

    linked.dispose();

    expect(disposed, 1);
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
