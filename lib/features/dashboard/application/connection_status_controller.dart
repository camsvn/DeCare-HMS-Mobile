import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';

/// True when the configured server answered the health check this session.
class ConnectionStatusController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final url = ref.watch(serverConfigControllerProvider).valueOrNull;
    if (url == null) return false;
    try {
      await ref.read(healthCheckApiProvider).check(url);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> refresh() async => ref.invalidateSelf();
}

final connectionStatusProvider =
    AsyncNotifierProvider<ConnectionStatusController, bool>(ConnectionStatusController.new);
