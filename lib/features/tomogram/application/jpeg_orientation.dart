import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// The sibling a bake writes before it replaces the original. Exported so the
/// capture session can delete one that a failed bake left behind.
const String jpegBakeTmpSuffix = '.tmp';

/// Quality of the re-encode. Only a shot that had to be rotated pays it, and
/// 90 is above the 85 the gallery path already uploads at.
const int _bakeQuality = 90;

/// Rewrites the JPEG at [path] so its pixels are upright and its EXIF
/// `Orientation` tag is gone, off the UI isolate.
///
/// CameraX hands back a *sensor-oriented* JPEG: a portrait shot from the back
/// camera is 1280x720 pixels tagged `Orientation = 6`. A viewer that honours
/// EXIF shows that as 720x1280; one that ignores it shows the patient on their
/// side. The clinic's viewers are unknown, and the picker path this capture
/// screen replaced uploaded upright pixels (1440x1920, `Orientation = 1`), so
/// the rotation is baked into the pixels here rather than trusted to the
/// reader.
///
/// A shot that is already upright — no tag, or `Orientation = 1` — is left
/// byte for byte alone: nothing is re-encoded, so it costs no quality and no
/// time. So is anything that does not decode as a JPEG.
///
/// Errors are not swallowed. The caller decides what a failed bake means; for
/// the capture session it means uploading the original, which is a photo the
/// user took rather than a photo they lost.
Future<void> bakeJpegOrientation(String path) => compute(_bake, path);

/// The isolate side of [bakeJpegOrientation]. Runs under `compute`, so it
/// takes and returns nothing but the path.
///
/// The new bytes go to a sibling `<path>.tmp` and are then renamed over the
/// original, so a crash or a kill mid-write cannot leave a truncated JPEG
/// where a whole one used to be. A failure takes the half-written sibling with
/// it and rethrows as it was.
Future<void> _bake(String path) async {
  final bytes = await File(path).readAsBytes();
  // Read the tag from the raw file rather than from the decoded image: this
  // decoder applies the orientation while decoding and clears the tag as it
  // goes, so by then there is nothing left to look at. `decodeJpgExif` also
  // answers null for anything that is not a JPEG, which is the other reason
  // to leave a file alone.
  final orientation = img.decodeJpgExif(bytes)?.imageIfd.orientation;
  if (orientation == null || orientation == 1) return;
  final image = img.decodeJpg(bytes);
  if (image == null) return;
  // A no-op with the decoder above, which has already turned the pixels — but
  // the call is what makes this function right either way, and a decoder that
  // stops auto-baking must not quietly start uploading sideways photos.
  final baked = img.encodeJpg(img.bakeOrientation(image), quality: _bakeQuality);
  final tmp = File('$path$jpegBakeTmpSuffix');
  try {
    await tmp.writeAsBytes(baked, flush: true);
    await tmp.rename(path);
  } catch (_) {
    if (tmp.existsSync()) {
      try {
        tmp.deleteSync();
      } on FileSystemException {
        // ignore: the rethrow below is the thing worth reporting.
      }
    }
    rethrow;
  }
}
