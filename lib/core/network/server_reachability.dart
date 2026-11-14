import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/dio_client.dart';

/// What the app last learned about whether the HMS server can be reached:
/// `true` once something answered, `false` once a connection could not be
/// made, `null` before anything has been tried.
///
/// Fed by every request through `dioProvider` and by the dashboard's health
/// check, so a screen can show "server unreachable" without trying again.
class ServerReachability extends Notifier<bool?> {
  @override
  bool? build() => null;

  void report(bool reachable) {
    if (state != reachable) state = reachable;
  }

  /// Pings the server's public health endpoint. The shared client reports the
  /// outcome itself, so this only has to make the request and absorb failure.
  Future<void> recheck() async {
    try {
      await ref.read(dioProvider).get<dynamic>('/auth/healthcheck');
    } catch (_) {
      // Already reported by the client, or no server is configured yet.
    }
  }
}

final serverReachabilityProvider = NotifierProvider<ServerReachability, bool?>(ServerReachability.new);
