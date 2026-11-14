import 'package:dio/dio.dart';

/// Stands in for the platform HTTP client: either answers every request with
/// [status] and a JSend body, or fails it the way the platform would for
/// [failure]. Records the path of every request that reached it.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter.status(int this.status) : failure = null;
  FakeHttpAdapter.failing(DioExceptionType this.failure) : status = null;

  final int? status;
  final DioExceptionType? failure;
  final List<String> paths = [];

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    paths.add(options.uri.path);
    final type = failure;
    if (type != null) throw DioException(requestOptions: options, type: type);
    return ResponseBody.fromString('{"status":"success","data":{"uptime":1}}', status!, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
