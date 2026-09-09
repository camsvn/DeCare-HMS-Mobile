import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether the device has a network route at all. This says nothing about the
/// HMS server being reachable — the upload attempt itself decides that — it
/// only tells the queue when it is worth trying again.
abstract class ConnectivityService {
  Stream<bool> get onlineChanges;
  Future<bool> isOnline();
}

class ConnectivityPlusService implements ConnectivityService {
  ConnectivityPlusService(this._connectivity);

  final Connectivity _connectivity;

  @override
  Stream<bool> get onlineChanges => _connectivity.onConnectivityChanged.map(_isOnline);

  @override
  Future<bool> isOnline() async => _isOnline(await _connectivity.checkConnectivity());

  /// The plugin reports every active interface; anything other than a lone
  /// `none` means there is a route to try.
  static bool _isOnline(List<ConnectivityResult> results) => !results.contains(ConnectivityResult.none);
}

final connectivityServiceProvider =
    Provider<ConnectivityService>((ref) => ConnectivityPlusService(Connectivity()));
