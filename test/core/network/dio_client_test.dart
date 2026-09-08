import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hms_uploader/core/network/dio_client.dart';

void main() {
  test('apiBaseUrl appends /api', () {
    expect(apiBaseUrl('http://decare.team'), 'http://decare.team/api');
  });

  test('buildDio sets base url, accept header and timeouts', () {
    final dio = buildDio(baseUrl: 'http://x/api', tokenReader: () => null);
    expect(dio.options.baseUrl, 'http://x/api');
    expect(dio.options.headers['Accept'], 'application/json');
    expect(dio.options.connectTimeout, jsonTimeout);
    expect(dio.options.receiveTimeout, jsonTimeout);
  });

  test('interceptor adds Bearer header only when a token exists', () async {
    String? token;
    final dio = buildDio(baseUrl: 'http://x/api', tokenReader: () => token);
    late RequestOptions seen;
    dio.httpClientAdapter = _CapturingAdapter((o) => seen = o);

    await dio.get('/a');
    expect(seen.headers.containsKey('Authorization'), isFalse);

    token = 'abc';
    await dio.get('/a');
    expect(seen.headers['Authorization'], 'Bearer abc');
  });
}

class _CapturingAdapter implements HttpClientAdapter {
  _CapturingAdapter(this.onRequest);
  final void Function(RequestOptions) onRequest;

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<List<int>>? requestStream, Future<void>? cancelFuture) async {
    onRequest(options);
    return ResponseBody.fromString('{}', 200, headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    });
  }

  @override
  void close({bool force = false}) {}
}
