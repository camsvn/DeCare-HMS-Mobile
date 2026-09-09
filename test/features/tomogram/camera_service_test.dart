import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';

void main() {
  // `PluginCameraService` itself is all platform channel, so what is testable
  // here is the one piece of arithmetic it does: turning the sensor's ratio
  // into the ratio `CameraPreview` actually lays out.
  group('displayedAspectRatio', () {
    test('a portrait preview shows the sensor ratio on its side', () {
      expect(displayedAspectRatio(16 / 9, DeviceOrientation.portraitUp), closeTo(9 / 16, 1e-9));
      expect(displayedAspectRatio(4 / 3, DeviceOrientation.portraitDown), closeTo(3 / 4, 1e-9));
    });

    test('a landscape preview shows the sensor ratio as it is', () {
      expect(displayedAspectRatio(16 / 9, DeviceOrientation.landscapeLeft), closeTo(16 / 9, 1e-9));
      expect(displayedAspectRatio(4 / 3, DeviceOrientation.landscapeRight), closeTo(4 / 3, 1e-9));
    });
  });
}
