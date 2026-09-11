import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String? value);
  Future<void> delete(String key);
}

class FlutterSecureStore implements SecureStore {
  // flutter_secure_storage 11 encrypts with its own cipher on Android; the
  // `encryptedSharedPreferences` option v9 needed no longer exists. Data
  // written by v9 is not readable by v11 — accepted: the only thing stored
  // here is the session, and testers log in once more after the upgrade.
  FlutterSecureStore([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String? value) =>
      value == null ? _storage.delete(key: key) : _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class InMemorySecureStore implements SecureStore {
  final Map<String, String> _map = {};

  @override
  Future<String?> read(String key) async => _map[key];

  @override
  Future<void> write(String key, String? value) async {
    if (value == null) {
      _map.remove(key);
    } else {
      _map[key] = value;
    }
  }

  @override
  Future<void> delete(String key) async => _map.remove(key);
}

final secureStoreProvider = Provider<SecureStore>((ref) => FlutterSecureStore());
