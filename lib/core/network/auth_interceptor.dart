import 'package:dio/dio.dart';

/// Adds `Authorization: Bearer <token>` when [tokenReader] returns a token.
class AuthInterceptor extends Interceptor {
  AuthInterceptor(this.tokenReader);

  final String? Function() tokenReader;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = tokenReader();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }
}
