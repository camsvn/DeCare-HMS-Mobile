import 'dart:async';

import 'package:hms_uploader/features/tomogram/tomogram.dart';

/// Drives [ConnectivityService] by hand so tests never touch the platform
/// channel. [emit] both flips [isOnline] and pushes the event, matching how the
/// real plugin reports a change it already applied.
///
/// With [replayOnListen] the stream behaves like connectivity_plus on Android,
/// which registers a `NetworkCallback` on every subscription and is told the
/// current network straight away — so every new listener first receives the
/// state it already has.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true, this.replayOnListen = false});

  bool online;
  final bool replayOnListen;
  int subscriptions = 0;
  late final StreamController<bool> _controller = StreamController<bool>.broadcast(onListen: _onListen);

  void _onListen() {
    subscriptions++;
    if (replayOnListen) scheduleMicrotask(() => _controller.add(online));
  }

  @override
  Stream<bool> get onlineChanges => _controller.stream;

  @override
  Future<bool> isOnline() async => online;

  void emit(bool value) {
    online = value;
    _controller.add(value);
  }

  Future<void> close() => _controller.close();
}
