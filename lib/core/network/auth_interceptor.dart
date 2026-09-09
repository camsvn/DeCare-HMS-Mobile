import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Fetches a fresh access token, or null when the session cannot be renewed.
typedef TokenRefresher = Future<String?> Function();

/// Adds `Authorization: Bearer <token>` when [tokenReader] returns a token and,
/// on a 401 from a protected route, refreshes the access token once and retries.
/// Auth routes are never retried: a 401 there is the answer, not a stale token.
///
/// [onAuthFailure] fires at most once per request: the retry re-enters this
/// interceptor, so the already-retried branch is the only place that reports it.
///
/// Deliberately a plain [Interceptor], not a [QueuedInterceptor]: the refresher
/// posts `/auth/refresh` through this same client, so with a queued interceptor
/// a 401 on the refresh itself (a dead refresh token — the common case) would
/// wait behind the very error that is awaiting it, and the client would hang
/// forever. A burst of 401s is de-duplicated by [_refresh] instead, which is
/// what the queue was wanted for.
class AuthInterceptor extends Interceptor {
  AuthInterceptor({
    required this.dio,
    required this.tokenReader,
    this.refresher,
    this.onAuthFailure,
  });

  final Dio dio;
  final String? Function() tokenReader;
  final TokenRefresher? refresher;

  /// Called when a protected request stays unauthorized: the session is dead.
  final VoidCallback? onAuthFailure;

  static const _retried = 'auth_retried';

  /// The refresh currently in flight, so parallel 401s wait on one call.
  Future<String?>? _refreshing;

  Future<String?> _refresh() async {
    final inFlight = _refreshing;
    if (inFlight != null) return inFlight;
    final future = _callRefresher();
    _refreshing = future;
    try {
      return await future;
    } finally {
      _refreshing = null;
    }
  }

  Future<String?> _callRefresher() async {
    try {
      return await refresher!();
    } catch (e) {
      // A missing provider override looks exactly like a rejected refresh;
      // say so in debug builds instead of silently signing the user out.
      assert(() {
        debugPrint('refresh failed: $e');
        return true;
      }());
      return null;
    }
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // A retry re-enters this chain already carrying the token the refresh
    // produced; tokenReader may still be reporting the stale one, so leave it.
    if (options.extra[_retried] == true) return handler.next(options);
    final token = tokenReader();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final path = err.requestOptions.path;
    final isAuthRoute = path.startsWith('/auth/');
    final alreadyRetried = err.requestOptions.extra[_retried] == true;
    if (status != 401 || isAuthRoute || alreadyRetried || refresher == null) {
      if (status == 401 && !isAuthRoute) onAuthFailure?.call();
      return handler.next(err);
    }

    final newToken = await _refresh();
    if (newToken == null || newToken.isEmpty) {
      onAuthFailure?.call();
      return handler.next(err);
    }

    final opts = err.requestOptions;
    // A multipart body is a one-shot stream: Dio finalizes the FormData before
    // sending it, and a finalized form cannot be re-read. Retrying would send
    // an empty body, so let the 401 through instead. The token has just been
    // refreshed, so the caller (the upload queue) succeeds on its next attempt.
    // The session itself is healthy, so this is not an auth failure.
    final data = opts.data;
    if (data is FormData && data.isFinalized) return handler.next(err);

    opts.headers['Authorization'] = 'Bearer $newToken';
    opts.extra[_retried] = true;
    try {
      final response = await dio.fetch<dynamic>(opts);
      return handler.resolve(response);
    } on DioException catch (e) {
      // No signal here: the retry re-entered this interceptor, and the
      // already-retried branch above is the single place that reports a 401.
      return handler.next(e);
    }
  }
}
