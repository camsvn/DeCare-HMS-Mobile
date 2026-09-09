import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The slice of `package:camera` the capture screen needs, behind an interface
/// so the session controller and the screen can be tested without a platform
/// channel. Back camera, portrait, stills only.
abstract class CameraService {
  /// True once [start] has initialised a camera and [takePicture] can be used.
  bool get isReady;

  /// Preview width / height. 1 until the camera is ready, so a layout built
  /// before initialisation still gets a usable number.
  double get previewAspectRatio;

  /// Opens the back camera. Throws when there is no usable camera.
  Future<void> start();

  /// Releases the device. A later [start] re-opens it.
  Future<void> stop();

  /// The live preview, or `SizedBox.shrink()` before the camera is ready.
  Widget preview();

  /// Captures one still and returns its JPEG path in app-private storage.
  Future<String> takePicture();

  Future<void> setTorch(bool on);

  /// Focuses (and meters exposure) at [normalized], 0..1 in preview
  /// coordinates. A no-op on devices without tap-to-focus.
  Future<void> focusAt(Offset normalized);
}

/// [CameraService] on `package:camera`.
///
/// Not unit-tested: every call here is a platform channel. It stays thin, and
/// the optional device features go through [_tryOptional] so an emulator or a
/// device without torch or tap-to-focus never fails the capture screen.
class PluginCameraService implements CameraService {
  CameraController? _controller;

  @override
  bool get isReady => _controller?.value.isInitialized ?? false;

  @override
  double get previewAspectRatio => isReady ? _controller!.value.aspectRatio : 1;

  @override
  Future<void> start() async {
    if (isReady) return;
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
    await controller.initialize();
    await _tryOptional(() => controller.lockCaptureOrientation(DeviceOrientation.portraitUp));
    _controller = controller;
  }

  @override
  Future<void> stop() async {
    final controller = _controller;
    // Cleared first: `isReady` must be false for the whole of `dispose`.
    _controller = null;
    await controller?.dispose();
  }

  @override
  Widget preview() => isReady ? CameraPreview(_controller!) : const SizedBox.shrink();

  @override
  Future<String> takePicture() async => (await _controller!.takePicture()).path;

  @override
  Future<void> setTorch(bool on) =>
      _tryOptional(() => _controller!.setFlashMode(on ? FlashMode.torch : FlashMode.off));

  @override
  Future<void> focusAt(Offset normalized) async {
    await _tryOptional(() => _controller!.setFocusPoint(normalized));
    await _tryOptional(() => _controller!.setExposurePoint(normalized));
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
  ref.onDispose(() {
    service.stop();
  });
  return service;
});
