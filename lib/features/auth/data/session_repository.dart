import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/storage/secure_store.dart';
import 'package:hms_uploader/features/auth/data/session.dart';

class SessionRepository {
  SessionRepository(this._store);

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  final SecureStore _store;

  Future<Session?> read() async {
    final access = await _store.read(_accessKey);
    final refresh = await _store.read(_refreshKey);
    if (access == null || refresh == null) return null;
    return Session(accessToken: access, refreshToken: refresh);
  }

  Future<void> save(Session s) async {
    await _store.write(_accessKey, s.accessToken);
    await _store.write(_refreshKey, s.refreshToken);
  }

  Future<void> clear() async {
    await _store.delete(_accessKey);
    await _store.delete(_refreshKey);
  }
}

final sessionRepositoryProvider = Provider<SessionRepository>(
  (ref) => SessionRepository(ref.watch(secureStoreProvider)),
);
