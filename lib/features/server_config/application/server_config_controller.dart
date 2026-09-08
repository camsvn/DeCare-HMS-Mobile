import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/utils/url_validator.dart';
import 'package:hms_uploader/features/server_config/data/health_check_api.dart';
import 'package:hms_uploader/features/server_config/data/server_config_repository.dart';

class InvalidServerUrlException implements Exception {
  const InvalidServerUrlException();
}

/// Holds the configured server URL. `isLoading` is true while connecting.
class ServerConfigController extends AsyncNotifier<String?> {
  @override
  Future<String?> build() async => ref.watch(serverConfigRepositoryProvider).read();

  Future<void> connect(String rawUrl) async {
    final url = normalizeServerUrl(rawUrl);
    if (url == null) {
      state = AsyncError<String?>(const InvalidServerUrlException(), StackTrace.current)
          .copyWithPrevious(state);
      return;
    }
    state = const AsyncLoading<String?>().copyWithPrevious(state);
    try {
      await ref.read(healthCheckApiProvider).check(url);
      await ref.read(serverConfigRepositoryProvider).save(url);
      state = AsyncData(url);
    } catch (e, st) {
      state = AsyncError<String?>(e, st).copyWithPrevious(state);
    }
  }

  Future<void> reset() async {
    await ref.read(serverConfigRepositoryProvider).clear();
    state = const AsyncData(null);
  }
}

final serverConfigControllerProvider =
    AsyncNotifierProvider<ServerConfigController, String?>(ServerConfigController.new);
