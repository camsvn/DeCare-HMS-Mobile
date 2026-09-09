import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/utils/temp_files.dart';
import 'package:hms_uploader/features/tomogram/application/camera_service.dart';

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
  @override
  CaptureState build() {
    ref.onDispose(() {
      final paths = state.shots;
      if (paths.isNotEmpty) deleteFiles(paths);
    });
    return const CaptureState();
  }

  CameraService get _camera => ref.read(cameraServiceProvider);

  /// Opens the camera. A failure is reported as [CaptureStatus.failed] rather
  /// than thrown: the screen offers a retry, which is another [start].
  Future<void> start() async {
    state = state.copyWith(status: CaptureStatus.starting);
    try {
      await _camera.start();
      state = state.copyWith(status: CaptureStatus.ready);
    } catch (_) {
      state = state.copyWith(status: CaptureStatus.failed);
    }
  }

  /// Releases the camera while keeping the shots, for the screen going into
  /// the background. Back to [CaptureStatus.starting]: nothing can be shot
  /// until a [start] re-opens the device, and the torch is off with it.
  Future<void> stop() async {
    state = state.copyWith(status: CaptureStatus.starting, torch: false);
    await _camera.stop();
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

  /// Drops one shot and deletes its file.
  Future<void> remove(String path) async {
    state = state.copyWith(shots: state.shots.where((p) => p != path).toList());
    await deleteFiles([path]);
  }

  Future<void> toggleTorch() async {
    final on = !state.torch;
    state = state.copyWith(torch: on);
    await _camera.setTorch(on);
  }

  Future<void> focusAt(Offset normalized) => _camera.focusAt(normalized);

  /// Abandons the session: every shot's file is deleted.
  Future<void> discardAll() async {
    final paths = state.shots;
    state = state.copyWith(shots: const []);
    await deleteFiles(paths);
  }

  /// Hands the shots to the caller and forgets them. The files are kept: the
  /// draft list owns them from here on.
  List<String> takeAll() {
    final paths = List<String>.of(state.shots);
    state = state.copyWith(shots: const []);
    return paths;
  }
}

final captureControllerProvider =
    NotifierProvider.autoDispose<CaptureController, CaptureState>(CaptureController.new);
