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

  Future<void> logout() async {
    await ref.read(sessionRepositoryProvider).clear();
    state = const AsyncData(null);
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, Session?>(SessionController.new);
