import 'dart:io';

/// Best-effort deletion of local files. Missing files and IO errors are ignored.
Future<void> deleteFiles(Iterable<String> paths) async {
  for (final p in paths) {
    try {
      final f = File(p);
      if (await f.exists()) await f.delete();
    } on FileSystemException {
      // ignore: best effort cleanup
    }
  }
}
