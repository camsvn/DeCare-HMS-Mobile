import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

/// In-memory [CameraService] for tests: no platform channel, real files.
///
/// Every capture writes a four-byte JPEG stub (`SOI` + `EOI`) into [dir] so
/// tests can assert on the filesystem the way the controller sees it.
class FakeCameraService implements CameraService {
  FakeCameraService({required this.dir, this.failStart = false, this.failCapture = false});

  /// Where [takePicture] writes its stubs. The test owns and deletes it.
  final Directory dir;

  /// Makes [start] throw, as a device with no usable camera would.
  bool failStart;

  /// Makes [takePicture] throw, as a busy or crashed camera would.
  bool failCapture;

  /// Makes [flush] throw, as a post-processing step that gave up would.
  bool failFlush = false;

  /// When set, [takePicture] waits on it before writing, so a test can hold a
  /// capture in flight and shoot again while the controller is busy.
  Completer<void>? gate;

  /// When set, [start] waits on it before readying, so a test can hold a cold
  /// start in flight and stop (or dispose) the session underneath it.
  Completer<void>? startGate;

  /// When set, [flush] waits on it, so a test can hold a session's background
  /// post-processing open and watch what the screen does about it.
  Completer<void>? flushGate;

  /// The preview's *displayed* width / height once started, as
  /// [CameraService.previewAspectRatio] reports it — so a portrait preview of
  /// a 16:9 sensor is 9/16 here. Settable, so a test can put the screen's
  /// cover-crop arithmetic under a known frame shape.
  double aspectRatio = 3 / 4;

  int startCount = 0;
  int stopCount = 0;
  int flushCount = 0;

  /// How many times [preview] has been asked for a widget, so a test can show
  /// that a shot does not rebuild the camera texture.
  int previewBuilds = 0;
  final List<bool> torchCalls = [];
  final List<Offset> focusCalls = [];

  bool _ready = false;
  int _shots = 0;

  /// Mirrors `PluginCameraService`'s generation latch: [stop] cancels a [start]
  /// that is still in flight, so the fake races the way the real service does.
  int _generation = 0;

  @override
  bool get isReady => _ready;

  @override
  double get previewAspectRatio => _ready ? aspectRatio : 1;

  @override
  Future<void> start() async {
    startCount++;
    final gen = ++_generation;
    final held = startGate;
    if (held != null) await held.future;
    // Overtaken by a `stop` (or another `start`): the device this call opened
    // is gone, so it must not report itself ready — or failed.
    if (gen != _generation) return;
    if (failStart) throw StateError('no camera');
    _ready = true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _generation++;
    _ready = false;
  }

  @override
  Widget preview() {
    previewBuilds++;
    return const ColoredBox(key: Key('fake-preview'), color: Colors.black);
  }

  @override
  Future<String> takePicture() async {
    final held = gate;
    if (held != null) await held.future;
    if (failCapture) throw StateError('capture failed');
    final file = File('${dir.path}/shot_${_shots++}.jpg')..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
    return file.path;
  }

  @override
  Future<void> flush() async {
    flushCount++;
    final held = flushGate;
    if (held != null) await held.future;
    if (failFlush) throw StateError('flush failed');
  }

  @override
  Future<void> setTorch(bool on) async => torchCalls.add(on);

  @override
  Future<void> focusAt(Offset normalized) async => focusCalls.add(normalized);
}
