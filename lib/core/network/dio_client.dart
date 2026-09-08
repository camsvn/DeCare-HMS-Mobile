import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hms_uploader/core/network/auth_interceptor.dart';

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

Dio buildDio({required String baseUrl, required String? Function() tokenReader}) {
  final dio = Dio(BaseOptions(
    baseUrl: baseUrl,
    connectTimeout: jsonTimeout,
    receiveTimeout: jsonTimeout,
    headers: {'Accept': 'application/json'},
  ));
  dio.interceptors.add(AuthInterceptor(tokenReader));
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
  );
  ref.onDispose(dio.close);
  return dio;
});
