import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/auth_interceptor.dart';

export 'package:hms_uploader/core/network/auth_interceptor.dart' show TokenRefresher;

const Duration jsonTimeout = Duration(seconds: 10);
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
final authFailureProvider = StateProvider<int>((ref) => 0);

Dio buildDio({
  required String baseUrl,
  required String? Function() tokenReader,
  TokenRefresher? refresher,
  VoidCallback? onAuthFailure,
}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: jsonTimeout,
    receiveTimeout: jsonTimeout,
    headers: {'Accept': 'application/json'},
  ));
  dio.interceptors.add(AuthInterceptor(
    dio: dio,
    tokenReader: tokenReader,
    refresher: refresher,
    onAuthFailure: onAuthFailure,
  ));
  return dio;
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
    onAuthFailure: () => ref.read(authFailureProvider.notifier).state++,
  );
  ref.onDispose(dio.close);
  return dio;
});
