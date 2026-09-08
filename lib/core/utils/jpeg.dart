import 'dart:io';

/// True when the file starts with the JPEG SOI marker `FF D8 FF`.
Future<bool> isJpegFile(String path) async {
  final file = File(path);
  if (!await file.exists()) return false;
  final raf = await file.open();
  try {
    final bytes = await raf.read(3);
    return bytes.length == 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF;
  } finally {
    await raf.close();
  }
}
