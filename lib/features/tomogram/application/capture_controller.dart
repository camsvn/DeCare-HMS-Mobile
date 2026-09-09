import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/utils/temp_files.dart';
import 'package:hms_uploader/features/tomogram/application/camera_service.dart';
import 'package:hms_uploader/features/tomogram/application/jpeg_orientation.dart';

/// Photos one capture session may hold. A tomogram series is a handful of
/// angles; the cap keeps a stuck shutter finger from filling the cache.
const int captureLimit = 20;

enum CaptureStatus { starting, ready, failed }

class CaptureState {
  const CaptureState({
    this.status = CaptureStatus.starting,
    this.shots = const [],
    this.busy = false,
    this.torch = false,
  });

  final CaptureStatus status;

  /// Captured JPEG paths, in capture order.
  final List<String> shots;

  /// A `takePicture` is in flight, so the shutter is disabled.
  final bool busy;

  final bool torch;

  bool get atLimit => shots.length >= captureLimit;

  bool get canShoot => status == CaptureStatus.ready && !busy && !atLimit;

  CaptureState copyWith({CaptureStatus? status, List<String>? shots, bool? busy, bool? torch}) => CaptureState(
        status: status ?? this.status,
        shots: shots ?? this.shots,
        busy: busy ?? this.busy,
        torch: torch ?? this.torch,
      );
}

/// The capture screen's session: the camera's lifecycle plus the shots taken
/// so far. Files the session still owns when it is disposed are deleted,
/// mirroring `TomogramController`, so a screen closed by the back gesture or a
/// route change does not leave photos in the cache.
class CaptureController extends AutoDisposeNotifier<CaptureState> {
  /// Resolved once, in [build]. Reading `cameraServiceProvider` per call would
  /// not do: `read` on an `autoDispose` provider that nothing listens to
  /// schedules its disposal, so mid-session the app would build a second
  /// `PluginCameraService` and stop the one holding the device.
  late CameraService _camera;

  @override
  CaptureState build() {
    _camera = ref.watch(cameraServiceProvider);
    ref.onDispose(() {
      final paths = state.shots;
      // Best effort and synchronous: a dispose callback cannot wait for the
      // camera's background post-processing, so a bake still in flight may
      // leave its `.tmp` sibling behind. Both names go, and `deleteFiles`
      // shrugs at the ones that are not there.
      if (paths.isNotEmpty) deleteFiles(_withTempSiblings(paths));
    });
    return const CaptureState();
  }

  /// Opens the camera. A failure is reported as [CaptureStatus.failed] rather
  /// than thrown: the screen offers a retry, which is another [start].
  Future<void> start() async {
    state = state.copyWith(status: CaptureStatus.starting);
    try {
      await _camera.start();
      // Readiness comes from the camera, not from "the call returned": a
      // `stop` racing into a cold start cancels it, and the session must not
      // then offer a shutter for a device that is closed.
      state = state.copyWith(
        status: _camera.isReady ? CaptureStatus.ready : CaptureStatus.starting,
      );
    } catch (_) {
      state = state.copyWith(status: CaptureStatus.failed);
    }
  }

  /// Releases the camera while keeping the shots, for the screen going into
  /// the background. Back to [CaptureStatus.starting]: nothing can be shot
  /// until a [start] re-opens the device, and the torch is off with it.
  Future<void> stop() async {
    state = state.copyWith(status: CaptureStatus.starting, torch: false);
    try {
      await _camera.stop();
    } catch (_) {
      // ignore: the device is being handed back; there is nothing to recover
      // and nothing the screen could tell the user to do about it.
    }
  }

  /// Takes one photo. Returns false when the session cannot shoot (not ready,
  /// already shooting, at the limit) or the capture failed, in which case the
  /// shot list is untouched.
  Future<bool> shoot() async {
    if (!state.canShoot) return false;
    state = state.copyWith(busy: true);
    try {
      final path = await _camera.takePicture();
      state = state.copyWith(shots: [...state.shots, path], busy: false);
      return true;
    } catch (_) {
      state = state.copyWith(busy: false);
      return false;
    }
  }

  /// Drops one shot and deletes its file. Only the first match goes, so the
  /// list and the one deleted file stay in step.
  Future<void> remove(String path) async {
    final shots = List<String>.of(state.shots);
    final index = shots.indexOf(path);
    if (index < 0) return;
    shots.removeAt(index);
    state = state.copyWith(shots: shots);
    // The camera may still be rewriting this file: deleting it out from under
    // a rename would either bring it back or leave the `.tmp` sibling behind.
    await _flush();
    await deleteFiles(_withTempSiblings([path]));
  }

  /// Ignored until the camera is ready: there is no device to light up, and
  /// the state must not claim a torch that is off.
  Future<void> toggleTorch() async {
    if (state.status != CaptureStatus.ready) return;
    final on = !state.torch;
    state = state.copyWith(torch: on);
    await _camera.setTorch(on);
  }

  /// Ignored until the camera is ready, for the same reason as [toggleTorch].
  Future<void> focusAt(Offset normalized) async {
    if (state.status != CaptureStatus.ready) return;
    await _camera.focusAt(normalized);
  }

  /// Abandons the session: every shot's file is deleted.
  Future<void> discardAll() async {
    final paths = state.shots;
    state = state.copyWith(shots: const []);
    await _flush();
    await deleteFiles(_withTempSiblings(paths));
  }

  /// Hands the shots to the caller and forgets them. The files are kept: the
  /// draft list owns them from here on.
  ///
  /// Waits for the camera's background post-processing first, so what is
  /// handed over is the finished JPEG and not one mid-rewrite. The shots stay
  /// in the state until then, so the screen can show that it is finishing.
  Future<List<String>> takeAll() async {
    final paths = List<String>.of(state.shots);
    await _flush();
    state = state.copyWith(shots: const []);
    return paths;
  }

  /// Waits for the camera's background post-processing, ignoring a failure.
  /// Every caller has something better to do with one than report it: hand the
  /// shots over anyway (losing a photo is worse than uploading it unrotated)
  /// or delete them anyway.
  Future<void> _flush() async {
    try {
      await _camera.flush();
    } catch (_) {
      // ignore: whatever is on disk is either the rewritten JPEG or the
      // original, and both are a photo the user took.
    }
  }

  /// [paths] plus the sibling each one's rewrite would have been written to,
  /// so a bake that died mid-write leaves nothing in the cache.
  static List<String> _withTempSiblings(Iterable<String> paths) =>
      [...paths, ...paths.map((p) => '$p$jpegBakeTmpSuffix')];
}

final captureControllerProvider =
    NotifierProvider.autoDispose<CaptureController, CaptureState>(CaptureController.new);
