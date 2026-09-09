import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/features/tomogram/tomogram.dart';
import 'package:image/image.dart' as img;

void main() {
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('bake'));
  tearDown(() async {
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  /// A 4x2 JPEG, optionally tagged with an EXIF [orientation] — 6 being what
  /// CameraX hands back for a portrait shot from the back camera.
  File wide(String name, {int? orientation}) {
    final image = img.Image(width: 4, height: 2);
    if (orientation != null) image.exif.imageIfd.orientation = orientation;
    return File('${dir.path}/$name')..writeAsBytesSync(img.encodeJpg(image));
  }

  img.Image decode(File file) => img.decodeJpg(file.readAsBytesSync())!;

  test('a sideways JPEG comes back upright with no orientation tag', () async {
    final file = wide('sideways.jpg', orientation: 6);
    // The raw file is 4x2 pixels that a reader is told to turn a quarter turn.
    // (`decodeJpg` cannot show that: it applies the tag itself.)
    expect(img.decodeJpgExif(file.readAsBytesSync())!.imageIfd.orientation, 6);

    await bakeJpegOrientation(file.path);

    final baked = decode(file);
    expect(baked.width, 2);
    expect(baked.height, 4);
    final ifd = baked.exif.imageIfd;
    // `bakeOrientation` drops the tag rather than writing 1; either says
    // "these pixels are already the right way up".
    expect(!ifd.hasOrientation || ifd.orientation == 1, isTrue);
    // Nothing is left for the session's cleanup to find.
    expect(File('${file.path}$jpegBakeTmpSuffix').existsSync(), isFalse);
  });

  test('an upright JPEG is left byte for byte alone', () async {
    for (final file in [wide('none.jpg'), wide('one.jpg', orientation: 1)]) {
      final before = file.readAsBytesSync();

      await bakeJpegOrientation(file.path);

      // Not merely "still upright": an already-correct shot must not be
      // re-encoded, which would cost quality for nothing.
      expect(file.readAsBytesSync(), before, reason: file.path);
    }
  });

  test('a file that is not a JPEG is left alone and does not throw', () async {
    final bytes = Uint8List.fromList(List.generate(64, (i) => i));
    final file = File('${dir.path}/notes.txt')..writeAsBytesSync(bytes);

    await bakeJpegOrientation(file.path);

    expect(file.readAsBytesSync(), bytes);
  });
}
