import 'dart:io';

/// Best-effort deletion of local files. Missing files and IO errors are ignored.
///
/// Uses the synchronous File API: these are small, local temp-file cleanups,
/// and staying synchronous avoids a real async filesystem gap that never
/// resolves inside a widget test's fake-async pump loop (no [WidgetTester]
/// can drive that completion without `runAsync`).
Future<void> deleteFiles(Iterable<String> paths) async {
  for (final p in paths) {
    try {
      final f = File(p);
      if (f.existsSync()) f.deleteSync();
    } on FileSystemException {
      // ignore: best effort cleanup
    }
  }
}
