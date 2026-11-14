import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/connectivity_service.dart';
import 'package:hms_uploader/core/network/server_reachability.dart';
import 'package:hms_uploader/features/server_config/server_config.dart';

/// Whether the configured server is reachable right now.
///
/// The device's connectivity is the fast, negative signal: with no network
/// route the answer is "unreachable" straight away and the server is not asked.
/// The health check is the positive signal, re-run whenever connectivity
/// changes, the server URL changes, or a caller asks via [refresh].
///
/// The answer is shared both ways with [serverReachabilityProvider]: each
/// check's result is reported there, and a request elsewhere in the app that
/// proves otherwise updates this status without another check.
class ConnectionStatusController extends AsyncNotifier<bool> {
  /// The last connectivity the stream reported. connectivity_plus tells every
  /// new listener the current network first, and this notifier subscribes
  /// afresh on each rebuild — so reacting to *every* event would make each
  /// rebuild trigger the next, and the dashboard would read "checking" for
  /// ever. Only a change is a reason to look again.
  bool? _lastOnline;

  @override
  Future<bool> build() async {
    final url = ref.watch(serverConfigControllerProvider).value;
    final connectivity = ref.watch(connectivityServiceProvider);
    // Any change of route (lost, regained, switched) is a reason to look again.
    final sub = connectivity.onlineChanges.listen((online) {
      if (online == _lastOnline) return;
      _lastOnline = online;
      ref.invalidateSelf();
    });
    ref.onDispose(sub.cancel);
    // A check in flight will report its own answer; only a settled status is
    // corrected by what other requests found.
    ref.listen(serverReachabilityProvider, (_, reachable) {
      if (reachable == null || state.isLoading || state.value == reachable) return;
      state = AsyncData(reachable);
    });

    if (url == null) return false;
    final reachability = ref.read(serverReachabilityProvider.notifier);
    final online = await connectivity.isOnline();
    _lastOnline ??= online;
    final reachable = online && await _healthy(url);
    reachability.report(reachable);
    return reachable;
  }

  Future<bool> _healthy(String url) async {
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
