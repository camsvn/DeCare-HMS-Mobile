import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/tomogram/application/jpeg_orientation.dart';

/// The slice of `package:camera` the capture screen needs, behind an interface
/// so the session controller and the screen can be tested without a platform
/// channel. Back camera, portrait, stills only.
abstract class CameraService {
  /// True once [start] has initialised a camera and [takePicture] can be used.
  bool get isReady;

  /// Width / height of the preview *as displayed*, which is not the sensor's
  /// own ratio: a portrait preview shows a landscape sensor on its side. 1
  /// until the camera is ready, so a layout built before initialisation still
  /// gets a usable number.
  double get previewAspectRatio;

  /// Opens the back camera. Throws when there is no usable camera.
  Future<void> start();

  /// Releases the device. A later [start] re-opens it.
  Future<void> stop();

  /// The live preview, or `SizedBox.shrink()` before the camera is ready.
  Widget preview();

  /// Captures one still and returns its JPEG path in app-private storage.
  ///
  /// The file may still be post-processed in the background when this returns,
  /// so a burst is not held up by the shot before it. [flush] is how a caller
  /// waits for that to be done.
  Future<String> takePicture();

  /// Waits for the background post-processing of every shot taken so far.
  /// Call it before handing the paths on — or before deleting them.
  Future<void> flush();

  Future<void> setTorch(bool on);

  /// Focuses (and meters exposure) at [normalized], 0..1 in preview
  /// coordinates. A no-op on devices without tap-to-focus.
  Future<void> focusAt(Offset normalized);
}

/// What [CameraPreview] lays a [sensorRatio] out as when the preview is shown
/// at [orientation].
///
/// The sensor reports width / height in its own landscape frame, but
/// `CameraPreview` builds `AspectRatio(1 / aspectRatio)` unless the applicable
/// orientation is landscape (see its `_getApplicableOrientation`). A caller
/// sizing a box for the preview needs the ratio the preview will actually be,
/// or the texture is forced into a transposed box.
@visibleForTesting
double displayedAspectRatio(double sensorRatio, DeviceOrientation orientation) {
  final landscape =
      orientation == DeviceOrientation.landscapeLeft || orientation == DeviceOrientation.landscapeRight;
  return landscape ? sensorRatio : 1 / sensorRatio;
}

/// [CameraService] on `package:camera`.
///
/// Not unit-tested: every call here is a platform channel. It stays thin, and
/// the optional device features go through [_tryOptional] so an emulator or a
/// device without torch or tap-to-focus never fails the capture screen.
class PluginCameraService implements CameraService {
  CameraController? _controller;

  /// Bumped by every [start] and every [stop]. A [start] that is overtaken —
  /// by a [stop] or by another [start] — sees its generation go stale and
  /// disposes the controller it opened instead of publishing it. Without it a
  /// screen popped or backgrounded during the (slow) cold start leaves an
  /// initialised camera nobody holds a reference to: [stop] clears
  /// `_controller` before `start` ever assigns it.
  int _generation = 0;

  /// The orientation bakes still running, one per shot taken. Tracked so
  /// [flush] can wait for them; each removes itself when it is done.
  final Set<Future<void>> _baking = {};

  @override
  bool get isReady => _controller?.value.isInitialized ?? false;

  @override
  double get previewAspectRatio {
    if (!isReady) return 1;
    final value = _controller!.value;
    // `previewPauseOrientation` is not consulted: this service never pauses
    // the preview, so it is always null here.
    return displayedAspectRatio(
      value.aspectRatio,
      value.lockedCaptureOrientation ?? value.deviceOrientation,
    );
  }

  /// A failed `initialize` disposes its controller before the error leaves, so
  /// a retry is not met with "camera in use" by the half-open one it left.
  @override
  Future<void> start() async {
    if (isReady) return;
    final gen = ++_generation;
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw StateError('No camera');
    final back = cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );
    // veryHigh is 1080p: the long edge is at most 1920 px, so captures already
    // satisfy the 2000 px rule the picker applies and need no re-encoding.
    final controller = CameraController(
      back,
      ResolutionPreset.veryHigh,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.jpeg,
    );
    try {
      await controller.initialize();
    } catch (_) {
      await controller.dispose();
      rethrow;
    }
    if (gen != _generation) {
      await controller.dispose();
      return;
    }
    await _tryOptional(() => controller.lockCaptureOrientation(DeviceOrientation.portraitUp));
    if (gen != _generation) {
      await controller.dispose();
      return;
    }
    _controller = controller;
  }

  @override
  Future<void> stop() async {
    // Bumped before anything else, so a `start` still inside `initialize`
    // disposes what it opened rather than publishing it after this returns.
    _generation++;
    final controller = _controller;
    // Cleared first: `isReady` must be false for the whole of `dispose`.
    _controller = null;
    await controller?.dispose();
  }

  @override
  Widget preview() => isReady ? CameraPreview(_controller!) : const SizedBox.shrink();

  /// Returns as soon as the plugin has written the file: the orientation bake
  /// runs behind it, so a burst is one tap per photo rather than one tap per
  /// re-encode. [flush] joins the two back up.
  @override
  Future<String> takePicture() async {
    final path = (await _controller!.takePicture()).path;
    late final Future<void> baking;
    baking = bakeJpegOrientation(path).catchError((Object error) {
      // Swallowed on purpose: the plugin's own file is still on disk, and
      // uploading a sideways photo beats losing the photo. Reported in debug
      // only — there is nothing the user could do about it.
      assert(() {
        debugPrint('bakeJpegOrientation failed for $path: $error');
        return true;
      }());
    }).whenComplete(() => _baking.remove(baking));
    _baking.add(baking);
    return path;
  }

  /// Every tracked bake has already swallowed its own failure, so this waits
  /// without ever throwing. The copy matters: they remove themselves as they
  /// complete.
  @override
  Future<void> flush() => Future.wait(_baking.toList());

  // The controller is captured before the optional call in both of these: a
  // `stop` racing in nulls the field, and `_controller!` would then throw a
  // `TypeError`, which `_tryOptional` does not (and should not) swallow.
  @override
  Future<void> setTorch(bool on) async {
    final controller = _controller;
    if (controller == null) return;
    await _tryOptional(() => controller.setFlashMode(on ? FlashMode.torch : FlashMode.off));
  }

  @override
  Future<void> focusAt(Offset normalized) async {
    final controller = _controller;
    if (controller == null) return;
    // Outside 0..1 the plugin throws `ArgumentError`, which is a programming
    // error `_tryOptional` deliberately does not swallow: clamp instead of
    // trusting the caller's hit-test arithmetic.
    final point = Offset(normalized.dx.clamp(0.0, 1.0), normalized.dy.clamp(0.0, 1.0));
    await _tryOptional(() => controller.setFocusPoint(point));
    await _tryOptional(() => controller.setExposurePoint(point));
  }

  /// Runs a call the device may not support. Only the plugin's "cannot do
  /// that here" errors are swallowed; anything else still escapes.
  Future<void> _tryOptional(Future<void> Function() call) async {
    try {
      await call();
    } on CameraException catch (_) {
      // ignore: optional device feature
    } on UnimplementedError catch (_) {
      // ignore: not implemented on this platform
    } on UnsupportedError catch (_) {
      // ignore: unsupported by this camera
    }
  }
}

/// One camera per capture screen: `autoDispose` releases the device as soon as
/// the screen is gone, so the OS camera app (and the next screen) can have it.
final cameraServiceProvider = Provider.autoDispose<CameraService>((ref) {
  final service = PluginCameraService();
  // Fire and forget, but never unhandled: a platform error while handing the
  // device back must not escape a dispose callback into the zone handler.
  ref.onDispose(() => unawaited(service.stop().catchError((Object _) {})));
  return service;
});
