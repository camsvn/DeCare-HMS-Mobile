import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
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

  /// Renews the access token with the stored refresh token.
  ///
  /// Returns null only for a *terminal* failure — no session, or a server that
  /// refused this refresh token — which is the caller's cue to sign out. A
  /// transient failure (no network, a timeout, a 5xx) is rethrown: it says
  /// nothing about the session, and treating it as a refusal would sign the
  /// user out every time the connection dropped. Signing out is the listener's
  /// decision either way, so the session is left untouched on failure.
  ///
  /// Deliberately uses `ref.read`: watching the session here would rebuild this
  /// notifier on the very state change it writes.
  Future<String?> refreshAccessToken() async {
    final current = state.valueOrNull;
    if (current == null) return null;
    try {
      final token = await ref.read(authApiProvider).refresh(current.refreshToken);
      // The session changed while the refresh was in flight — a sign-out, or a
      // sign-in as somebody else. Saving now would resurrect a dead session.
      if (state.valueOrNull?.refreshToken != current.refreshToken) return null;
      final next = Session(accessToken: token, refreshToken: current.refreshToken);
      await ref.read(sessionRepositoryProvider).save(next);
      state = AsyncData(next);
      return token;
    } catch (e) {
      final failure = ApiFailure.from(e);
      // Terminal: the server gave an answer, and the answer was no. Retrying
      // the same refresh token cannot change it.
      if (failure is UnauthorizedFailure ||
          failure is RejectedFailure ||
          failure is BadDataFailure ||
          failure is NotFoundFailure) {
        return null;
      }
      throw failure;
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
