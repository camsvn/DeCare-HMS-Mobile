import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/auth/data/auth_api.dart';
import 'package:hms_uploader/features/auth/data/session.dart';
import 'package:hms_uploader/features/auth/data/session_repository.dart';

class SessionController extends AsyncNotifier<Session?> {
  @override
  Future<Session?> build() => ref.watch(sessionRepositoryProvider).read();

  Future<void> login(String username, String password) async {
    state = const AsyncLoading<Session?>().copyWithPrevious(state);
    try {
      final session = await ref.read(authApiProvider).login(username, password);
      await ref.read(sessionRepositoryProvider).save(session);
      state = AsyncData(session);
    } catch (e, st) {
      state = AsyncError<Session?>(e, st).copyWithPrevious(state);
    }
  }

  /// Renews the access token with the stored refresh token. Returns null when
  /// there is no session or the server refuses the refresh; signing out is the
  /// listener's decision, not this method's, so the session is left untouched.
  ///
  /// Deliberately uses `ref.read`: watching the session here would rebuild this
  /// notifier on the very state change it writes.
  Future<String?> refreshAccessToken() async {
    final current = state.valueOrNull;
    if (current == null) return null;
    try {
      final token = await ref.read(authApiProvider).refresh(current.refreshToken);
      final next = Session(accessToken: token, refreshToken: current.refreshToken);
      await ref.read(sessionRepositoryProvider).save(next);
      state = AsyncData(next);
      return token;
    } catch (_) {
      return null;
    }
  }

  Future<void> logout() async {
    // Drop the in-memory session *before* awaiting the store, so a burst of
    // 401s sees the session already gone and only signs out once.
    state = const AsyncData(null);
    // Clear again afterwards, even if the secure store throws: leaving the
    // state behind would keep the user inside the app with dead tokens, and a
    // rebuild while the clear was in flight could have re-read the old session.
    try {
      await ref.read(sessionRepositoryProvider).clear();
    } finally {
      state = const AsyncData(null);
    }
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);
