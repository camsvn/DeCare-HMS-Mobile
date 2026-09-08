import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/storage/prefs_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ServerConfigRepository {
  ServerConfigRepository(this._prefs);

  static const _key = 'server_url';
  final SharedPreferences _prefs;

  String? read() {
    final v = _prefs.getString(_key);
    return (v == null || v.isEmpty) ? null : v;
  }

  Future<void> save(String url) => _prefs.setString(_key, url);

  Future<void> clear() => _prefs.remove(_key);
}

final serverConfigRepositoryProvider = Provider<ServerConfigRepository>(
  (ref) => ServerConfigRepository(ref.watch(sharedPreferencesProvider)),
);
