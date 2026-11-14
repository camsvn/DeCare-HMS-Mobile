import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/api_failure.dart';
import 'package:hms_uploader/core/network/auth_interceptor.dart';
import 'package:hms_uploader/core/network/connectivity_service.dart';
import 'package:hms_uploader/core/network/server_reachability.dart';

export 'package:hms_uploader/core/network/auth_interceptor.dart' show TokenRefresher;

/// How long to wait for a connection to open. Kept well under [jsonTimeout]:
/// a server that is up accepts in milliseconds, so a connect that hangs means
/// the host is unreachable and the user should hear so quickly.
const Duration connectTimeout = Duration(seconds: 5);
const Duration jsonTimeout = Duration(seconds: 10);

/// How long the offline gate waits for the platform to say whether there is a
/// network before giving up and sending the request anyway.
const Duration onlineCheckTimeout = Duration(milliseconds: 500);
const Duration uploadTimeout = Duration(seconds: 60);

String apiBaseUrl(String serverUrl) => '$serverUrl/api';

/// Current server URL. Overridden in main.dart with the server_config feature state.
final serverUrlProvider = Provider<String?>(
  (ref) => throw UnimplementedError('serverUrlProvider must be overridden in main.dart'),
);

/// Current access token. Overridden in main.dart with the auth feature state.
final accessTokenProvider = Provider<String?>(
  (ref) => throw UnimplementedError('accessTokenProvider must be overridden in main.dart'),
);

/// Renews the access token. Overridden in main.dart with the auth feature's
/// session controller. The interceptor treats a throw as a failed refresh, so
/// an un-overridden container degrades to "session expired" rather than crashing.
final refreshAccessTokenProvider = Provider<TokenRefresher>(
  (ref) => throw UnimplementedError('refreshAccessTokenProvider must be overridden in main.dart'),
);

/// Bumped whenever a protected request stays 401 after a refresh attempt.
/// `SessionExpiryListener` watches it and signs the user out.
class AuthFailureCounter extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

final authFailureProvider = NotifierProvider<AuthFailureCounter, int>(AuthFailureCounter.new);

/// [isOnline], when given, is asked before every request; with no network the
/// request fails at once as an [OfflineFailure] instead of waiting out the
/// connect timeout. [onReachability] hears what each request proved about the
/// server: `true` for any response, `false` when no connection could be made.
Dio buildDio({
  required String baseUrl,
  required String? Function() tokenReader,
  TokenRefresher? refresher,
  VoidCallback? onAuthFailure,
  Future<bool> Function()? isOnline,
  void Function(bool reachable)? onReachability,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: connectTimeout,
    receiveTimeout: jsonTimeout,
    headers: {'Accept': 'application/json'},
  ));
  if (isOnline != null) dio.interceptors.add(_OfflineGate(isOnline));
  dio.interceptors.add(AuthInterceptor(
    dio: dio,
    tokenReader: tokenReader,
    refresher: refresher,
    onAuthFailure: onAuthFailure,
  ));
  if (onReachability != null) dio.interceptors.add(_ReachabilityReporter(onReachability));
  return dio;
}

/// Fails a request straight away when the device has no network route.
class _OfflineGate extends Interceptor {
  _OfflineGate(this._isOnline);

  final Future<bool> Function() _isOnline;

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    bool online;
    try {
      online = await _isOnline().timeout(onlineCheckTimeout);
    } catch (_) {
      // A shortcut, not a gate keeper: if the platform cannot say, or does
      // not say promptly, let the request itself find out.
      online = true;
    }
    if (online) return handler.next(options);
    handler.reject(
      DioException.connectionError(
        requestOptions: options,
        reason: 'No network connection',
        error: const DeviceOfflineException(),
      ),
      true,
    );
  }
}

/// Tells [_report] what each finished request proved about the server.
class _ReachabilityReporter extends Interceptor {
  _ReachabilityReporter(this._report);

  final void Function(bool reachable) _report;

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _report(true);
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response != null) {
      // Any status at all means the server answered.
      _report(true);
    } else if (ApiFailure.from(err) is CannotConnectFailure) {
      _report(false);
    }
    // Anything else (a slow answer, a cancel) proves nothing either way.
    handler.next(err);
  }
}

/// Shared client for the configured server. Rebuilds whenever the URL changes.
/// Throws [StateError] if no server URL is configured; callers only reach it
/// after the redirect gate has ensured one exists.
final dioProvider = Provider<Dio>((ref) {
  final url = ref.watch(serverUrlProvider);
  if (url == null || url.isEmpty) {
    throw StateError('No server URL configured');
  }
  final dio = buildDio(
    baseUrl: apiBaseUrl(url),
    tokenReader: () => ref.read(accessTokenProvider),
    refresher: () => ref.read(refreshAccessTokenProvider)(),
    onAuthFailure: () => ref.read(authFailureProvider.notifier).bump(),
    isOnline: () => ref.read(connectivityServiceProvider).isOnline(),
    onReachability: (reachable) => ref.read(serverReachabilityProvider.notifier).report(reachable),
  );
  ref.onDispose(dio.close);
  return dio;
});
