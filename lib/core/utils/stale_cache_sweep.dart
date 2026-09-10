import 'dart:io';

import 'package:flutter/foundation.dart';

/// How long a photo may sit in the cache directory before a launch sweep
/// removes it. Anything the app is using is minutes old; a day leaves a wide
/// margin for a device whose clock jumped.
const staleCacheAge = Duration(hours: 24);

/// File types the camera and picker plugins leave in the app cache: captured
/// and picked JPEGs, and the `.tmp` sibling the orientation bake writes.
const _photoExtensions = {'.jpg', '.jpeg', '.tmp'};

/// Deletes photo files in [cacheDir] (recursively) last modified more than
/// [olderThan] ago, then removes any subdirectory that emptied as a result.
/// Returns the number of files removed.
///
/// Every screen that owns photos deletes them when it is done, but a process
/// that dies with photos on screen — a crash, a swipe from Recents, the OS
/// reclaiming memory — never runs that code, and the files would otherwise sit
/// in the cache until the system trimmed it. Run once per launch, not awaited.
/// Files that are not photos (other plugins' caches) are never touched, and
/// the offline upload queue keeps its staged copies in the documents
/// directory, outside this sweep.
Future<int> sweepStaleCache(
  Directory cacheDir, {
  Duration olderThan = staleCacheAge,
  DateTime? now,
}) async {
  if (!await cacheDir.exists()) return 0;
  final cutoff = (now ?? DateTime.now()).subtract(olderThan);
  var removed = 0;
  final touchedDirs = <String>{};

  await for (final entity in cacheDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (!_photoExtensions.contains(_extensionOf(entity.path))) continue;
    try {
      final modified = await entity.lastModified();
      if (modified.isAfter(cutoff)) continue;
      await entity.delete();
      removed++;
      touchedDirs.add(entity.parent.path);
    } on FileSystemException catch (e) {
      // Best effort: a file that vanished or is locked is left for next time.
      debugPrint('sweepStaleCache: skipped ${entity.path}: ${e.message}');
    }
  }

  // Deepest first, so a nested folder can empty its parent in the same pass.
  final dirs = touchedDirs.where((d) => d != cacheDir.path).toList()
    ..sort((a, b) => b.length.compareTo(a.length));
  for (final path in dirs) {
    final dir = Directory(path);
    try {
      if (await dir.list().isEmpty) await dir.delete();
    } on FileSystemException {
      // ignore: another writer beat us to it, or it filled up again
    }
  }
  return removed;
}

/// Lower-cased extension including the dot, or an empty string.
String _extensionOf(String path) {
  final name = File(path).uri.pathSegments.last;
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.substring(dot).toLowerCase();
}
