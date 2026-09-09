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

  /// When set, [takePicture] waits on it before writing, so a test can hold a
  /// capture in flight and shoot again while the controller is busy.
  Completer<void>? gate;

  int startCount = 0;
  int stopCount = 0;
  final List<bool> torchCalls = [];
  final List<Offset> focusCalls = [];

  bool _ready = false;
  int _shots = 0;

  @override
  bool get isReady => _ready;

  @override
  double get previewAspectRatio => _ready ? 3 / 4 : 1;

  @override
  Future<void> start() async {
    startCount++;
    if (failStart) throw StateError('no camera');
    _ready = true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _ready = false;
  }

  @override
  Widget preview() => const ColoredBox(key: Key('fake-preview'), color: Colors.black);

  @override
  Future<String> takePicture() async {
    final held = gate;
    if (held != null) await held.future;
    if (failCapture) throw StateError('capture failed');
    final file = File('${dir.path}/shot_${_shots++}.jpg')..writeAsBytesSync(const [0xFF, 0xD8, 0xFF, 0xD9]);
    return file.path;
  }

  @override
  Future<void> setTorch(bool on) async => torchCalls.add(on);

  @override
  Future<void> focusAt(Offset normalized) async => focusCalls.add(normalized);
}
