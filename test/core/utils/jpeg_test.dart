import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/utils/jpeg.dart';

void main() {
  late Directory dir;
  setUp(() async => dir = await Directory.systemTemp.createTemp('jpeg_test'));
  tearDown(() async => dir.delete(recursive: true));

  test('detects JPEG magic bytes', () async {
    final f = File('${dir.path}/a.bin');
    await f.writeAsBytes([0xFF, 0xD8, 0xFF, 0xE0, 0, 0]);
    expect(await isJpegFile(f.path), isTrue);
  });
  test('rejects PNG', () async {
    final f = File('${dir.path}/a.png');
    await f.writeAsBytes([0x89, 0x50, 0x4E, 0x47, 0, 0]);
    expect(await isJpegFile(f.path), isFalse);
  });
  test('rejects missing or tiny file', () async {
    expect(await isJpegFile('${dir.path}/missing'), isFalse);
    final f = File('${dir.path}/tiny');
    await f.writeAsBytes([0xFF]);
    expect(await isJpegFile(f.path), isFalse);
  });
}
