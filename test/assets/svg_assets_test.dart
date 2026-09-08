import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

void main() {
  // encodeSvg's default optimizers (masking/clipping/overdraw) require the
  // native PathOps library from the Flutter engine cache; without this,
  // parsing throws regardless of SVG content.
  setUpAll(() {
    if (!initializePathOpsFromFlutterCache()) {
      fail('Could not initialize PathOps from the Flutter cache; run `flutter precache`.');
    }
  });

  for (final name in ['blank_canvas.svg', 'add_tomogram.svg', 'hms_circle.svg']) {
    test('$name parses as vector graphics', () {
      final xml = File('assets/images/$name').readAsStringSync();
      final bytes = encodeSvg(xml: xml, debugName: name);
      expect(bytes, isNotEmpty);
    });
  }
}
