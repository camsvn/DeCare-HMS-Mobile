import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/connectivity_service.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';

/// Whether the configured server is reachable right now.
///
/// The device's connectivity is the fast, negative signal: with no network
/// route the answer is "unreachable" straight away and the server is not asked.
/// The health check is the positive signal, re-run whenever connectivity
/// changes, the server URL changes, or a caller asks via [refresh].
class ConnectionStatusController extends AsyncNotifier<bool> {
  @override
  Future<bool> build() async {
    final url = ref.watch(serverConfigControllerProvider).value;
    final connectivity = ref.watch(connectivityServiceProvider);
    // Any change of route (lost, regained, switched) is a reason to look again.
    final sub = connectivity.onlineChanges.listen((_) => ref.invalidateSelf());
    ref.onDispose(sub.cancel);

    if (url == null) return false;
    if (!await connectivity.isOnline()) return false;
    try {
      await ref.read(healthCheckApiProvider).check(url);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Runs the check again now, e.g. when the app returns to the foreground.
  void refresh() => ref.invalidateSelf();
}

final connectionStatusProvider =
    AsyncNotifierProvider<ConnectionStatusController, bool>(ConnectionStatusController.new);
