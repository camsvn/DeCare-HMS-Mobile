import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/utils/temp_files.dart';

void main() {
  test('deletes existing files and ignores missing ones', () async {
    final dir = await Directory.systemTemp.createTemp('tmp_files');
    final a = File('${dir.path}/a')..writeAsStringSync('a');
    await deleteFiles([a.path, '${dir.path}/missing']);
    expect(a.existsSync(), isFalse);
    await dir.delete(recursive: true);
  });
}
