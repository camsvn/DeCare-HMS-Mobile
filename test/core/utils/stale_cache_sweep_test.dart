import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/utils/stale_cache_sweep.dart';

void main() {
  late Directory cache;
  final now = DateTime(2026, 9, 11, 9);
  final twoDaysAgo = now.subtract(const Duration(days: 2));
  final anHourAgo = now.subtract(const Duration(hours: 1));

  File put(String relative, DateTime modified) {
    final f = File('${cache.path}/$relative')
      ..createSync(recursive: true)
      ..writeAsBytesSync([1, 2, 3])
      ..setLastModifiedSync(modified);
    return f;
  }

  setUp(() async => cache = await Directory.systemTemp.createTemp('sweep'));
  tearDown(() async => cache.delete(recursive: true));

  test('deletes photo files older than the threshold and keeps recent ones', () async {
    final oldJpg = put('CAP123.jpg', twoDaysAgo);
    final oldTmp = put('CAP123.jpg.tmp', twoDaysAgo);
    final oldJpeg = put('scaled.JPEG', twoDaysAgo);
    final freshJpg = put('CAP456.jpg', anHourAgo);

    final removed = await sweepStaleCache(cache, now: now);

    expect(removed, 3);
    expect(oldJpg.existsSync(), isFalse);
    expect(oldTmp.existsSync(), isFalse);
    expect(oldJpeg.existsSync(), isFalse);
    expect(freshJpg.existsSync(), isTrue);
  });

  test('leaves files that are not photos alone, however old', () async {
    final db = put('some_plugin.db', twoDaysAgo);
    final txt = put('notes.txt', twoDaysAgo);

    expect(await sweepStaleCache(cache, now: now), 0);
    expect(db.existsSync(), isTrue);
    expect(txt.existsSync(), isTrue);
  });

  test('sweeps picker subfolders and removes the ones it empties', () async {
    // image_picker writes cache/<uuid>/<name>.jpg.
    put('9f1c/photo.jpg', twoDaysAgo);
    put('a2b3/photo.jpg', anHourAgo);
    put('c4d5/keep.bin', twoDaysAgo);

    expect(await sweepStaleCache(cache, now: now), 1);
    expect(Directory('${cache.path}/9f1c').existsSync(), isFalse, reason: 'emptied folder goes');
    expect(Directory('${cache.path}/a2b3').existsSync(), isTrue, reason: 'fresh photo keeps its folder');
    expect(Directory('${cache.path}/c4d5').existsSync(), isTrue, reason: 'non-photo content is untouched');
  });

  test('a missing cache directory is not an error', () async {
    final gone = Directory('${cache.path}/nope');
    expect(await sweepStaleCache(gone, now: now), 0);
  });

  test('the threshold is adjustable', () async {
    final f = put('CAP.jpg', anHourAgo);
    expect(await sweepStaleCache(cache, olderThan: const Duration(minutes: 30), now: now), 1);
    expect(f.existsSync(), isFalse);
  });
}
