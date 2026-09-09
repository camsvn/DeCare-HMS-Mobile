import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:hms_uploader/features/tomogram/data/pending_upload.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The app's documents directory. Overridden in main.dart with the awaited
/// `getApplicationDocumentsDirectory()`, and with a temp directory in tests.
final appDocumentsDirProvider = Provider<Directory>(
  (ref) => throw UnimplementedError('appDocumentsDirProvider must be overridden'),
);

/// The queue's storage: the entry list in prefs, the photos themselves under
/// `<root>/pending/<id>/`.
///
/// The file operations use the synchronous `File`/`Directory` API on purpose.
/// They are small local copies, and staying synchronous keeps them completable
/// inside a widget test's fake-async pump loop, which never drains a real
/// filesystem future (same reason as `core/utils/temp_files.dart`).
class PendingUploadsRepository {
  PendingUploadsRepository(this._prefs, this._root);

  static const _key = 'pending_uploads';

  final SharedPreferences _prefs;
  final Directory _root;

  List<PendingUpload> read() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      return list.whereType<Map>().map(PendingUpload.fromJson).toList();
    } on FormatException {
      return const [];
    }
  }

  Future<void> write(List<PendingUpload> entries) =>
      _prefs.setString(_key, jsonEncode(entries.map((e) => e.toJson()).toList()));

  /// Copies [draft]'s files out of the picker cache — which the OS may clear at
  /// any time — into the entry's own folder, and returns the entry pointing at
  /// the copies. The originals stay with the drafts that own them.
  Future<PendingUpload> stage(PendingUpload draft) async {
    final folder = _folderFor(draft.id);
    Directory(folder).createSync(recursive: true);
    final staged = <PendingFile>[];
    for (var i = 0; i < draft.files.length; i++) {
      final source = draft.files[i];
      final target = '$folder/$i.jpg';
      File(source.path).copySync(target);
      staged.add(PendingFile(path: target, description: source.description));
    }
    return draft.copyWith(files: staged);
  }

  /// Deletes an entry's staged photos. A folder that is already gone is fine.
  Future<void> purge(PendingUpload entry) async {
    final folder = Directory(_folderFor(entry.id));
    try {
      if (folder.existsSync()) folder.deleteSync(recursive: true);
    } on FileSystemException {
      // ignore: best effort cleanup
    }
  }

  String _folderFor(String id) => '${_root.path}/pending/$id';
}

final pendingUploadsRepositoryProvider = Provider<PendingUploadsRepository>(
  (ref) => PendingUploadsRepository(ref.watch(sharedPreferencesProvider), ref.watch(appDocumentsDirProvider)),
);
