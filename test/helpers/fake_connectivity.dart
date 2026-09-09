import 'dart:async';

import 'package:hms_uploader/features/tomogram/tomogram.dart';

/// Drives [ConnectivityService] by hand so tests never touch the platform
/// channel. [emit] both flips [isOnline] and pushes the event, matching how the
/// real plugin reports a change it already applied.
class FakeConnectivityService implements ConnectivityService {
  FakeConnectivityService({this.online = true});

  bool online;
  final StreamController<bool> _controller = StreamController<bool>.broadcast();

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
